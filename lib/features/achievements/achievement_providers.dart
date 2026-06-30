import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/local/local_achievement_service.dart';
import '../../data/models/achievement.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/analysis_repository.dart';
import '../analysis/analysis_providers.dart';
import '../daily_log/daily_log_providers.dart';
import '../notifications/app_notifications_provider.dart';
import '../sleep/sleep_providers.dart';

// ─── Service provider ─────────────────────────────────────────────────────────

final achievementServiceProvider = Provider<LocalAchievementService>((ref) {
  return LocalAchievementService();
});

// ─── Antrian unlock banner ────────────────────────────────────────────────────

/// Antrian achievement yang baru saja ter-unlock dan belum ditampilkan
/// sebagai banner in-app.
///
/// [AchievementUnlockBanner] (dipasang di root AmimirApp) mendengarkan
/// provider ini dan menampilkan banner satu per satu.
///
/// Item ditambahkan oleh [AchievementProgressNotifier.build()] setiap kali
/// [refreshAchievements] mendeteksi unlock baru.
/// Item dihapus oleh [AchievementUnlockBanner] setelah banner selesai tampil.
final achievementUnlockQueueProvider =
    StateProvider<List<AchievementDefinition>>((ref) => []);

// ─── Progress provider ────────────────────────────────────────────────────────

/// Daftar lengkap semua achievement beserta progress user saat ini.
///
/// Dikonversi dari [FutureProvider] ke [AsyncNotifierProvider] agar bisa
/// melakukan side-effect (push ke [achievementUnlockQueueProvider]) saat
/// achievement baru ter-unlock — sesuatu yang tidak bisa dilakukan dari
/// dalam [FutureProvider].
///
/// Return type tetap [AsyncValue<List<AchievementProgress>>], jadi semua
/// screen yang sudah watch provider ini tidak perlu diubah.
final achievementProgressProvider =
    AsyncNotifierProvider<AchievementProgressNotifier, List<AchievementProgress>>(
      AchievementProgressNotifier.new,
    );

class AchievementProgressNotifier
    extends AsyncNotifier<List<AchievementProgress>> {
  @override
  Future<List<AchievementProgress>> build() async {
    // Reactive: setiap kali salah satu provider ini berubah (misal setelah
    // save sleep log baru), build() akan re-run dan cek ulang achievement.
    final sleepService = ref.watch(sleepLogRepositoryProvider);
    final dailyLogService = ref.watch(dailyLogRepositoryProvider);
    final AnalysisRepository analysisRepository = ref.watch(
      analysisRepositoryProvider,
    );
    final LocalAchievementService achievementService = ref.watch(
      achievementServiceProvider,
    );

    final sleepLogs = sleepService.getAllSleepLogs();
    final dailyLogs = dailyLogService.getAllDailyLogs();
    final analysisCaches = analysisRepository.getAllAnalysisCaches();

    final result = await achievementService.refreshAchievements(
      sleepLogs: sleepLogs,
      dailyLogs: dailyLogs,
      analysisCaches: analysisCaches,
    );

    // Kalau ada achievement baru, masukkan ke antrian banner in-app.
    // ref.read (bukan ref.watch) karena ini side-effect, bukan dependency.
    if (result.newlyUnlocked.isNotEmpty) {
      ref
          .read(achievementUnlockQueueProvider.notifier)
          .update((state) => [...state, ...result.newlyUnlocked]);

      // Catat juga ke riwayat notifikasi lonceng (dropdown top bar) —
      // beda dari banner yang cuma tampil 4 detik lalu hilang, entry di
      // dropdown ini tetap ada sampai user buka dropdown-nya.
      final appNotificationService = ref.read(appNotificationServiceProvider);

      for (final AchievementDefinition def in result.newlyUnlocked) {
        await appNotificationService.add(
          AppNotification(
            id: 'achievement_${def.id}_${DateTime.now().millisecondsSinceEpoch}',
            type: AppNotificationType.achievement,
            title: 'Achievement Unlocked: ${def.title}',
            body: def.description,
            createdAt: DateTime.now(),
          ),
        );
      }

      ref.read(appNotificationsProvider.notifier).refresh();
    }

    return result.all;
  }
}

// ─── Equipped achievement ─────────────────────────────────────────────────────

final equippedAchievementProvider = Provider<AchievementProgress?>((ref) {
  final achievementProgressAsync = ref.watch(achievementProgressProvider);

  return achievementProgressAsync.maybeWhen(
    data: (achievements) {
      for (final AchievementProgress achievement in achievements) {
        if (achievement.isEquipped) {
          return achievement;
        }
      }

      return null;
    },
    orElse: () => null,
  );
});

// ─── Aksi equip/unequip ───────────────────────────────────────────────────────

// Provider untuk aksi equip/unequip — otomatis invalidate list setelah update
final achievementActionsProvider =
    AsyncNotifierProvider<AchievementActionsNotifier, void>(
      AchievementActionsNotifier.new,
    );

class AchievementActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> equip(String achievementId) async {
    state = const AsyncLoading();
    try {
      final LocalAchievementService service = ref.read(
        achievementServiceProvider,
      );
      await service.equipAchievement(achievementId);
      ref.invalidate(achievementProgressProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> unequip() async {
    state = const AsyncLoading();
    try {
      final LocalAchievementService service = ref.read(
        achievementServiceProvider,
      );
      await service.unequipAchievement();
      ref.invalidate(achievementProgressProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
