import 'package:beebase/core/location/location_failure.dart';
import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/location/resolved_location.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/apiary_form_state.dart';
part 'state/apiary_form_initial.dart';
part 'state/apiary_form_loading.dart';
part 'state/apiary_form_success.dart';
part 'state/apiary_form_error.dart';
part 'mixin/apiary_form_emitter.dart';

final class ApiaryFormCubit extends Cubit<ApiaryFormState> with ApiaryFormEmitter {
  ApiaryFormCubit({required this.writer, required this.refreshNotifier, required this.locationService, this.initial})
    : super(const ApiaryFormInitial());

  final IApiaryWriter writer;
  final ApiaryListRefreshNotifier refreshNotifier;
  final LocationService locationService;

  /// The apiary being edited, or `null` when this form is creating a new one.
  final Apiary? initial;

  bool get isEditing => initial != null;

  Future<void> submit({required String name, String? description, String? location, double? lat, double? lon}) {
    return emitSubmit(
      writer,
      refreshNotifier,
      initial: initial,
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
    );
  }

  /// Resolves the device's current position to a display address, for the
  /// "use current location" action. Kept out of [ApiaryFormState] since it's
  /// a local, ephemeral concern for the location field, not the form's
  /// submit lifecycle.
  Future<Either<LocationFailure, ResolvedLocation>> resolveCurrentLocation() {
    return locationService.getCurrentLocation();
  }
}
