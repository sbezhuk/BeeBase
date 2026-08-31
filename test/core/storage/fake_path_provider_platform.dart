import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points `path_provider` (and therefore `LocalMediaStore`) at a caller-
/// supplied directory instead of a real platform channel, which has no
/// handler registered under `flutter test`. Install with
/// `PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);`
/// in any test that exercises real `LocalMediaStore` file I/O.
final class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this._documentsPath);

  final String _documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;
}
