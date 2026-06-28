import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/local/local_achievement_service.dart';
import '../achievements/achievement_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final AuthRepository authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  Future<void> build() async {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      await _authRepository.registerWithEmailAndPassword(
        email: email,
        password: password,
      );

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(_getErrorMessage(error), stackTrace);
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AsyncLoading();

    try {
      final UserCredential credential = await _authRepository
          .loginWithEmailAndPassword(email: email, password: password);

      // Achievement Sync v2: baca equipped dari Firestore, override Hive
      // (handles login akun lain — Hive selalu ikut Firestore akun yang baru login)
      final String? uid = credential.user?.uid;
      if (uid != null) {
        final String? equippedId = await _authRepository
            .fetchEquippedAchievementId(uid);

        final LocalAchievementService achievementService = ref.read(
          achievementServiceProvider,
        );
        await achievementService.setEquippedFromFirestore(equippedId);
      }

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(_getErrorMessage(error), stackTrace);
      return false;
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    state = const AsyncLoading();

    try {
      await _authRepository.sendPasswordResetEmail(email: email);

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(_getErrorMessage(error), stackTrace);
      return false;
    }
  }

  Future<bool> logout() async {
    state = const AsyncLoading();

    try {
      await _authRepository.logout();

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(_getErrorMessage(error), stackTrace);
      return false;
    }
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Format email tidak valid.';
        case 'user-not-found':
          return 'Akun tidak ditemukan.';
        case 'wrong-password':
          return 'Password salah.';
        case 'email-already-in-use':
          return 'Email sudah digunakan.';
        case 'weak-password':
          return 'Password terlalu lemah.';
        case 'network-request-failed':
          return 'Koneksi internet bermasalah.';
        default:
          return error.message ?? 'Terjadi kesalahan autentikasi.';
      }
    }

    return error.toString();
  }
}
