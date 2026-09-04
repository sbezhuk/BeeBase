import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/domain/entity/hive.dart';

extension HiveResponseX on HiveResponse {
  Hive toEntity() => Hive(
    id: id,
    apiaryId: apiaryId,
    name: name,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
    images: images.map((image) => image.id).toList(),
  );
}
