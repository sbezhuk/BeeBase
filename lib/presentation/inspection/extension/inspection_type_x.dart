import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:easy_localization/easy_localization.dart';

/// Localized display label for an [InspectionType] — keyed off the enum's
/// own [Enum.name], so a new type only needs its `inspection.types.<name>`
/// entry in `assets/langs/en-US.json`, never a change here.
extension InspectionTypeX on InspectionType {
  String get label => 'inspection.types.$name'.tr();
}
