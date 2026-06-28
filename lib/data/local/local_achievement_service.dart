import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/user_session_service.dart';
import '../models/achievement.dart';
import '../models/analysis_cache.dart';
import '../models/daily_log.dart';
import '../models/sleep_log.dart';

class LocalAchievementService {
  /// Nama box ini sekarang per-akun (UID), bukan global lagi.
  /// Lihat [UserSessionService] untuk alasannya.
  static String get achievementsBoxName {
    final String? uid = UserSessionService.currentUid;

    if (uid == null) {
      throw StateError(
        'Tidak ada user yang login — box achievement belum bisa diakses.',
      );
    }

    return UserSessionService.boxNameFor(
      UserSessionService.achievementsPrefix,
      uid,
    );
  }

  static const String _unlockedMapKey = 'unlocked_achievement_map';
  static const String _equippedAchievementIdKey = 'equipped_achievement_id';

  Box get _box {
    return Hive.box(achievementsBoxName);
  }

  List<AchievementDefinition> getAchievementDefinitions() {
    return _achievementDefinitions;
  }

  Map<String, DateTime> getUnlockedAchievementMap() {
    final dynamic rawData = _box.get(_unlockedMapKey);

    if (rawData is! Map) {
      return {};
    }

    final Map<String, DateTime> result = {};

    rawData.forEach((key, value) {
      final String id = key.toString();
      final DateTime? unlockedAt = _parseDateTime(value);

      if (id.isNotEmpty && unlockedAt != null) {
        result[id] = unlockedAt;
      }
    });

    return result;
  }

  String? getEquippedAchievementId() {
    final String id = _box.get(_equippedAchievementIdKey)?.toString() ?? '';

    if (id.isEmpty) {
      return null;
    }

    return id;
  }

  Future<void> equipAchievement(String achievementId) async {
    await _box.put(_equippedAchievementIdKey, achievementId);

    await syncEquippedAchievementToFirebase(achievementId);
  }

  Future<void> unequipAchievement() async {
    await _box.delete(_equippedAchievementIdKey);

    await syncEquippedAchievementToFirebase(null);
  }

  Future<void> clearAchievementData() async {
    await _box.delete(_unlockedMapKey);
    await _box.delete(_equippedAchievementIdKey);
  }

  /// Hapus cuma daftar achievement yang ter-unlock (dipakai saat restore
  /// dari cloud backup). Equipped achievement TIDAK ikut terhapus karena
  /// itu sudah disinkronkan terpisah lewat Firestore profile (lihat
  /// [setEquippedFromFirestore]).
  Future<void> clearUnlockedAchievementsOnly() async {
    await _box.delete(_unlockedMapKey);
  }

  /// Timpa daftar achievement yang ter-unlock dengan data dari cloud
  /// backup (dipakai saat restore).
  Future<void> restoreUnlockedAchievementMap(
    Map<String, DateTime> unlockedMap,
  ) async {
    await _saveUnlockedAchievementMap(unlockedMap);
  }

  /// Dipanggil saat login untuk sync equipped dari Firestore ke Hive.
  /// Jika [achievementId] null/kosong, hapus dari Hive (akun baru atau tidak ada equipped).
  Future<void> setEquippedFromFirestore(String? achievementId) async {
    if (achievementId == null || achievementId.isEmpty) {
      await _box.delete(_equippedAchievementIdKey);
    } else {
      await _box.put(_equippedAchievementIdKey, achievementId);
    }
  }

