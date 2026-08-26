import 'package:beebase/core/storage/secure_storage.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockSecureStorage secureStorage;
  late TokenStorage tokenStorage;

  setUp(() {
    secureStorage = MockSecureStorage();
    tokenStorage = TokenStorage(secureStorage: secureStorage);
  });

  group('saveAccessToken', () {
    test('writes the token under the access_token key', () async {
      when(() => secureStorage.write(any(), any())).thenAnswer((_) async {});

      await tokenStorage.saveAccessToken('token-123');

      verify(() => secureStorage.write('access_token', 'token-123')).called(1);
    });
  });

  group('accessToken', () {
    test('returns the stored token', () async {
      when(
        () => secureStorage.read('access_token'),
      ).thenAnswer((_) async => 'token-123');

      expect(await tokenStorage.accessToken(), 'token-123');
    });

    test('returns null when nothing is stored', () async {
      when(
        () => secureStorage.read('access_token'),
      ).thenAnswer((_) async => null);

      expect(await tokenStorage.accessToken(), isNull);
    });
  });

  group('hasAccessToken', () {
    test('is true when a token is stored', () async {
      when(
        () => secureStorage.read('access_token'),
      ).thenAnswer((_) async => 'token-123');

      expect(await tokenStorage.hasAccessToken(), isTrue);
    });

    test('is false when no token is stored', () async {
      when(
        () => secureStorage.read('access_token'),
      ).thenAnswer((_) async => null);

      expect(await tokenStorage.hasAccessToken(), isFalse);
    });
  });

  group('clear', () {
    test('deletes the access token', () async {
      when(() => secureStorage.delete(any())).thenAnswer((_) async {});

      await tokenStorage.clear();

      verify(() => secureStorage.delete('access_token')).called(1);
    });
  });
}
