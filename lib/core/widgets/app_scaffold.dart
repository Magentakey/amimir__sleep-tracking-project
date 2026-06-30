import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/app_notification.dart';
import '../../features/notifications/app_notifications_provider.dart';
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
                Expanded(child: Padding(padding: padding, child: body)),
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
                const _NotificationBellButton(),
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

// ─── Notification Bell ──────────────────────────────────────────────────────

/// Ikon lonceng dengan badge counter notifikasi belum dibaca, plus
/// dropdown daftar notifikasi saat di-tap.
///
/// Isi dropdown: notifikasi achievement unlock + pengingat harian. Tidak
/// ada screen terpisah — semuanya tampil di dropdown ini saja.
///
/// Counter hilang begitu dropdown dibuka (semua ditandai sudah dibaca),
/// dan akan muncul lagi kalau ada notifikasi baru masuk setelahnya.
class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  Future<void> _openDropdown(BuildContext context, WidgetRef ref) async {
    // Tandai semua sudah dibaca SEKARANG (saat lonceng dipencet) —
    // bukan saat dropdown ditutup — sesuai permintaan: counter hilang
    // begitu lonceng di-tap.
    await ref.read(appNotificationsProvider.notifier).markAllRead();

    final List<AppNotification> notifications = ref.read(
      appNotificationsProvider,
    );

    if (!context.mounted) return;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          button.size.bottomLeft(Offset.zero),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    await showMenu<void>(
      context: context,
      position: position,
      color: AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _NotificationDropdownContent(notifications: notifications),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notification',
          onPressed: () => _openDropdown(context, ref),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.primaryFixedDim,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.topBar, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Isi dropdown lonceng — daftar notifikasi achievement + pengingat harian.
class _NotificationDropdownContent extends StatelessWidget {
  final List<AppNotification> notifications;

  const _NotificationDropdownContent({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('Notifikasi', style: AppTextStyles.cardTitle),
            ),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Text(
                  'Belum ada notifikasi.',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: AppColors.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    return _NotificationRow(notification: notifications[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;

  const _NotificationRow({required this.notification});

  @override
  Widget build(BuildContext context) {
    final bool isAchievement =
        notification.type == AppNotificationType.achievement;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerHighest,
            ),
            child: Icon(
              isAchievement
                  ? Icons.emoji_events_rounded
                  : Icons.notifications_active_rounded,
              size: 18,
              color: isAchievement
                  ? const Color(0xFFFFD700)
                  : AppColors.primaryFixedDim,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRelativeTime(notification.createdAt),
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';

    return DateFormat('d MMM yyyy', 'id').format(dt);
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
