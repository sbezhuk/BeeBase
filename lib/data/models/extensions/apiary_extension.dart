import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/domain/entity/apiary.dart';

extension ApiaryResponseX on ApiaryResponse {
  Apiary toEntity() =>
      Apiary(id: id, name: name, description: notes, location: location, createdAt: createdAt, updatedAt: updatedAt);
}
