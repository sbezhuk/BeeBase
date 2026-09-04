import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiaryResponse.fromJson', () {
    test('parses images as list of objects (matching real backend / Swagger schema)', () {
      final json = {
        'id': 'apiary-1',
        'name': 'Meadow Apiary',
        'location': 'Sunny Valley',
        'description': 'Main apiary',
        'lat': 48.8566,
        'lon': 2.3522,
        'images': [
          {
            'id': 'img-1',
            'image_url': 'http://localhost:8888/api/v1/media/img-1/download',
          },
          {
            'id': 'img-2',
            'image_url': 'http://localhost:8888/api/v1/media/img-2/download',
          },
        ],
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T15:30:00.000Z',
      };

      final response = ApiaryResponse.fromJson(json);

      expect(response.id, 'apiary-1');
      expect(response.name, 'Meadow Apiary');
      expect(response.images.length, 2);
      expect(response.images[0].id, 'img-1');
      expect(response.images[0].imageUrl, 'http://localhost:8888/api/v1/media/img-1/download');
      expect(response.images[1].id, 'img-2');

      final entity = response.toEntity();
      expect(entity.images, ['img-1', 'img-2']);
    });

    test('parses images as list of string IDs for backward compatibility', () {
      final json = {
        'id': 'apiary-2',
        'name': 'Garden Apiary',
        'images': ['img-3', 'img-4'],
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T15:30:00.000Z',
      };

      final response = ApiaryResponse.fromJson(json);

      expect(response.images.length, 2);
      expect(response.images[0].id, 'img-3');
      expect(response.images[1].id, 'img-4');

      final entity = response.toEntity();
      expect(entity.images, ['img-3', 'img-4']);
    });

    test('defaults images to empty list when omitted or null', () {
      final json = {
        'id': 'apiary-3',
        'name': 'Empty Apiary',
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T15:30:00.000Z',
      };

      final response = ApiaryResponse.fromJson(json);
      expect(response.images, isEmpty);
      expect(response.toEntity().images, isEmpty);
    });
  });
}
