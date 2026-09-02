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
  /// everything). Never sent on create: hive-service's create endpoint has
  /// no `images` field, so a caller must create first and PUT separately to
  /// attach photos.
  @JsonKey(includeIfNull: false)
  final List<String>? images;

  Map<String, dynamic> toJson() => _$HiveRequestToJson(this);
}
