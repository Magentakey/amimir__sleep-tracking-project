import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final bool showBottomNavigation;
  final EdgeInsetsGeometry padding;

  const AppScaffold({
    super.key,
    required this.body,
    this.currentIndex = 0,
    this.showBottomNavigation = true,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 20),
  });

  // ── Navigation index mapping ─────────────────────────────
  // 0 → Dashboard
  // 1 → Analysis
  // 2 → Forum      ← NEW
  // 3 → Reports
  // 4 → Profile
  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutePath.dashboard);
        break;
      case 1:
        context.go(AppRoutePath.analysis);
        break;
      case 2:
        context.go(AppRoutePath.forum); // ← NEW
        break;
      case 3:
        context.go(AppRoutePath.reports);
        break;
      case 4:
        context.go(AppRoutePath.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _NocturnalBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: Padding(padding: padding, child: body),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: showBottomNavigation
          ? _buildBottomNavigation(context)
          : null,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.topBar,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ambientShadow,
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.sleepGradient,
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    size: 22,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('amimir', style: AppTextStyles.appLogo),
                const Spacer(),
                IconButton(
                  tooltip: 'Notification',
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primaryFixedDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bottomBar,
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ambientShadow,
                    blurRadius: 40,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (index) => _handleNavigation(context, index),
                // With 5 items, BottomNavigationBar requires type set to fixed
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_outlined),
                    activeIcon: Icon(Icons.dashboard_rounded),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.auto_awesome_outlined),
                    activeIcon: Icon(Icons.auto_awesome_rounded),
                    label: 'Analysis',
                  ),
                  // ── NEW ───────────────────────────────────────
                  BottomNavigationBarItem(
                    icon: Icon(Icons.forum_outlined),
                    activeIcon: Icon(Icons.forum_rounded),
                    label: 'Forum',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_outlined),
                    activeIcon: Icon(Icons.bar_chart_rounded),
                    label: 'Reports',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NocturnalBackground extends StatelessWidget {
  const _NocturnalBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.25,
          colors: [Color(0xFF142B63), Color(0xFF0A1836), Color(0xFF060E20)],
          stops: [0.0, 0.42, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 92,
            right: -42,
            child: _GlowOrb(size: 180, color: Color(0x333C4B9E)),
          ),
          Positioned(
            top: 360,
            left: -70,
            child: _GlowOrb(size: 220, color: Color(0x22F9E0FF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
