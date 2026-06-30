import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/achievement.dart';
import '../achievement_providers.dart';

/// Overlay in-app yang menampilkan banner "Achievement Unlocked!" saat
/// achievement baru ter-unlock.
///
/// Widget ini dipasang di root [AmimirApp] via [MaterialApp.router.builder]
/// sehingga selalu aktif di semua halaman. Banner muncul dari atas layar,
/// tampil 4 detik, lalu slide kembali ke atas.
///
/// Kalau lebih dari satu achievement unlock sekaligus (misal setelah
/// restore backup), akan ditampilkan satu per satu secara antrian.
///
/// Notifikasi ini TIDAK dikirim ke OS — hanya muncul di dalam app.
/// Untuk notifikasi OS lihat [NotificationService].
class AchievementUnlockBanner extends ConsumerStatefulWidget {
  const AchievementUnlockBanner({super.key});

  @override
  ConsumerState<AchievementUnlockBanner> createState() =>
      _AchievementUnlockBannerState();
}

class _AchievementUnlockBannerState
    extends ConsumerState<AchievementUnlockBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  AchievementDefinition? _current;

  /// True saat banner sedang tampil (animasi masuk/keluar atau jeda 4 detik).
  bool _isBusy = false;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ─── Riverpod listener ─────────────────────────────────────────────────────

  // [ref.listen] di dalam build() adalah cara idiomatis Riverpod untuk
  // bereaksi terhadap perubahan state dan memicu efek samping.

  @override
  Widget build(BuildContext context) {
    // GLOBAL TRIGGER: widget ini selalu terpasang di root app (lihat
    // app.dart), jadi men-watch achievementProgressProvider di sini
    // membuat pengecekan achievement berjalan otomatis dari MANA SAJA —
    // bukan cuma saat user membuka Profile/Achievements screen.
    //
    // Tanpa baris ini, ref.invalidate(achievementProgressProvider) yang
    // dipanggil dari home_screen/dashboard_screen/analysis_screen cuma
    // menandai provider "dirty" tanpa benar-benar menjalankan ulang
    // build()-nya (AsyncNotifierProvider bersifat lazy — baru dihitung
    // ulang saat ada yang men-watch/membaca). Itu sebabnya sebelumnya
    // notifikasi achievement baru muncul setelah user balik ke menu
    // Profile, karena di situlah provider ini pertama kali di-watch
    // ulang setelah invalidate.
    ref.watch(achievementProgressProvider);

    ref.listen<List<AchievementDefinition>>(achievementUnlockQueueProvider, (
      prev,
      next,
    ) {
      if (next.isNotEmpty && !_isBusy) {
        _showNext(next.first);
      }
    });

    if (_current == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(opacity: _fade, child: _buildBanner(_current!)),
        ),
      ),
    );
  }

  // ─── Logika antrian ───────────────────────────────────────────────────────

  void _showNext(AchievementDefinition achievement) {
    if (_isBusy || !mounted) return;

    _isBusy = true;

    setState(() {
      _current = achievement;
    });

    _controller.forward(from: 0);

    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  Future<void> _dismiss() async {
    _dismissTimer?.cancel();

    await _controller.reverse();

    if (!mounted) return;

    // Hapus item pertama dari antrian
    ref
        .read(achievementUnlockQueueProvider.notifier)
        .update((state) => state.isEmpty ? [] : state.sublist(1));

    if (!mounted) return;

    setState(() {
      _current = null;
      _isBusy = false;
    });

    // Cek apakah masih ada antrian — kalau iya, tampilkan setelah jeda kecil
    // supaya animasi tidak langsung nyambung tanpa jeda.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    final List<AchievementDefinition> remaining = ref.read(
      achievementUnlockQueueProvider,
    );

    if (remaining.isNotEmpty) {
      _showNext(remaining.first);
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  Widget _buildBanner(AchievementDefinition achievement) {
    final Color rarityColor = _rarityColor(achievement.rarity);
    final String rarityLabel = _rarityLabel(achievement.rarity);
    final IconData rarityIcon = _rarityIcon(achievement.rarity);

    return GestureDetector(
      onTap: _dismiss,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            const BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // ── Ikon rarity ──────────────────────────────────────────────────
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rarityColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: rarityColor.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: Icon(rarityIcon, color: rarityColor, size: 26),
            ),
            const SizedBox(width: 14),

            // ── Teks ─────────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '🏆  Achievement Unlocked!',
                        style: AppTextStyles.small.copyWith(
                          color: rarityColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rarityLabel,
                          style: AppTextStyles.small.copyWith(
                            color: rarityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    achievement.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Tombol tutup ─────────────────────────────────────────────────
            const SizedBox(width: 8),
            Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper rarity ────────────────────────────────────────────────────────

  Color _rarityColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return AppColors.onSurfaceVariant;
      case AchievementRarity.rare:
        return const Color(0xFF60AAFF); // biru
      case AchievementRarity.epic:
        return const Color(0xFFBB86FC); // ungu
      case AchievementRarity.legendary:
        return const Color(0xFFFFD700); // gold
    }
  }

  String _rarityLabel(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Common';
      case AchievementRarity.rare:
        return 'Rare';
      case AchievementRarity.epic:
        return 'Epic';
      case AchievementRarity.legendary:
        return 'Legendary';
    }
  }

  IconData _rarityIcon(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Icons.emoji_events_outlined;
      case AchievementRarity.rare:
        return Icons.emoji_events_rounded;
      case AchievementRarity.epic:
        return Icons.military_tech_rounded;
      case AchievementRarity.legendary:
        return Icons.workspace_premium_rounded;
    }
  }
}
