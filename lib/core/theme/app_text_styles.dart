import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTextStyles {
  static const String fontDisplay = 'Manrope';
  static const String fontBody = 'Inter';

  // ============================================================
  // Display / Editorial Voice - Manrope
  // ============================================================

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 48,
    height: 1.02,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    color: AppColors.onSurface,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 38,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    color: AppColors.onSurface,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 28,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: AppColors.onSurface,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.onSurface,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.onSurface,
  );

  static const TextStyle appLogo = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.onSurface,
  );

  // ============================================================
  // Body / Engine - Inter
  // ============================================================

  static const TextStyle body = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontBody,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontBody,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle small = TextStyle(
    fontFamily: fontBody,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.onSurfaceMuted,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: AppColors.onPrimary,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: fontBody,
    fontSize: 11,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 42,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    color: AppColors.onSurface,
  );

  static const TextStyle metricSmall = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 28,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: AppColors.onSurface,
  );
}
