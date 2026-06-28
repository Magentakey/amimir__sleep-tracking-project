import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/local/local_achievement_service.dart';
import '../../data/models/achievement.dart';
import 'forum_providers.dart';
import 'widgets/forum_post_card.dart';
import 'widgets/create_post_sheet.dart';

/// Convert AchievementRarity enum ke string tanpa bergantung pada .name getter
String _rarityToString(AchievementRarity rarity) {
  switch (rarity) {
    case AchievementRarity.common:
      return 'common';
    case AchievementRarity.rare:
      return 'rare';
    case AchievementRarity.epic:
      return 'epic';
    case AchievementRarity.legendary:
      return 'legendary';
  }
}

class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  /// Fetch username + resolve equipped badge dari Firestore user doc.
  /// Badge detail di-lookup dari static achievement definitions (tidak perlu Hive async).
  Future<({String username, ForumBadge? badge})> _fetchAuthorMeta() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fallbackUsername =
        FirebaseAuth.instance.currentUser?.email ?? 'Anonymous';

    if (uid == null) return (username: fallbackUsername, badge: null);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = doc.data();
    if (data == null) return (username: fallbackUsername, badge: null);

    // username ada di root
    final username = data['username'] as String? ?? fallbackUsername;

    // equipped_achievement_id ada di nested profile map
    final profile = data['profile'] as Map<String, dynamic>?;
    final equippedId = profile?['equipped_achievement_id'] as String?;

    ForumBadge? badge;
    if (equippedId != null && equippedId.isNotEmpty) {
      // Lookup dari static definitions — tidak perlu async/Hive
      final definitions = LocalAchievementService().getAchievementDefinitions();
      final def = definitions.cast<dynamic>().firstWhere(
        (d) => d.id == equippedId,
        orElse: () => null,
      );
      if (def != null) {
        badge = ForumBadge(
          id: def.id,
          title: def.title,
          iconName: def.iconName,
          rarity: _rarityToString(def.rarity),
        );
      }
    }

    return (username: username, badge: badge);
  }

  void _openCreatePost() async {
    final meta = await _fetchAuthorMeta();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CreatePostSheet(username: meta.username, equippedBadge: meta.badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(forumPostsProvider);
    final filter = ref.watch(forumFilterProvider);

    return AppScaffold(
      currentIndex: 2, // adjust to your nav index for Forum
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Forum', style: AppTextStyles.headline),
                      const SizedBox(height: 2),
                      Text(
                        'Informasi & tips dari komunitas',
                        style: AppTextStyles.subtitle,
                      ),
                    ],
                  ),
                ),
                // Sort toggle
                _SortToggle(current: filter.sort),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Category filter row ──────────────────────────────
          _CategoryFilterRow(selected: filter.category),

          const SizedBox(height: 14),

          // ── Posts list ───────────────────────────────────────
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Gagal memuat forum.\n$e',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return _EmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => ForumPostCard(post: posts[i]),
                );
              },
            ),
          ),
        ],
      ),
      // FAB for creating post — overlaid via Stack in AppScaffold's body area
      // We use a custom FAB approach since AppScaffold doesn't expose floatingActionButton
    );
  }
}

// ── We wrap ForumScreen to inject FAB ───────────────────────

class ForumScreenWrapper extends ConsumerWidget {
  const ForumScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const ForumScreen(),
        Positioned(
          right: 18,
          bottom: 100, // above bottom nav
          child: _CreateFAB(),
        ),
      ],
    );
  }
}

class _CreateFAB extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final meta = await _fetchAuthorMeta();
        if (!context.mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => CreatePostSheet(
            username: meta.username,
            equippedBadge: meta.badge,
          ),
        );
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          gradient: AppColors.sleepGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x443C4B9E),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: AppColors.onPrimary,
          size: 28,
        ),
      ),
    );
  }

  Future<({String username, ForumBadge? badge})> _fetchAuthorMeta() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fallback = FirebaseAuth.instance.currentUser?.email ?? 'Anonymous';
    if (uid == null) return (username: fallback, badge: null);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    if (data == null) return (username: fallback, badge: null);

    final username = data['username'] as String? ?? fallback;
    final profile = data['profile'] as Map<String, dynamic>?;
    final equippedId = profile?['equipped_achievement_id'] as String?;

    ForumBadge? badge;
    if (equippedId != null && equippedId.isNotEmpty) {
      final definitions = LocalAchievementService().getAchievementDefinitions();
      final def = definitions.cast<dynamic>().firstWhere(
        (d) => d.id == equippedId,
        orElse: () => null,
      );
      if (def != null) {
        badge = ForumBadge(
          id: def.id,
          title: def.title,
          iconName: def.iconName,
          rarity: _rarityToString(def.rarity),
        );
      }
    }

    return (username: username, badge: badge);
  }
}

// ── Sort Toggle ──────────────────────────────────────────────

class _SortToggle extends ConsumerWidget {
  final ForumSort current;
  const _SortToggle({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortChip(
            label: 'Terbaru',
            icon: Icons.schedule_rounded,
            isActive: current == ForumSort.newest,
            onTap: () => ref
                .read(forumFilterProvider.notifier)
                .update((s) => s.copyWith(sort: ForumSort.newest)),
          ),
          _SortChip(
            label: 'Populer',
            icon: Icons.local_fire_department_rounded,
            isActive: current == ForumSort.popular,
            onTap: () => ref
                .read(forumFilterProvider.notifier)
                .update((s) => s.copyWith(sort: ForumSort.popular)),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.small.copyWith(
                color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Filter Row ──────────────────────────────────────

class _CategoryFilterRow extends ConsumerWidget {
  final String? selected;
  const _CategoryFilterRow({this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ['Semua', ...kForumCategories];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isAll = cat == 'Semua';
          final isActive = isAll ? selected == null : selected == cat;

          return GestureDetector(
            onTap: () {
              ref
                  .read(forumFilterProvider.notifier)
                  .update(
                    (s) => isAll
                        ? s.copyWith(clearCategory: true)
                        : s.copyWith(category: cat),
                  );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                cat,
                style: AppTextStyles.label.copyWith(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: AppColors.onSurfaceMuted,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text('Belum ada post', style: AppTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            'Jadilah yang pertama berbagi informasi!',
            style: AppTextStyles.subtitle,
          ),
        ],
      ),
    );
  }
}
