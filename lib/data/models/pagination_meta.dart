import 'package:json_annotation/json_annotation.dart';

part 'pagination_meta.g.dart';

@JsonSerializable()
final class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) => _$PaginationMetaFromJson(json);

  final int page;
  final int limit;
  final int total;

  @JsonKey(name: 'total_pages')
  final int totalPages;

  @JsonKey(name: 'has_next')
  final bool hasNext;

  @JsonKey(name: 'has_previous')
  final bool hasPrevious;

  Map<String, dynamic> toJson() => _$PaginationMetaToJson(this);
}
