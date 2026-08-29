import 'package:beebase/data/models/pagination_meta.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_response.g.dart';

/// Envelope shape shared by every paginated list endpoint
/// (`{items: [...], pagination: {...}}`) — reused as-is for any future
/// paginated collection (hives, inspections, ...), never redefined per
/// feature.
@JsonSerializable(genericArgumentFactories: true)
final class PaginatedResponse<T> {
  const PaginatedResponse({required this.items, required this.pagination});

  factory PaginatedResponse.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$PaginatedResponseFromJson(json, fromJsonT);

  final List<T> items;
  final PaginationMeta pagination;

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) => _$PaginatedResponseToJson(this, toJsonT);
}
