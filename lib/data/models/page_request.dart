import 'package:json_annotation/json_annotation.dart';

part 'page_request.g.dart';

/// Universal page/limit query-parameter DTO — reused by every paginated
/// list endpoint (apiaries today, hives/inspections later) instead of each
/// data source building its own inline query-parameter map.
@JsonSerializable()
final class PageRequest {
  const PageRequest({required this.page, required this.limit});

  factory PageRequest.fromJson(Map<String, dynamic> json) => _$PageRequestFromJson(json);

  final int page;
  final int limit;

  Map<String, dynamic> toJson() => _$PageRequestToJson(this);
}
