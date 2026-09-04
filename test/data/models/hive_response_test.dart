import 'package:beebase/data/models/extensions/hive_extension.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HiveResponse.fromJson', () {
    test('parses images as list of objects (matching real backend / Swagger schema)', () {
      final json = {
        'id': 'hive-1',
        'apiary_id': 'apiary-1',
        'name': 'Hive Alpha',
        'notes': 'Strong colony',
        'images': [
          {
            'id': 'hive-img-1',
            'image_url': 'http://localhost:8888/api/v1/media/hive-img-1/download',
          },
        ],
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T15:30:00.000Z',
      };

      final response = HiveResponse.fromJson(json);

      expect(response.id, 'hive-1');
      expect(response.apiaryId, 'apiary-1');
      expect(response.images.length, 1);
      expect(response.images[0].id, 'hive-img-1');
      expect(response.images[0].imageUrl, 'http://localhost:8888/api/v1/media/hive-img-1/download');

      final entity = response.toEntity();
      expect(entity.images, ['hive-img-1']);
    });

    test('parses images as list of string IDs for backward compatibility', () {
      final json = {
        'id': 'hive-2',
        'apiary_id': 'apiary-1',
        'name': 'Hive Beta',
        'images': ['hive-img-2'],
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T15:30:00.000Z',
      };

      final response = HiveResponse.fromJson(json);

      expect(response.images.length, 1);
      expect(response.images[0].id, 'hive-img-2');

      final entity = response.toEntity();
      expect(entity.images, ['hive-img-2']);
    });

    test('defaults images to empty list when omitted or null', () {
      final json = {
        'id': 'hive-3',
        'apiary_id': 'apiary-1',
        'name': 'Hive Gamma',
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T15:30:00.000Z',
      };

      final response = HiveResponse.fromJson(json);
      expect(response.images, isEmpty);
      expect(response.toEntity().images, isEmpty);
    });
  });
}