  /// Cek semua achievement, unlock yang memenuhi syarat, dan simpan ke Hive.
  ///
  /// Return value adalah Dart record dengan dua field:
  /// - [all]           — daftar lengkap semua achievement beserta progress
  /// - [newlyUnlocked] — achievement yang baru saja ter-unlock pada pemanggilan
  ///                     ini (sebelumnya belum unlock). Dipakai oleh
  ///                     [achievementProgressProvider] untuk memicu banner
  ///                     in-app via [achievementUnlockQueueProvider].
  Future<
    ({List<AchievementProgress> all, List<AchievementDefinition> newlyUnlocked})
  >
  refreshAchievements({
    required List<SleepLog> sleepLogs,
    required List<DailyLog> dailyLogs,
    required List<AnalysisCache> analysisCaches,
  }) async {
    final Map<String, DateTime> unlockedMap = getUnlockedAchievementMap();
    final List<AchievementDefinition> newlyUnlocked = [];

    final String? equippedAchievementId = getEquippedAchievementId();

    final List<AchievementProgress> result = [];

    for (final AchievementDefinition definition in _achievementDefinitions) {
      final int progress = _calculateProgress(
        achievementId: definition.id,
        sleepLogs: sleepLogs,
        dailyLogs: dailyLogs,
        analysisCaches: analysisCaches,
      );

      DateTime? unlockedAt = unlockedMap[definition.id];

      if (unlockedAt == null && progress >= definition.targetProgress) {
        unlockedAt = DateTime.now();
        unlockedMap[definition.id] = unlockedAt;
        newlyUnlocked.add(definition);
      }

      result.add(
        AchievementProgress(
          definition: definition,
          currentProgress: progress,
          unlockedAt: unlockedAt,
          isEquipped: equippedAchievementId == definition.id,
        ),
      );
    }

    if (newlyUnlocked.isNotEmpty) {
      await _saveUnlockedAchievementMap(unlockedMap);
    }

    result.sort((a, b) {
      if (a.isEquipped && !b.isEquipped) {
        return -1;
      }

      if (!a.isEquipped && b.isEquipped) {
        return 1;
      }

      if (a.isUnlocked && !b.isUnlocked) {
        return -1;
      }

      if (!a.isUnlocked && b.isUnlocked) {
        return 1;
      }

      return a.definition.title.compareTo(b.definition.title);
    });

    return (all: result, newlyUnlocked: newlyUnlocked);
  }

