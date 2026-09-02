import 'package:json_annotation/json_annotation.dart';

part 'hive_request.g.dart';

/// The body for updating a hive (`PUT /api/v1/hives/{id}`) — matches
/// hive-service's `UpdateHiveRequest` schema exactly. Also reused for
/// create, where `apiary_id` is merged in separately by `HiveDataSource`
/// (it's on `CreateHiveRequest` but not `UpdateHiveRequest`, since a hive
/// can't be moved to a different apiary after creation).
@JsonSerializable()
final class HiveRequest {
  const HiveRequest({required this.name, this.notes, this.images});

  factory HiveRequest.fromJson(Map<String, dynamic> json) =>
      _$HiveRequestFromJson(json);

  final String name;
  final String? notes;

  /// The desired final set of already-uploaded media ids attached to this
  /// hive. `null` (the default) leaves currently attached media untouched
  /// — [includeIfNull] omits the key entirely in that case, which is what
  /// hive-service's `PUT` distinguishes from an explicit `[]` (detach
  /// everything). Never sent on create: hive-service's create endpoint
  /// accepts an `images` field now, but this client still creates first and
  /// PUTs separately to attach photos (see
  /// `HiveRepositoryImpl.addHiveImage`) rather than sending them inline —
  /// that flow was already correct before create supported `images` and
  /// there's no requirement to change it.
  @JsonKey(includeIfNull: false)
  final List<String>? images;

  Map<String, dynamic> toJson() => _$HiveRequestToJson(this);
}
