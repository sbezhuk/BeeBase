part of '../apiary_list_cubit.dart';

final class ApiaryListLoaded extends ApiaryListState {
  const ApiaryListLoaded(this.apiaries);

  final List<Apiary> apiaries;

  bool get isEmpty => apiaries.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApiaryListLoaded) return false;
    if (other.apiaries.length != apiaries.length) return false;
    for (var i = 0; i < apiaries.length; i++) {
      if (other.apiaries[i] != apiaries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(apiaries);
}