  Future<void> syncEquippedAchievementToFirebase(String? achievementId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    // Pakai update dengan dot-notation agar profile fields lain tidak tertimpa
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'profile.equipped_achievement_id': achievementId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveUnlockedAchievementMap(
    Map<String, DateTime> unlockedMap,
  ) async {
    final Map<String, String> storedMap = {};

    unlockedMap.forEach((key, value) {
      storedMap[key] = value.toIso8601String();
    });

    await _box.put(_unlockedMapKey, storedMap);
  }

  int _calculateProgress({
    required String achievementId,
    required List<SleepLog> sleepLogs,
    required List<DailyLog> dailyLogs,
    required List<AnalysisCache> analysisCaches,
  }) {
    final List<SleepLog> normalizedSleepLogs = _sortSleepLogs(sleepLogs);
    final List<DailyLog> normalizedDailyLogs = _sortDailyLogs(dailyLogs);

    switch (achievementId) {
      case 'first_sleep_log':
        return normalizedSleepLogs.length;

      case 'healthy_sleeper':
        return normalizedSleepLogs.where(_isHealthySleep).length;

      case 'perfect_night':
        return normalizedSleepLogs.where(_isPerfectSleep).length;

      case 'short_sleeper':
        return normalizedSleepLogs.where(_isShortSleep).length;

      case 'long_dreamer':
        return normalizedSleepLogs.where(_isLongSleep).length;

      case 'tracker_3_days':
        return _maxSleepLogStreak(normalizedSleepLogs);

      case 'tracker_7_days':
        return _maxSleepLogStreak(normalizedSleepLogs);

      case 'sleep_discipline':
        return _maxSleepLogStreak(
          normalizedSleepLogs.where(_isHealthySleep).toList(),
        );

      case 'zombie_week':
        return _maxSleepLogStreak(
          normalizedSleepLogs.where(_isVeryShortSleep).toList(),
        );

      case 'daily_journal':
        return normalizedDailyLogs.length;

      case 'mood_tracker':
        return normalizedDailyLogs.where((dailyLog) {
          return dailyLog.mood.trim().isNotEmpty;
        }).length;

      case 'caffeine_aware':
        return normalizedDailyLogs.where((dailyLog) {
          return dailyLog.caffeineLogs.isNotEmpty;
        }).length;

      case 'meal_logger':
        return normalizedDailyLogs.where((dailyLog) {
          return dailyLog.mealLogs.isNotEmpty;
        }).length;

      case 'routine_builder':
        return normalizedDailyLogs.where((dailyLog) {
          return dailyLog.sleepHelpers.isNotEmpty;
        }).length;

      case 'full_daily_log':
        return normalizedDailyLogs.where(_isFullDailyLog).length;

      case 'first_insight':
        return analysisCaches.length;

      case 'weekly_reflection':
        return analysisCaches.where((cache) {
          return cache.periodType == 'weekly';
        }).length;

      case 'monthly_reflection':
        return analysisCaches.where((cache) {
          return cache.periodType == 'monthly';
        }).length;

      case 'data_storyteller':
        return analysisCaches.length;

      case 'no_caffeine_night':
        return _maxNoNightCaffeineStreak(
          sleepLogs: normalizedSleepLogs,
          dailyLogs: normalizedDailyLogs,
        );

      case 'early_bird':
        return _maxSleepLogStreak(
          normalizedSleepLogs.where((sleepLog) {
            return sleepLog.wakeTime.hour < 6;
          }).toList(),
        );

      case 'deep_habit':
        return normalizedSleepLogs.length;

      default:
        return 0;
    }
  }

  List<SleepLog> _sortSleepLogs(List<SleepLog> sleepLogs) {
    final List<SleepLog> logs = [...sleepLogs];

    logs.sort((a, b) {
      return _dateOnly(a.date).compareTo(_dateOnly(b.date));
    });

    return logs;
  }

  List<DailyLog> _sortDailyLogs(List<DailyLog> dailyLogs) {
    final List<DailyLog> logs = [...dailyLogs];

    logs.sort((a, b) {
      return _dateOnly(a.date).compareTo(_dateOnly(b.date));
    });

    return logs;
  }

  bool _isHealthySleep(SleepLog sleepLog) {
    return sleepLog.durationMinutes >= 7 * 60 &&
        sleepLog.durationMinutes <= 9 * 60;
  }

  bool _isPerfectSleep(SleepLog sleepLog) {
    return sleepLog.durationMinutes >= 465 && sleepLog.durationMinutes <= 495;
  }

  bool _isShortSleep(SleepLog sleepLog) {
    return sleepLog.durationMinutes < 4 * 60;
  }

  bool _isVeryShortSleep(SleepLog sleepLog) {
    return sleepLog.durationMinutes <= 3 * 60;
  }

  bool _isLongSleep(SleepLog sleepLog) {
    return sleepLog.durationMinutes > 10 * 60;
  }

  bool _isFullDailyLog(DailyLog dailyLog) {
    final bool hasMood = dailyLog.mood.trim().isNotEmpty;
    final bool hasSleepHelper = dailyLog.sleepHelpers.isNotEmpty;
    final bool hasCaffeine = dailyLog.caffeineLogs.isNotEmpty;
    final bool hasMeal = dailyLog.mealLogs.isNotEmpty;
    final bool hasActivity = dailyLog.activity.trim().isNotEmpty;

    return hasMood && hasSleepHelper && (hasCaffeine || hasMeal || hasActivity);
  }

  int _maxSleepLogStreak(List<SleepLog> sleepLogs) {
    final List<DateTime> dates = sleepLogs
        .map((sleepLog) {
          return _dateOnly(sleepLog.date);
        })
        .toSet()
        .toList();

    dates.sort();

    return _maxConsecutiveDateStreak(dates);
  }

  int _maxNoNightCaffeineStreak({
    required List<SleepLog> sleepLogs,
    required List<DailyLog> dailyLogs,
  }) {
    final Map<String, DailyLog> dailyLogMap = {};

    for (final DailyLog dailyLog in dailyLogs) {
      dailyLogMap[_dateKey(dailyLog.date)] = dailyLog;
    }

    final List<DateTime> qualifiedDates = [];

    for (final SleepLog sleepLog in sleepLogs) {
      final DateTime sleepDate = _dateOnly(sleepLog.date);
      final DailyLog? dailyLog = dailyLogMap[_dateKey(sleepDate)];

      if (dailyLog == null) {
        continue;
      }

      final bool hasNightCaffeine = dailyLog.caffeineLogs.any((caffeine) {
        return caffeine.dateTime.hour >= 18;
      });

      if (!hasNightCaffeine) {
        qualifiedDates.add(sleepDate);
      }
    }

    qualifiedDates.sort();

    return _maxConsecutiveDateStreak(qualifiedDates.toSet().toList());
  }

  int _maxConsecutiveDateStreak(List<DateTime> dates) {
    if (dates.isEmpty) {
      return 0;
    }

    final List<DateTime> sortedDates = dates.map(_dateOnly).toSet().toList();
    sortedDates.sort();

    int currentStreak = 1;
    int maxStreak = 1;

    for (int index = 1; index < sortedDates.length; index++) {
      final DateTime previousDate = sortedDates[index - 1];
      final DateTime currentDate = sortedDates[index];

      final int difference = currentDate.difference(previousDate).inDays;

      if (difference == 1) {
        currentStreak++;
      } else if (difference > 1) {
        currentStreak = 1;
      }

      if (currentStreak > maxStreak) {
        maxStreak = currentStreak;
      }
    }

    return maxStreak;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dateKey(DateTime value) {
    final DateTime date = _dateOnly(value);
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  static const List<AchievementDefinition> _achievementDefinitions = [
    AchievementDefinition(
      id: 'first_sleep_log',
      title: 'First Sleep Log',
      description: 'Catat sleep log pertama kamu.',
      iconName: 'bedtime',
      category: AchievementCategory.sleep,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'healthy_sleeper',
      title: 'Healthy Sleeper',
      description: 'Tidur dalam rentang 7 sampai 9 jam.',
      iconName: 'nightlight',
      category: AchievementCategory.sleep,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'perfect_night',
      title: 'Perfect Night',
      description: 'Tidur sekitar 8 jam, dengan toleransi 15 menit.',
      iconName: 'star',
      category: AchievementCategory.sleep,
      rarity: AchievementRarity.rare,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'short_sleeper',
      title: 'Short Sleeper',
      description: 'Pernah mencatat tidur kurang dari 4 jam.',
      iconName: 'warning',
      category: AchievementCategory.sleep,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'long_dreamer',
      title: 'Long Dreamer',
      description: 'Pernah mencatat tidur lebih dari 10 jam.',
      iconName: 'cloud',
      category: AchievementCategory.sleep,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'tracker_3_days',
      title: '3-Day Tracker',
      description: 'Catat sleep log 3 hari berturut-turut.',
      iconName: 'calendar',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.common,
      targetProgress: 3,
    ),
    AchievementDefinition(
      id: 'tracker_7_days',
      title: '7-Day Tracker',
      description: 'Catat sleep log 7 hari berturut-turut.',
      iconName: 'calendar_month',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.rare,
      targetProgress: 7,
    ),
    AchievementDefinition(
      id: 'sleep_discipline',
      title: 'Sleep Discipline',
      description: 'Tidur 7 sampai 9 jam selama 7 hari berturut-turut.',
      iconName: 'verified',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.epic,
      targetProgress: 7,
    ),
    AchievementDefinition(
      id: 'zombie_week',
      title: 'Zombie Week',
      description:
          'Tidur 3 jam atau kurang selama 7 hari berturut-turut. Ini pencapaian unik, tapi tubuhmu butuh pemulihan.',
      iconName: 'dark_mode',
      category: AchievementCategory.special,
      rarity: AchievementRarity.legendary,
      targetProgress: 7,
    ),
    AchievementDefinition(
      id: 'daily_journal',
      title: 'Daily Journal',
      description: 'Isi daily log pertama kamu.',
      iconName: 'notes',
      category: AchievementCategory.dailyLog,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'mood_tracker',
      title: 'Mood Tracker',
      description: 'Isi mood sebanyak 7 kali.',
      iconName: 'mood',
      category: AchievementCategory.dailyLog,
      rarity: AchievementRarity.common,
      targetProgress: 7,
    ),
    AchievementDefinition(
      id: 'caffeine_aware',
      title: 'Caffeine Aware',
      description: 'Catat caffeine pertama kamu.',
      iconName: 'coffee',
      category: AchievementCategory.dailyLog,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'meal_logger',
      title: 'Meal Logger',
      description: 'Ambil foto meal pertama kamu.',
      iconName: 'restaurant',
      category: AchievementCategory.dailyLog,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'routine_builder',
      title: 'Routine Builder',
      description: 'Gunakan sleep helper sebanyak 5 hari.',
      iconName: 'spa',
      category: AchievementCategory.dailyLog,
      rarity: AchievementRarity.rare,
      targetProgress: 5,
    ),
    AchievementDefinition(
      id: 'full_daily_log',
      title: 'Full Daily Log',
      description:
          'Isi daily log lengkap: mood, sleep helper, dan minimal satu data tambahan.',
      iconName: 'checklist',
      category: AchievementCategory.dailyLog,
      rarity: AchievementRarity.rare,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'first_insight',
      title: 'First Insight',
      description: 'Generate AI analysis pertama kamu.',
      iconName: 'auto_awesome',
      category: AchievementCategory.analysis,
      rarity: AchievementRarity.common,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'weekly_reflection',
      title: 'Weekly Reflection',
      description: 'Generate weekly analysis pertama kamu.',
      iconName: 'view_week',
      category: AchievementCategory.analysis,
      rarity: AchievementRarity.rare,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'monthly_reflection',
      title: 'Monthly Reflection',
      description: 'Generate monthly analysis pertama kamu.',
      iconName: 'calendar_month',
      category: AchievementCategory.analysis,
      rarity: AchievementRarity.rare,
      targetProgress: 1,
    ),
    AchievementDefinition(
      id: 'data_storyteller',
      title: 'Data Storyteller',
      description: 'Generate analysis sebanyak 10 kali.',
      iconName: 'psychology',
      category: AchievementCategory.analysis,
      rarity: AchievementRarity.epic,
      targetProgress: 10,
    ),
    AchievementDefinition(
      id: 'no_caffeine_night',
      title: 'No Caffeine Night',
      description:
          'Tidur dan tidak mencatat caffeine malam selama 7 hari berturut-turut.',
      iconName: 'local_drink',
      category: AchievementCategory.special,
      rarity: AchievementRarity.epic,
      targetProgress: 7,
    ),
    AchievementDefinition(
      id: 'early_bird',
      title: 'Early Bird',
      description: 'Bangun sebelum jam 6 pagi selama 5 hari berturut-turut.',
      iconName: 'wb_twilight',
      category: AchievementCategory.special,
      rarity: AchievementRarity.rare,
      targetProgress: 5,
    ),
    AchievementDefinition(
      id: 'deep_habit',
      title: 'Deep Habit',
      description: 'Catat total 30 sleep log.',
      iconName: 'emoji_events',
      category: AchievementCategory.special,
      rarity: AchievementRarity.epic,
      targetProgress: 30,
    ),
  ];
}
