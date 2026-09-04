import 'package:json_annotation/json_annotation.dart';

part 'entity_image_response.g.dart';

@JsonSerializable()
final class EntityImageResponse {
  const EntityImageResponse({
    required this.id,
    this.imageUrl,
  });

  factory EntityImageResponse.fromJson(dynamic json) {
    if (json is String) {
      return EntityImageResponse(id: json);
    }
    if (json is Map<String, dynamic>) {
      return _$EntityImageResponseFromJson(json);
    }
    throw ArgumentError.value(json, 'json', 'Cannot parse EntityImageResponse');
  }

  final String id;

  @JsonKey(name: 'image_url')
  final String? imageUrl;

  Map<String, dynamic> toJson() => _$EntityImageResponseToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntityImageResponse &&
          other.id == id &&
          other.imageUrl == imageUrl);

  @override
  int get hashCode => Object.hash(id, imageUrl);
}

class EntityImageListConverter
    implements JsonConverter<List<EntityImageResponse>, List<dynamic>?> {
  const EntityImageListConverter();

  @override
  List<EntityImageResponse> fromJson(List<dynamic>? json) {
    if (json == null) return const [];
    return json.map((e) => EntityImageResponse.fromJson(e)).toList();
  }

  @override
  List<dynamic> toJson(List<EntityImageResponse> object) =>
      object.map((e) => e.toJson()).toList();
}
