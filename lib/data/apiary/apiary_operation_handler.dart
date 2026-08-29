import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';

/// Executes a queued Apiary operation when the [SyncEngine] drains the
/// queue. Extends [Repository] purely to reuse its `on()` exception→Failure
/// classification — the same rule already governs online reads/writes, so
/// there is exactly one place that decides what counts as a permanent vs a
/// retryable failure.
final class ApiaryOperationHandler extends Repository implements OperationHandler {
  ApiaryOperationHandler({required this.dataSource, required this.localDataSource, required this.refreshNotifier});

  final IApiaryDataSource dataSource;
  final LocalDataSource<List<ApiaryResponse>> localDataSource;
  final ApiaryListRefreshNotifier refreshNotifier;

  @override
  String get entityType => 'apiary';

  @override
  Future<OperationResult> handle(OfflineOperation operation) {
    return switch (operation.operationType) {
      OperationType.create => _handleCreate(operation),
      OperationType.update ||
      OperationType.delete => Future.value(const OperationPermanentFailure('Offline update/delete is not supported yet.')),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final request = ApiaryRequest.fromJson(operation.payload);
    final result = await on(() => dataSource.createApiary(request, idempotencyKey: operation.id));

    return result.fold(
      (failure) async {
        return failure is ServerFailure
            ? OperationPermanentFailure(failure.message.resolve())
            : OperationRetryableFailure(failure.message.resolve());
      },
      (response) async {
        await _reconcileCache(operation.localEntityId, response);
        refreshNotifier.notify();
        return const OperationSuccess();
      },
    );
  }

  Future<void> _reconcileCache(String? localEntityId, ApiaryResponse serverResponse) {
    return localDataSource.modify((current) {
      final withoutPlaceholder = (current ?? const []).where((response) => response.id != localEntityId);
      return [...withoutPlaceholder, serverResponse];
    });
  }
}
