import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:flutter/material.dart';

final class PrimaryButton extends StatelessWidget {
  const PrimaryButton({required this.label, required this.onPressed, this.isLoading = false, super.key});

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.primary, AppColor.primaryDark],
        ),
        boxShadow: [BoxShadow(color: AppColor.primaryDark.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 14))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColor.background),
                  )
                : Text(label, style: AppTextStyles.button),
          ),
        ),
      ),
    );
  }
}
