import 'package:flutter/material.dart';

class AppColors {
  // ============================================================
  // Nocturnal Elegance Design Tokens
  // ============================================================

  static const Color surface = Color(0xFF060E20);
  static const Color surfaceLowest = Color(0xFF050B19);
  static const Color surfaceLow = Color(0xFF08142D);
  static const Color surfaceContainer = Color(0xFF0A1836);
  static const Color surfaceContainerHigh = Color(0xFF0D1D40);
  static const Color surfaceContainerHighest = Color(0xFF11244C);
  static const Color surfaceVariant = Color(0xFF1A2C58);
  static const Color surfaceBright = Color(0xFF22366B);

  static const Color primary = Color(0xFFBAC3FF);
  static const Color primaryDim = Color(0xFF8F9CFF);
  static const Color primaryContainer = Color(0xFF3C4B9E);
  static const Color primaryFixedDim = Color(0xFFAAB5FF);

  static const Color secondary = Color(0xFFC8D6FF);
  static const Color secondaryContainer = Color(0xFF1B315F);

  static const Color tertiary = Color(0xFFF9E0FF);
  static const Color tertiaryContainer = Color(0xFF50335F);

  static const Color onSurface = Color(0xFFDEE5FF);
  static const Color onSurfaceVariant = Color(0xFF99AAD9);
  static const Color onSurfaceMuted = Color(0xFF7485B5);
  static const Color onPrimary = Color(0xFF071026);

  static const Color outlineVariant = Color(0xFF364770);
  static const Color error = Color(0xFFF97386);
  static const Color onError = Color(0xFF22060B);

  static const Color transparent = Colors.transparent;

  // ============================================================
  // Gradients
  // ============================================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  static const LinearGradient sleepGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBAC3FF), Color(0xFF6D7BFF), Color(0xFF3C4B9E)],
  );

  static const LinearGradient calmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11244C), Color(0xFF0A1836), Color(0xFF060E20)],
  );

  // ============================================================
  // Backward-compatible aliases
  // Jangan hapus agar halaman lama tidak error.
  // ============================================================

  static const Color background = surface;

  static const Color topBar = Color(0x991A2C58);
  static const Color bottomBar = Color(0x991A2C58);

  static const Color card = surfaceContainerHigh;
  static const Color cardDark = surfaceContainer;
  static const Color cardSoft = surfaceContainerHighest;

  static const Color primaryButton = primary;
  static const Color secondaryButton = secondaryContainer;

  static const Color circleButton = surfaceContainer;

  static const Color textDark = onSurface;
  static const Color textMuted = onSurfaceVariant;
  static const Color textLight = onSurface;

  static const Color softGlow = Color(0x1ABAC3FF);
  static const Color ambientShadow = Color(0x10DEE5FF);
}
