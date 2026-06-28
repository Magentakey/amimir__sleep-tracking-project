import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AuthHeader extends StatelessWidget {
  final String subtitle;
  final String eyebrow;
  final String title;

  const AuthHeader({
    super.key,
    required this.subtitle,
    this.eyebrow = 'The Digital Sanctuary',
    this.title = 'amimir',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.sleepGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.softGlow,
                blurRadius: 42,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: const Icon(
            Icons.nightlight_round,
            size: 42,
            color: AppColors.onPrimary,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          eyebrow,
          style: AppTextStyles.label.copyWith(
            color: AppColors.primaryFixedDim,
            letterSpacing: 0.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: AppTextStyles.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: AppTextStyles.subtitle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
