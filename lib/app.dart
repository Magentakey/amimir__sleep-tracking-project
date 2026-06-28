import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/achievements/widgets/achievement_unlock_banner.dart';
import 'routes/app_router.dart';

class AmimirApp extends StatelessWidget {
  const AmimirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Amimir',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,

      // ── Achievement unlock banner ─────────────────────────────────────────
      // Dipasang di sini (bukan di AppScaffold) supaya banner muncul di
      // semua halaman termasuk Login, Register, dan layar tanpa scaffold.
      // [AchievementUnlockBanner] adalah ConsumerStatefulWidget yang
      // mendengarkan [achievementUnlockQueueProvider] — bisa melakukan ini
      // karena ProviderScope sudah ada di atas AmimirApp (lihat main.dart).
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AchievementUnlockBanner(),
            ),
          ],
        );
      },
    );
  }
}
