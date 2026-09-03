import 'package:beebase/core/networking/exceptions/cancellation_exception.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';

final class _TestRepository extends Repository {
  const _TestRepository();
}

void main() {
  const repository = _TestRepository();

  group('Repository.on', () {
    test('returns Right on success', () async {
      final result = await repository.on(() async => 'ok');

      expect(result, isA<Right<Failure, String>>());
    });

    test('maps ServerException to ServerFailure', () async {
      final result = await repository.on<void>(
        () async => throw const ServerException(
          code: 'invalid',
          message: 'Invalid',
          statusCode: 422,
          fields: {},
        ),
      );

      expect(result, isA<Left<Failure, void>>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps CancellationException to CancellationFailure', () async {
      final result = await repository.on<void>(
        () async =>
            throw const CancellationException(ErrorTextRaw('cancelled')),
      );

      result.fold(
        (failure) => expect(failure, isA<CancellationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps InternalException to InternalFailure', () async {
      final result = await repository.on<void>(
        () async =>
            throw const InternalException(ErrorTextRaw('no connection')),
      );

      result.fold(
        (failure) => expect(failure, isA<InternalFailure>()),
        (_) => fail('expected Left'),
      );
    });

    // The scenario this guards: `action` is a data-source call where the
    // HTTP request itself already succeeded (a 2xx was required to reach the
    // response-decoding line at all — any non-2xx would have already thrown
    // a `ServerException`, caught above) and something decoding that
    // successful response throws instead — e.g. `response.data!` on an
    // empty/null body, or a DTO's `fromJson` hitting an unexpected shape.
    // That used to propagate straight out of `on()` uncaught, indistinguishable
    // by the time it reached a generic catch-all from a real request failure
    // — even though the backend had already durably applied the change.
    test(
      'catches an unclassified exception thrown after a would-be-successful response and maps it to InternalFailure',
      () async {
        final result = await repository.on<Map<String, dynamic>>(
          () async => throw TypeError(),
        );

        expect(result, isA<Left<Failure, Map<String, dynamic>>>());
        result.fold(
          (failure) => expect(failure, isA<InternalFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'ignoreStatusCode still treats a matching ServerException as success',
      () async {
        final result = await repository.on<String>(
          () async => throw const ServerException(
            code: 'not_found',
            message: 'Not found',
            statusCode: 404,
            fields: {},
          ),
          ignoreStatusCode: 404,
          onIgnoredStatusCode: () => 'treated as success',
        );

        result.fold(
          (_) => fail('expected Right'),
          (value) => expect(value, 'treated as success'),
        );
      },
    );
  });
}
