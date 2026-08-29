import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';

/// A generic, entity-agnostic record of a mutation that couldn't reach the
/// server yet. [payload] is opaque here — only the [OperationHandler]
/// registered for [entityType] knows how to interpret it. [id] doubles as
/// the client-generated idempotency key sent with the eventual request, so
/// retrying this operation never creates a duplicate entity server-side
/// (assuming backend support — see `ApiaryOperationHandler`).
final class OfflineOperation {
  const OfflineOperation({
    required this.id,
    required this.entityType,
    required this.operationType,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.retryCount = 0,
    this.lastError,
    this.localEntityId,
    this.dependsOnOperationId,
    this.version = 0,
  });

  final String id;
  final String entityType;
  final OperationType operationType;
  final Map<String, dynamic> payload;
  final OperationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int retryCount;
  final String? lastError;
  final String? localEntityId;

  /// The id of an operation this one must wait behind (e.g. creating a Hive
  /// that belongs to an Apiary not yet synced). Modeled but not enforced by
  /// [SyncEngine] today — there is only one entity type in the queue so far.
  final String? dependsOnOperationId;

  /// Bumped every time a newer local edit is consolidated into this same
  /// operation (see `OfflineMutationStore.saveWithConsolidatedOperation`).
  /// `SyncEngineImpl` snapshots this before sending the request and compares
  /// it against the current row afterward, so a payload that changed while
  /// the request was in flight is never mistaken for the one that was
  /// actually sent — see `OperationSuperseded`.
  final int version;

  OfflineOperation copyWith({
    OperationType? operationType,
    Map<String, dynamic>? payload,
    OperationStatus? status,
    DateTime? updatedAt,
    int? retryCount,
    String? lastError,
    String? localEntityId,
    int? version,
  }) {
    return OfflineOperation(
      id: id,
      entityType: entityType,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      localEntityId: localEntityId ?? this.localEntityId,
      dependsOnOperationId: dependsOnOperationId,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entityType': entityType,
    'operationType': operationType.name,
    'payload': payload,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'retryCount': retryCount,
    'lastError': lastError,
    'localEntityId': localEntityId,
    'dependsOnOperationId': dependsOnOperationId,
    'version': version,
  };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) => OfflineOperation(
    id: json['id'] as String,
    entityType: json['entityType'] as String,
    operationType: OperationType.values.byName(json['operationType'] as String),
    payload: (json['payload'] as Map<String, dynamic>? ?? const {}),
    status: OperationStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
    lastError: json['lastError'] as String?,
    localEntityId: json['localEntityId'] as String?,
    dependsOnOperationId: json['dependsOnOperationId'] as String?,
    version: json['version'] as int? ?? 0,
  );
}
