import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/analysis/analysis_screen.dart';
import '../features/auth/email_verification_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dev/hive_test_screen.dart';
import '../features/forum/forum_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/profile/disease_history_screen.dart';

class AppRoutePath {
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String analysis = '/analysis';
  static const String reports = '/reports';
  static const String profile = '/profile';
  static const String hiveTest = '/hive-test';
  static const String achievements = '/achievements';
  static const String forum = '/forum';
  static const String diseaseHistory = '/disease-history';
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutePath.login,
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) {
      final User? user = FirebaseAuth.instance.currentUser;
      final bool isLoggedIn = user != null;
      final bool isVerified = user?.emailVerified ?? false;

      final String currentPath = state.matchedLocation;

      final bool isAuthPage =
          currentPath == AppRoutePath.login ||
          currentPath == AppRoutePath.register;

      final bool isVerifyPage = currentPath == AppRoutePath.verifyEmail;

      // Belum login → ke /login (kecuali sudah di auth page)
      if (!isLoggedIn && !isAuthPage) {
        return AppRoutePath.login;
      }

      // Sudah login tapi belum verifikasi email → ke /verify-email
      // Pengecualian: kalau sudah di verify page, biarkan tetap di sana
      if (isLoggedIn && !isVerified && !isVerifyPage) {
        return AppRoutePath.verifyEmail;
      }

      // Sudah login DAN sudah verified → jangan bisa ke auth/verify page
      if (isLoggedIn && isVerified && (isAuthPage || isVerifyPage)) {
        return AppRoutePath.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutePath.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutePath.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutePath.verifyEmail,
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutePath.home,
        builder: (context, state) {
          final Object? extra = state.extra;
          final DateTime? targetDailyDate = extra is DateTime ? extra : null;
          return HomeScreen(targetDailyDate: targetDailyDate);
        },
      ),
      GoRoute(
        path: AppRoutePath.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutePath.analysis,
        builder: (context, state) => const AnalysisScreen(),
      ),
      GoRoute(
        path: AppRoutePath.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutePath.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutePath.hiveTest,
        builder: (context, state) => const HiveTestScreen(),
      ),
      GoRoute(
        path: AppRoutePath.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutePath.forum,
        builder: (context, state) => const ForumScreenWrapper(),
      ),
      GoRoute(
        path: AppRoutePath.diseaseHistory,
        builder: (context, state) => const DiseaseHistoryScreen(),
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((dynamic _) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
