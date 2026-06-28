import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: isPrimary ? AppColors.onPrimary : AppColors.primary,
            ),
          )
        : Text(
            text,
            style: AppTextStyles.button.copyWith(
              color: isPrimary ? AppColors.onPrimary : AppColors.onSurface,
            ),
          );

    if (!isPrimary) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null || isLoading
              ? null
              : AppColors.primaryGradient,
          color: onPressed == null || isLoading
              ? AppColors.surfaceContainerHighest
              : null,
          borderRadius: BorderRadius.circular(28),
          boxShadow: onPressed == null || isLoading
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.softGlow,
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.transparent,
            foregroundColor: AppColors.onPrimary,
            shadowColor: AppColors.transparent,
            disabledBackgroundColor: AppColors.transparent,
            disabledForegroundColor: AppColors.onSurfaceMuted,
          ),
          child: child,
        ),
      ),
    );
  }
}
