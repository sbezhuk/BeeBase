import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips the real backend envelope shape through fromJson', () {
    // Shaped exactly like GET /api/v1/apiaries's 200 response.
    final json = {
      'items': [
        {
          'id': 'apiary-1',
          'name': 'Back Garden',
          'location': 'Springfield',
          'description': 'A small apiary',
          'lat': 51.5,
          'lon': -0.1,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-02T00:00:00.000Z',
        },
      ],
      'pagination': {'page': 1, 'limit': 20, 'total': 125, 'total_pages': 7, 'has_next': true, 'has_previous': false},
    };

    final response = PaginatedResponse.fromJson(json, (item) => ApiaryResponse.fromJson(item as Map<String, dynamic>));

    expect(response.items, hasLength(1));
    expect(response.items.single.id, 'apiary-1');
    expect(response.items.single.name, 'Back Garden');
    expect(response.pagination.page, 1);
    expect(response.pagination.limit, 20);
    expect(response.pagination.total, 125);
    expect(response.pagination.totalPages, 7);
    expect(response.pagination.hasNext, isTrue);
    expect(response.pagination.hasPrevious, isFalse);
  });

  test('round-trips an empty items list', () {
    final json = {
      'items': <Object?>[],
      'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0, 'has_next': false, 'has_previous': false},
    };

    final response = PaginatedResponse.fromJson(json, (item) => ApiaryResponse.fromJson(item as Map<String, dynamic>));

    expect(response.items, isEmpty);
    expect(response.pagination.hasNext, isFalse);
  });
}
