import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../forum_providers.dart';

class ForumPostCard extends ConsumerWidget {
  final ForumPost post;

  const ForumPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hasLiked = post.likes.contains(currentUid);
    final hasDisliked = post.dislikes.contains(currentUid);
    final isAuthor = post.authorUid == currentUid;
    // Admin bisa hapus post siapapun — UID hardcoded di client untuk
    // menampilkan tombol. Enforcement sebenarnya ada di Firestore Rules
    // supaya tidak bisa di-bypass dari luar app.
    const String adminUid = 'KiIMlYV9jOO84SYD7vIgfX93b3u1';
    final bool canDelete = isAuthor || currentUid == adminUid;
    final service = ref.read(forumServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ambientShadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Author & Badge ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.sleepGradient,
                  ),
                  child: Center(
                    child: Text(
                      post.authorUsername.isNotEmpty
                          ? post.authorUsername[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorUsername,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (post.authorBadge != null)
                        _BadgeChip(badge: post.authorBadge!),
                    ],
                  ),
                ),
                // Category chip
                _CategoryChip(category: post.category),
                // More menu untuk author atau admin
                if (canDelete)
                  PopupMenuButton<String>(
                    color: AppColors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => _DeleteDialog(),
                        );
                        if (confirm == true) {
                          await service.deletePost(post.id);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hapus Post',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Content ─────────────────────────────────────────
            Text(post.content, style: AppTextStyles.body),

            const SizedBox(height: 16),

            // ── Footer: Time & Actions ───────────────────────────
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: AppColors.onSurfaceMuted,
                ),
                const SizedBox(width: 4),
                Text(_formatDate(post.createdAt), style: AppTextStyles.small),
                const Spacer(),
                // Like button
                _VoteButton(
                  icon: Icons.thumb_up_alt_rounded,
                  outlineIcon: Icons.thumb_up_alt_outlined,
                  count: post.likes.length,
                  isActive: hasLiked,
                  activeColor: AppColors.primary,
                  onTap: () => service.toggleLike(post),
                ),
                const SizedBox(width: 8),
                // Dislike button
                _VoteButton(
                  icon: Icons.thumb_down_alt_rounded,
                  outlineIcon: Icons.thumb_down_alt_outlined,
                  count: post.dislikes.length,
                  isActive: hasDisliked,
                  activeColor: AppColors.error,
                  onTap: () => service.toggleDislike(post),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('d MMMM yyyy, HH:mm', 'id').format(dt);
  }
}

// ── Badge Chip ───────────────────────────────────────────────

class _BadgeChip extends StatelessWidget {
  final ForumBadge badge;
  const _BadgeChip({required this.badge});

  Color get _rarityColor {
    switch (badge.rarity) {
      case 'legendary':
        return const Color(0xFFFFD700);
      case 'epic':
        return const Color(0xFFBF7FFF);
      case 'rare':
        return const Color(0xFF7FBBFF);
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _rarityColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _rarityColor.withOpacity(0.30), width: 1),
      ),
      child: Text(
        badge.title,
        style: AppTextStyles.small.copyWith(
          color: _rarityColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Category Chip ────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        category,
        style: AppTextStyles.small.copyWith(
          color: AppColors.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Vote Button ──────────────────────────────────────────────

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final IconData outlineIcon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.outlineIcon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.15)
              : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? icon : outlineIcon,
              size: 14,
              color: isActive ? activeColor : AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 5),
            Text(
              count.toString(),
              style: AppTextStyles.small.copyWith(
                color: isActive ? activeColor : AppColors.onSurfaceMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete Confirm Dialog ────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Hapus Post?', style: AppTextStyles.cardTitle),
      content: Text(
        'Post ini akan dihapus permanen dan tidak bisa dikembalikan.',
        style: AppTextStyles.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Hapus',
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
