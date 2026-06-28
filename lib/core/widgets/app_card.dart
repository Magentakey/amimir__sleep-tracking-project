import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? width;
  final VoidCallback? onTap;

  final bool isGlass;
  final bool useGradient;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const AppCard({
    super.key,
    required this.child,
    this.color = AppColors.cardSoft,
    this.padding = const EdgeInsets.all(22),
    this.margin,
    this.radius = 32,
    this.width = double.infinity,
    this.onTap,
    this.isGlass = false,
    this.useGradient = false,
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    Widget card = Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: useGradient ? null : color,
        gradient: useGradient ? (gradient ?? AppColors.primaryGradient) : null,
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: isGlass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: _buildContent(),
              )
            : _buildContent(),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: AppColors.transparent,
        borderRadius: borderRadius,
        child: InkWell(borderRadius: borderRadius, onTap: onTap, child: card),
      );
    }

    return card;
  }

  Widget _buildContent() {
    return Padding(padding: padding, child: child);
  }
}
