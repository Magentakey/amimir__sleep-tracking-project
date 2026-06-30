import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../forum_providers.dart';

const List<String> kForumCategories = [
  'Umum',
  'Sleep Tips',
  'Achievement',
  'Pengalaman',
];

class CreatePostSheet extends ConsumerStatefulWidget {
  /// Pass the current user's equipped badge (from achievements provider)
  final ForumBadge? equippedBadge;
  final String username;

  const CreatePostSheet({
    super.key,
    required this.username,
    this.equippedBadge,
  });

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _contentController = TextEditingController();
  String _selectedCategory = kForumCategories.first;
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(forumServiceProvider)
          .createPost(
            content: content,
            category: _selectedCategory,
            username: widget.username,
            badge: widget.equippedBadge,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

          Text('Buat Post Baru', style: AppTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text(
            'Bagikan informasi, tips, atau pengalamanmu',
            style: AppTextStyles.subtitle,
          ),

          const SizedBox(height: 20),

          // Category selector
          Text('Kategori', style: AppTextStyles.label),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kForumCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = kForumCategories[i];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      cat,
                      style: AppTextStyles.label.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Content field
          Text('Konten', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _contentController,
              style: AppTextStyles.body,
              maxLines: 5,
              minLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Tulis sesuatu yang bermanfaat...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle: AppTextStyles.small,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.sleepGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton(
                onPressed: _isLoading ? null : _submit,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Publikasikan', style: AppTextStyles.button),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
