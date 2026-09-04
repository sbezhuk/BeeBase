import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final attachment1 = MediaAttachment(
    id: 'media-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    imageUrl: 'https://example.com/photo.jpg',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final attachment2 = MediaAttachment(
    id: 'media-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    imageUrl: 'https://example.com/photo.jpg',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final attachment3 = MediaAttachment(
    id: 'media-2',
    originalFilename: 'photo2.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 2048,
    imageUrl: 'https://example.com/photo2.jpg',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('equality and hashCode', () {
    test('same-field instances are equal and have identical hashCodes', () {
      expect(attachment1, attachment2);
      expect(attachment1.hashCode, attachment2.hashCode);
    });

    test('instances with different fields are not equal', () {
      expect(attachment1 == attachment3, isFalse);
    });
  });
}
