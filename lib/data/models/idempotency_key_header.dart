import 'package:json_annotation/json_annotation.dart';

part 'idempotency_key_header.g.dart';

/// The `Idempotency-Key` header sent on a create request so a retried
/// offline-queued create is recognized as the same operation server-side.
@JsonSerializable()
final class IdempotencyKeyHeader {
  const IdempotencyKeyHeader({required this.idempotencyKey});

  factory IdempotencyKeyHeader.fromJson(Map<String, dynamic> json) => _$IdempotencyKeyHeaderFromJson(json);

  @JsonKey(name: 'Idempotency-Key')
  final String idempotencyKey;

  Map<String, dynamic> toJson() => _$IdempotencyKeyHeaderToJson(this);
}
