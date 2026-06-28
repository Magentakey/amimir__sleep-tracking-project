import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final ColorScheme colorScheme = const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      surface: AppColors.surface,
      error: AppColors.error,
      onSurface: AppColors.onSurface,
      onError: AppColors.onError,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.fontBody,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      canvasColor: AppColors.background,
      cardColor: AppColors.card,
      dividerColor: AppColors.transparent,
      splashColor: AppColors.primary.withValues(alpha: 0.08),
      highlightColor: AppColors.primary.withValues(alpha: 0.06),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appLogo,
        iconTheme: IconThemeData(color: AppColors.primaryFixedDim),
      ),

      textTheme: const TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        headlineMedium: AppTextStyles.headline,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.cardTitle,
        bodyLarge: AppTextStyles.bodyMedium,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.subtitle,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.label,
        labelSmall: AppTextStyles.small,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceMuted,
        selectedLabelStyle: AppTextStyles.navLabel,
        unselectedLabelStyle: AppTextStyles.navLabel,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: AppTextStyles.subtitle,
        hintStyle: AppTextStyles.subtitle,
        floatingLabelStyle: AppTextStyles.label.copyWith(
          color: AppColors.primaryDim,
        ),
        prefixIconColor: AppColors.primaryFixedDim,
        suffixIconColor: AppColors.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.primaryDim, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceContainerHighest,
          disabledForegroundColor: AppColors.onSurfaceMuted,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          shadowColor: AppColors.transparent,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          backgroundColor: AppColors.secondaryContainer,
          textStyle: AppTextStyles.button.copyWith(color: AppColors.onSurface),
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primaryContainer,
        disabledColor: AppColors.surfaceLow,
        labelStyle: AppTextStyles.label,
        secondaryLabelStyle: AppTextStyles.label.copyWith(
          color: AppColors.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        showCheckmark: false,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceContainerHighest,
        contentTextStyle: AppTextStyles.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        surfaceTintColor: AppColors.transparent,
        titleTextStyle: AppTextStyles.cardTitle,
        contentTextStyle: AppTextStyles.body,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceContainer,
        surfaceTintColor: AppColors.transparent,
        headerBackgroundColor: AppColors.surfaceContainerHighest,
        headerForegroundColor: AppColors.onSurface,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onPrimary;
          }

          return AppColors.onSurface;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }

          return AppColors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.all(AppColors.primary),
        todayBorder: const BorderSide(color: AppColors.primaryDim),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surfaceContainer,
        hourMinuteColor: AppColors.surfaceContainerHighest,
        hourMinuteTextColor: AppColors.onSurface,
        dialBackgroundColor: AppColors.surfaceLow,
        dialHandColor: AppColors.primary,
        dialTextColor: AppColors.onSurface,
        entryModeIconColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }

  // Backward-compatible getter.
  // app.dart lama masih memanggil AppTheme.lightTheme.
  // Dengan ini app tetap full dark mode tanpa wajib ubah app.dart.
  static ThemeData get lightTheme {
    return darkTheme;
  }
}
