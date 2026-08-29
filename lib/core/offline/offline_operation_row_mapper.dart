import 'dart:convert';

import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';

/// Maps [OfflineOperation] to/from an `offline_operations` table row — the
/// one place both `SqliteOperationQueue` and `SqliteOfflineMutationStore`
/// agree on the schema.
abstract final class OfflineOperationRowMapper {
  static Map<String, Object?> toRow(OfflineOperation operation) => {
    'id': operation.id,
    'entity_type': operation.entityType,
    'operation_type': operation.operationType.name,
    'payload': jsonEncode(operation.payload),
    'status': operation.status.name,
    'created_at': operation.createdAt.toIso8601String(),
    'updated_at': operation.updatedAt.toIso8601String(),
    'retry_count': operation.retryCount,
    'last_error': operation.lastError,
    'local_entity_id': operation.localEntityId,
    'depends_on_operation_id': operation.dependsOnOperationId,
  };

  static OfflineOperation fromRow(Map<String, Object?> row) => OfflineOperation(
    id: row['id']! as String,
    entityType: row['entity_type']! as String,
    operationType: OperationType.values.byName(row['operation_type']! as String),
    payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
    status: OperationStatus.values.byName(row['status']! as String),
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    retryCount: row['retry_count']! as int,
    lastError: row['last_error'] as String?,
    localEntityId: row['local_entity_id'] as String?,
    dependsOnOperationId: row['depends_on_operation_id'] as String?,
  );
}
