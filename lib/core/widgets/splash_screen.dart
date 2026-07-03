import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Splash screen yang muncul selama SessionGate menunggu Firebase Auth
/// dan membuka Hive box — menggantikan placeholder CircularProgressIndicator
/// yang sebelumnya ditampilkan di sana.
///
/// Animasi:
/// 1. Background gradient radial fade in (300ms)
/// 2. Logo bulan + nama "amimir" fade-in + slide-up ringan (600ms, delay 200ms)
/// 3. Tagline fade in (400ms, delay 600ms)
/// 4. Three-dot pulse loader di bawah (loop, delay 800ms)
///
/// Tidak ada timer hardcoded — splash tetap tampil selama SessionGate
/// benar-benar butuh waktu untuk selesai, lalu langsung diganti oleh
/// child (AmimirApp). Transisi dari splash ke app terasa smooth karena
/// background color-nya sama.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────

  late final AnimationController _bgController;
  late final AnimationController _logoController;
  late final AnimationController _taglineController;
  late final AnimationController _dotsController;

  // ── Animations ─────────────────────────────────────────────────────────────

  late final Animation<double> _bgFade;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    // Background
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bgFade = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);

    // Logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    // Tagline
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _taglineFade = CurvedAnimation(
      parent: _taglineController,
      curve: Curves.easeOut,
    );

    // Dots loader (infinite loop)
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Sequence
    _bgController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _logoController.forward();
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _taglineController.forward();
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _dotsController.repeat();
      });
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _taglineController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _bgFade,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.35,
            colors: [
              Color(0xFF142B63),
              Color(0xFF0A1836),
              Color(0xFF060E20),
            ],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Background glow orbs ────────────────────────────────────
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.08,
              right: -60,
              child: _GlowOrb(size: 200, color: const Color(0x333C4B9E)),
            ),
            Positioned(
              bottom: MediaQuery.sizeOf(context).height * 0.15,
              left: -80,
              child: _GlowOrb(size: 240, color: const Color(0x1AF9E0FF)),
            ),

            // ── Konten utama ────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo + nama
                  FadeTransition(
                    opacity: _logoFade,
                    child: SlideTransition(
                      position: _logoSlide,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ikon bulan dengan glow
                          _MoonIcon(),
                          const SizedBox(height: 28),

                          // Nama app
                          Text(
                            'amimir',
                            style: AppTextStyles.displayMedium.copyWith(
                              letterSpacing: -1.6,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tagline
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'Track your sleep, improve your life.',
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Three-dot pulse loader
                  FadeTransition(
                    opacity: _taglineFade,
                    child: _DotsLoader(controller: _dotsController),
                  ),
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Moon icon ───────────────────────────────────────────────────────────────

class _MoonIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
        // Icon container
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.sleepGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.softGlow,
                blurRadius: 36,
                offset: Offset(0, 12),
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.nightlight_round,
            size: 48,
            color: AppColors.onPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Three-dot pulse loader ───────────────────────────────────────────────────

class _DotsLoader extends AnimatedWidget {
  const _DotsLoader({required AnimationController controller})
      : super(listenable: controller);

  static const int _dotCount = 3;
  static const double _dotSize = 6;
  static const double _dotSpacing = 10;

  @override
  Widget build(BuildContext context) {
    final double t = (listenable as AnimationController).value;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_dotCount, (i) {
        // Tiap dot punya fase yang offset 0.33 dari dot sebelumnya
        final double phase = (t + i / _dotCount) % 1.0;

        // Pulse: naik dari 0.4 → 1.0 → 0.4 menggunakan sine
        final double scale = 0.4 + 0.6 * math.sin(phase * math.pi);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: _dotSpacing / 2),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryFixedDim.withValues(
                  alpha: 0.4 + 0.6 * scale,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Glow orb (sama dengan yang di app_scaffold) ─────────────────────────────

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
