import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/domain/entity/apiary.dart';

extension ApiaryResponseX on ApiaryResponse {
  Apiary toEntity() => Apiary(
    id: id,
    name: name,
    description: description,
    location: location,
    lat: lat,
    lon: lon,
    createdAt: createdAt,
    updatedAt: updatedAt,
    images: images.map((image) => image.id).toList(),
  );
}
