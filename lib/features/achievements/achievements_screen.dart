import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/models/achievement.dart';
import 'achievement_providers.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementAsync = ref.watch(achievementProgressProvider);

    return AppScaffold(
      currentIndex: 3,
      body: achievementAsync.when(
        loading: () {
          return _buildLoadingState();
        },
        error: (error, stackTrace) {
          return _buildErrorState(error.toString());
        },
        data: (achievements) {
          final AchievementProgress? equippedAchievement =
              _findEquippedAchievement(achievements);

          final List<AchievementProgress> unlockedAchievements = achievements
              .where((achievement) => achievement.isUnlocked)
              .toList();

          final List<AchievementProgress> lockedAchievements = achievements
              .where((achievement) => !achievement.isUnlocked)
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroCard(
                  totalAchievement: achievements.length,
                  unlockedCount: unlockedAchievements.length,
                  equippedAchievement: equippedAchievement,
                ),
                const SizedBox(height: 18),
                _buildEquippedCard(
                  context: context,
                  ref: ref,
                  equippedAchievement: equippedAchievement,
                ),
                const SizedBox(height: 18),
                _buildProgressSummaryCard(
                  totalAchievement: achievements.length,
                  unlockedCount: unlockedAchievements.length,
                ),
                const SizedBox(height: 22),
                _buildSectionTitle(
                  title: 'Unlocked Achievements',
                  subtitle: 'Achievement yang sudah kamu dapatkan.',
                ),
                const SizedBox(height: 12),
                if (unlockedAchievements.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.lock_open_rounded,
                    title: 'Belum ada achievement terbuka',
                    subtitle:
                        'Catat sleep log, daily log, dan generate analysis untuk mulai membuka achievement.',
                  )
                else
                  ...unlockedAchievements.map((achievement) {
                    return _buildAchievementCard(
                      context: context,
                      ref: ref,
                      achievement: achievement,
                    );
                  }),
                const SizedBox(height: 22),
                _buildSectionTitle(
                  title: 'Locked Achievements',
                  subtitle: 'Progress achievement yang belum terbuka.',
                ),
                const SizedBox(height: 12),
                if (lockedAchievements.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Semua achievement sudah terbuka',
                    subtitle: 'Keren, semua achievement sudah kamu dapatkan.',
                  )
                else
                  ...lockedAchievements.map((achievement) {
                    return _buildAchievementCard(
                      context: context,
                      ref: ref,
                      achievement: achievement,
                    );
                  }),
                const SizedBox(height: 96),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: AppCard(
        color: AppColors.surfaceContainerHigh,
        padding: const EdgeInsets.all(24),
        radius: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading achievements...',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: AppCard(
        color: AppColors.error.withOpacity(0.16),
        padding: const EdgeInsets.all(24),
        radius: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              'Gagal memuat achievement.',
              style: AppTextStyles.cardTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  AchievementProgress? _findEquippedAchievement(
    List<AchievementProgress> achievements,
  ) {
    for (final AchievementProgress achievement in achievements) {
      if (achievement.isEquipped) {
        return achievement;
      }
    }

    return null;
  }

  Widget _buildHeroCard({
    required int totalAchievement,
    required int unlockedCount,
    required AchievementProgress? equippedAchievement,
  }) {
    return AppCard(
      color: AppColors.surfaceVariant.withOpacity(0.58),
      padding: const EdgeInsets.all(24),
      radius: 38,
      isGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievement room',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primaryFixedDim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your sleep badges',
            style: AppTextStyles.displayMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Unlock badges from sleep habits, daily logs, and AI analysis.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildHeroMetric(
                  icon: Icons.emoji_events_rounded,
                  label: 'Unlocked',
                  value: '$unlockedCount/$totalAchievement',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeroMetric(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Equipped',
                  value: equippedAchievement == null ? '-' : '1',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(14),
      radius: 26,
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryFixedDim, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.metricSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.small,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedCard({
    required BuildContext context,
    required WidgetRef ref,
    required AchievementProgress? equippedAchievement,
  }) {
    if (equippedAchievement == null) {
      return AppCard(
        color: AppColors.surfaceContainerHigh,
        padding: const EdgeInsets.all(22),
        radius: 34,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.calmGradient,
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.primaryFixedDim,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No equipped achievement',
              style: AppTextStyles.cardTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih salah satu unlocked achievement untuk dipasang di Profile dan nanti dipakai di Forum.',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAchievementIcon(equippedAchievement, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipped Achievement',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.primaryFixedDim,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      equippedAchievement.definition.title,
                      style: AppTextStyles.cardTitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            equippedAchievement.definition.description,
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final service = ref.read(achievementServiceProvider);
                await service.unequipAchievement();
                ref.invalidate(achievementProgressProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Achievement unequipped.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Unequip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummaryCard({
    required int totalAchievement,
    required int unlockedCount,
  }) {
    final double progress = totalAchievement == 0
        ? 0
        : unlockedCount / totalAchievement;

    return AppCard(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.all(18),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievement Progress',
            style: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: 8),
          Text(
            '$unlockedCount of $totalAchievement achievements unlocked.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headline),
        const SizedBox(height: 6),
        Text(subtitle, style: AppTextStyles.subtitle),
      ],
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return AppCard(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryFixedDim, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard({
    required BuildContext context,
    required WidgetRef ref,
    required AchievementProgress achievement,
  }) {
    final bool isUnlocked = achievement.isUnlocked;
    final bool isEquipped = achievement.isEquipped;

    return AppCard(
      color: isUnlocked
          ? AppColors.surfaceContainerHigh
          : AppColors.surfaceContainer,
      padding: const EdgeInsets.all(18),
      radius: 32,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAchievementIcon(achievement),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.definition.title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: isUnlocked
                            ? AppColors.onSurface
                            : AppColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      achievement.definition.description,
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSmallPill(
                          icon: Icons.category_rounded,
                          text: achievement.definition.category.name,
                        ),
                        _buildSmallPill(
                          icon: Icons.auto_awesome_rounded,
                          text: achievement.definition.rarity.name,
                        ),
                        if (isEquipped)
                          _buildSmallPill(
                            icon: Icons.check_circle_rounded,
                            text: 'equipped',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildProgressBar(achievement),
          const SizedBox(height: 14),
          if (isUnlocked)
            SizedBox(
              width: double.infinity,
              child: isEquipped
                  ? OutlinedButton.icon(
                      onPressed: () async {
                        final service = ref.read(achievementServiceProvider);
                        await service.unequipAchievement();
                        ref.invalidate(achievementProgressProvider);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Achievement unequipped.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Unequip'),
                    )
                  : ElevatedButton.icon(
                      onPressed: () async {
                        final service = ref.read(achievementServiceProvider);
                        await service.equipAchievement(achievement.id);
                        ref.invalidate(achievementProgressProvider);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${achievement.definition.title} equipped.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('Equip'),
                    ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Locked'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementIcon(
    AchievementProgress achievement, {
    double size = 50,
  }) {
    final bool isUnlocked = achievement.isUnlocked;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUnlocked ? AppColors.primaryGradient : null,
        color: isUnlocked ? null : AppColors.surfaceVariant,
      ),
      child: Icon(
        _iconFromName(achievement.definition.iconName),
        color: isUnlocked ? AppColors.onPrimary : AppColors.onSurfaceMuted,
        size: size * 0.48,
      ),
    );
  }

  Widget _buildSmallPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryFixedDim),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.small.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AchievementProgress achievement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                achievement.isUnlocked ? 'Unlocked' : 'Progress',
                style: AppTextStyles.small,
              ),
            ),
            Text(
              achievement.progressText,
              style: AppTextStyles.small.copyWith(
                color: AppColors.primaryFixedDim,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: achievement.progressPercent,
            minHeight: 9,
            backgroundColor: AppColors.surfaceVariant,
            color: achievement.isUnlocked
                ? AppColors.primary
                : AppColors.primaryDim,
          ),
        ),
      ],
    );
  }

  IconData _iconFromName(String iconName) {
    switch (iconName) {
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'nightlight':
        return Icons.nightlight_round;
      case 'star':
        return Icons.star_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      case 'calendar':
        return Icons.calendar_today_rounded;
      case 'calendar_month':
        return Icons.calendar_month_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'dark_mode':
        return Icons.dark_mode_rounded;
      case 'notes':
        return Icons.notes_rounded;
      case 'mood':
        return Icons.mood_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'checklist':
        return Icons.checklist_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'view_week':
        return Icons.view_week_rounded;
      case 'psychology':
        return Icons.psychology_alt_rounded;
      case 'local_drink':
        return Icons.local_drink_rounded;
      case 'wb_twilight':
        return Icons.wb_twilight_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }
}