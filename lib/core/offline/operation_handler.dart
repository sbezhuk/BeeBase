import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_result.dart';

/// The extensibility point: a feature registers one of these (see
/// `OperationRegistry`) to teach the generic [SyncEngine] how to execute its
/// own pending operations, without the engine ever knowing the feature
/// exists.
abstract interface class OperationHandler {
  /// Matches [OfflineOperation.entityType] — e.g. `'apiary'`.
  String get entityType;

  Future<OperationResult> handle(OfflineOperation operation);
}
