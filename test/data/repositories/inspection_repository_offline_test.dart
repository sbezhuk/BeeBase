import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/repositories/inspection_repository_impl.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInspectionDataSource extends Mock implements IInspectionDataSource {}

class MockInspectionLocalDataSource extends Mock
    implements IInspectionLocalDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockInspectionDataSource remoteDataSource;
  late MockInspectionLocalDataSource localDataSource;
  late MockNetworkInfo networkInfo;
  late InspectionRepositoryImpl repository;

  final sampleResponse = InspectionResponse(
    id: 'server-inspection-1',
    hiveId: 'hive-server-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'All looks good',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleOfflineInspection = Inspection(
    id: 'local-inspection-123',
    hiveId: 'hive-server-1',
    localId: 'local-inspection-123',
    hiveServerId: 'hive-server-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'Offline note',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  final sampleSyncedInspection = Inspection(
    id: 'server-inspection-1',
    hiveId: 'hive-server-1',
    localId: 'server-inspection-1',
    serverId: 'server-inspection-1',
    hiveServerId: 'hive-server-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'All looks good',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.synced,
  );

  setUpAll(() {
    registerFallbackValue(
      InspectionRequest(
        date: DateTime(2026),
        type: InspectionType.routine,
        notes: 'fallback',
      ),
    );
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
    registerFallbackValue(sampleOfflineInspection);
  });

  setUp(() {
    remoteDataSource = MockInspectionDataSource();
    localDataSource = MockInspectionLocalDataSource();
    networkInfo = MockNetworkInfo();
    repository = InspectionRepositoryImpl(
      dataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
  });

  group('InspectionRepositoryImpl - Online operations', () {
    setUp(() {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    });

    test('online create calls remote API and caches to local SQLite', () async {
      when(
        () => remoteDataSource.createInspection('hive-server-1', any()),
      ).thenAnswer((_) async => sampleResponse);
      when(
        () => localDataSource.saveServerInspections(any()),
      ).thenAnswer((_) async {});

      final result = await repository.createInspection(
        hiveId: 'hive-server-1',
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'All looks good',
      );

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (inspection) {
        expect(inspection.id, 'server-inspection-1');
      });
      verify(
        () => remoteDataSource.createInspection('hive-server-1', any()),
      ).called(1);
      verify(() => localDataSource.saveServerInspections(any())).called(1);
    });

    test('create while online but parent hive is still local-only stores the '
        'inspection offline instead of calling the API', () async {
      when(() => localDataSource.insertInspection(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Inspection,
      );

      final result = await repository.createInspection(
        hiveId: 'local-hive-999',
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'notes',
      );

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (inspection) {
        expect(inspection.syncStatus, SyncStatus.pendingCreate);
        expect(inspection.hiveLocalId, 'local-hive-999');
        expect(inspection.hiveServerId, isNull);
      });
      verifyNever(() => remoteDataSource.createInspection(any(), any()));
      verify(() => localDataSource.insertInspection(any())).called(1);
    });

    test(
      'online getInspection returns local pendingUpdate version instead of server version',
      () async {
        final pendingUpdateInspection = sampleSyncedInspection.copyWith(
          notes: 'Locally edited notes',
          syncStatus: SyncStatus.pendingUpdate,
        );
        when(
          () => localDataSource.getInspectionById('server-inspection-1'),
        ).thenAnswer((_) async => pendingUpdateInspection);

        final result = await repository.getInspection(
          hiveId: 'hive-server-1',
          id: 'server-inspection-1',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (inspection) {
          expect(inspection.notes, 'Locally edited notes');
          expect(inspection.syncStatus, SyncStatus.pendingUpdate);
        });
        verifyNever(() => remoteDataSource.getInspection(any(), any()));
      },
    );

    test(
      'online delete calls remote API and deletes permanently from SQLite',
      () async {
        when(
          () => localDataSource.getInspectionById('server-inspection-1'),
        ).thenAnswer((_) async => sampleSyncedInspection);
        when(
          () => remoteDataSource.deleteInspection(any(), 'server-inspection-1'),
        ).thenAnswer((_) async {});
        when(
          () => localDataSource.deleteInspectionPermanently(
            'server-inspection-1',
          ),
        ).thenAnswer((_) async {});

        final result = await repository.deleteInspection(
          hiveId: 'hive-server-1',
          id: 'server-inspection-1',
        );

        expect(result.isRight, isTrue);
        verify(
          () => remoteDataSource.deleteInspection(any(), 'server-inspection-1'),
        ).called(1);
        verify(
          () => localDataSource.deleteInspectionPermanently(
            'server-inspection-1',
          ),
        ).called(1);
      },
    );
  });

  group('InspectionRepositoryImpl - Offline operations', () {
    setUp(() {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
    });

    test(
      'offline create does NOT call remote API and saves to SQLite as pendingCreate',
      () async {
        when(() => localDataSource.insertInspection(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Inspection,
        );

        final result = await repository.createInspection(
          hiveId: 'hive-server-1',
          date: DateTime(2026, 1, 1),
          type: InspectionType.health,
          notes: 'Offline note',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (inspection) {
          expect(inspection.notes, 'Offline note');
          expect(inspection.syncStatus, SyncStatus.pendingCreate);
          expect(inspection.localId, isNotNull);
          expect(inspection.id, startsWith('local-'));
          expect(inspection.hiveServerId, 'hive-server-1');
          expect(inspection.hiveLocalId, isNull);
        });
        verifyNever(() => remoteDataSource.createInspection(any(), any()));
        verify(() => localDataSource.insertInspection(any())).called(1);
      },
    );

    test(
      'offline create under an offline-created hive references it by local id, '
      'not a fake server id',
      () async {
        when(() => localDataSource.insertInspection(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Inspection,
        );

        final result = await repository.createInspection(
          hiveId: 'local-hive-1',
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'notes',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (inspection) {
          expect(inspection.hiveLocalId, 'local-hive-1');
          expect(inspection.hiveServerId, isNull);
          expect(inspection.syncStatus, SyncStatus.pendingCreate);
        });
      },
    );

    test(
      'offline getInspections reads active records scoped to the hive from SQLite',
      () async {
        when(
          () => localDataSource.getActiveInspectionsForHive(
            hiveId: 'hive-server-1',
            page: 1,
            limit: 20,
          ),
        ).thenAnswer((_) async => [sampleOfflineInspection]);

        final result = await repository.getInspections(
          hiveId: 'hive-server-1',
          page: 1,
          limit: 20,
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (page) {
          expect(page.items.length, 1);
          expect(page.items.first.id, 'local-inspection-123');
        });
        verifyNever(() => remoteDataSource.getInspections(any(), any()));
      },
    );

    test('offline getInspection reads record from SQLite', () async {
      when(
        () => localDataSource.getInspectionById('local-inspection-123'),
      ).thenAnswer((_) async => sampleOfflineInspection);

      final result = await repository.getInspection(
        hiveId: 'hive-server-1',
        id: 'local-inspection-123',
      );

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (inspection) {
        expect(inspection.id, 'local-inspection-123');
        expect(inspection.notes, 'Offline note');
      });
      verifyNever(() => remoteDataSource.getInspection(any(), any()));
    });

    test(
      'offline update modifies SQLite and marks pendingUpdate if previously synced',
      () async {
        when(
          () => localDataSource.getInspectionById('server-inspection-1'),
        ).thenAnswer((_) async => sampleSyncedInspection);
        when(() => localDataSource.updateInspection(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Inspection,
        );

        final result = await repository.updateInspection(
          hiveId: 'hive-server-1',
          id: 'server-inspection-1',
          date: DateTime(2026, 1, 2),
          type: InspectionType.queen,
          notes: 'Updated notes',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (inspection) {
          expect(inspection.notes, 'Updated notes');
          expect(inspection.type, InspectionType.queen);
          expect(inspection.syncStatus, SyncStatus.pendingUpdate);
        });
        verifyNever(
          () => remoteDataSource.updateInspection(any(), any(), any()),
        );
        verify(() => localDataSource.updateInspection(any())).called(1);
      },
    );

    test(
      'offline update keeps pendingCreate if entity was created offline',
      () async {
        when(
          () => localDataSource.getInspectionById('local-inspection-123'),
        ).thenAnswer((_) async => sampleOfflineInspection);
        when(() => localDataSource.updateInspection(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Inspection,
        );

        final result = await repository.updateInspection(
          hiveId: 'hive-server-1',
          id: 'local-inspection-123',
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'New offline notes',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (inspection) {
          expect(inspection.notes, 'New offline notes');
          expect(inspection.syncStatus, SyncStatus.pendingCreate);
        });
      },
    );

    test(
      'offline delete of unsynced record deletes permanently from SQLite',
      () async {
        when(
          () => localDataSource.getInspectionById('local-inspection-123'),
        ).thenAnswer((_) async => sampleOfflineInspection);
        when(
          () => localDataSource.deleteInspectionPermanently(
            'local-inspection-123',
          ),
        ).thenAnswer((_) async {});

        final result = await repository.deleteInspection(
          hiveId: 'hive-server-1',
          id: 'local-inspection-123',
        );

        expect(result.isRight, isTrue);
        verify(
          () => localDataSource.deleteInspectionPermanently(
            'local-inspection-123',
          ),
        ).called(1);
        verifyNever(() => localDataSource.markPendingDelete(any()));
        verifyNever(() => remoteDataSource.deleteInspection(any(), any()));
      },
    );

    test(
      'offline delete of synced record marks pendingDelete in SQLite without deleting',
      () async {
        when(
          () => localDataSource.getInspectionById('server-inspection-1'),
        ).thenAnswer((_) async => sampleSyncedInspection);
        when(
          () => localDataSource.markPendingDelete('server-inspection-1'),
        ).thenAnswer((_) async {});

        final result = await repository.deleteInspection(
          hiveId: 'hive-server-1',
          id: 'server-inspection-1',
        );

        expect(result.isRight, isTrue);
        verify(
          () => localDataSource.markPendingDelete('server-inspection-1'),
        ).called(1);
        verifyNever(() => localDataSource.deleteInspectionPermanently(any()));
        verifyNever(() => remoteDataSource.deleteInspection(any(), any()));
      },
    );
  });
}
