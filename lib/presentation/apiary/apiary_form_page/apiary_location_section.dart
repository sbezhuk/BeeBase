part of '../apiary_form_page.dart';

/// Location as its own labeled block (matching [ApiarySectionCard]'s
/// section-card pattern): geolocation is the only way to set it — no manual
/// text entry — so the card just shows the resolved address and coordinates
/// once [_ApiaryLocationPrimaryAction] has fetched them, or a short "not set
/// yet" message beforehand.
final class _ApiaryLocationSection extends StatelessWidget {
  const _ApiaryLocationSection({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isFetchingLocation,
    required this.onUseCurrentLocation,
  });

  final String? address;
  final double? latitude;
  final double? longitude;
  final bool isFetchingLocation;
  final VoidCallback onUseCurrentLocation;

  bool get _hasAddress => address != null && address!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lat = latitude;
    final lon = longitude;
    return ApiarySectionCard(
      label: 'apiary.form.locationLabel'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasAddress) ...[
            Text(address!, style: context.textStyles.body),
            if (lat != null && lon != null) ...[
              SizedBox(height: context.spacing.xs),
              Text(
                '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                style: context.textStyles.label.copyWith(color: colors.honeyMuted),
              ),
            ],
          ] else ...[
            Text('apiary.form.location.notSet'.tr(), style: context.textStyles.body.copyWith(color: colors.textSecondary)),
            SizedBox(height: context.spacing.xs),
            Text('apiary.form.location.optionalHint'.tr(), style: context.textStyles.label.copyWith(color: colors.honeyMuted)),
          ],
          SizedBox(height: context.spacing.md),
          _ApiaryLocationPrimaryAction(
            label: _hasAddress
                ? 'apiary.form.location.updateCurrentLocation'.tr()
                : 'apiary.form.location.useCurrentLocation'.tr(),
            isLoading: isFetchingLocation,
            onPressed: onUseCurrentLocation,
          ),
        ],
      ),
    );
  }
}
