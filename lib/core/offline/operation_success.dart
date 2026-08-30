part of 'operation_result.dart';

final class OperationSuccess extends OperationResult {
  const OperationSuccess({this.resolvedEntityId});

  /// The server-assigned id a successful `create` produced, so it can be
  /// written onto the synced [OfflineOperation] row — see
  /// [OfflineOperation.resolvedEntityId]. `null` for an `update` (no new id)
  /// or when nothing else depends on this operation's entity.
  final String? resolvedEntityId;
}
