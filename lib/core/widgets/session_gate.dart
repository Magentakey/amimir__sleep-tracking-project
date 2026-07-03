import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/achievements/achievement_providers.dart';
import '../../features/daily_log/daily_log_providers.dart';
import '../../features/notifications/app_notifications_provider.dart';
import '../../features/sleep/sleep_providers.dart';
import '../../data/local/local_settings_service.dart';
import '../constants/app_colors.dart';
import '../services/user_session_service.dart';
import '../theme/app_theme.dart';
import 'splash_screen.dart';

/// Widget akar yang memastikan Hive box milik user yang benar sudah
/// terbuka SEBELUM layar manapun (Home, Dashboard, dst) dirender.
///
/// Kenapa perlu ini:
/// Setiap akun (uid) sekarang punya box Hive sendiri-sendiri (lihat
/// [UserSessionService]) supaya data sleep log / daily log / analysis /
/// achievement antar akun tidak ketuker di satu HP yang sama. Box itu
/// baru bisa dibuka setelah kita tahu siapa yang login, jadi SessionGate
/// menunggu event auth pertama, buka/tutup box yang relevan, baru
/// menampilkan aplikasi sesungguhnya ([child]).
class SessionGate extends ConsumerStatefulWidget {
  const SessionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends ConsumerState<SessionGate> {
  StreamSubscription<User?>? _subscription;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
  }

  Future<void> _handleAuthChange(User? user) async {
    if (mounted) {
      setState(() {
        _ready = false;
      });
    }

    // Bersihkan antrian banner achievement sebelum ganti user/logout.
    // Tanpa ini, notifikasi achievement dari sesi sebelumnya bisa muncul
    // lagi saat user login ulang (karena StateProvider tidak auto-reset).
    ref.read(achievementUnlockQueueProvider.notifier).state = [];

    if (user == null) {
      await UserSessionService.closeCurrentUserBoxes();
    } else {
      await UserSessionService.openBoxesForUser(user.uid);

      // Simpan UID terakhir yang login ke box global, supaya WorkManager
      // callback (background isolate, lihat main.dart) tahu box notifikasi
      // siapa yang harus ditulis saat pengingat harian fire — isolate itu
      // tidak bisa baca UserSessionService.currentUid karena itu
      // in-memory dan tidak ikut ter-share antar isolate.
      await LocalSettingsService().setLastUid(user.uid);
    }

    // Provider data lama bisa jadi masih nyangkut punya akun sebelumnya
    ref.invalidate(latestSleepLogProvider);
    ref.invalidate(allSleepLogsProvider);
    ref.invalidate(todayDailyLogProvider);
    ref.invalidate(achievementProgressProvider);
    ref.invalidate(appNotificationsProvider);

    if (mounted) {
      setState(() {
        _ready = true;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          backgroundColor: AppColors.surface,
          body: SplashScreen(),
        ),
      );
    }

    return widget.child;
  }
}
