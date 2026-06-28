import 'package:cloud_firestore/cloud_firestore.dart';

import '../local/local_achievement_service.dart';
import '../local/local_daily_log_service.dart';
import '../local/local_sleep_service.dart';
import '../models/analysis_cache.dart';
import '../models/daily_log.dart';
import '../models/sleep_log.dart';
import 'analysis_repository.dart';

/// Ringkasan hasil backup/restore, dipakai untuk ditampilkan di UI Profile.
class BackupSummary {
  final int sleepLogCount;
  final int dailyLogCount;
  final int analysisCacheCount;
  final int achievementCount;
  final DateTime? backedUpAt;

  const BackupSummary({
    required this.sleepLogCount,
    required this.dailyLogCount,
    required this.analysisCacheCount,
    required this.achievementCount,
    this.backedUpAt,
  });
}

/// Backup & restore data lokal (Hive) ke/dari Firestore secara MANUAL,
/// dipicu user lewat tombol di Profile — bukan auto-sync realtime.
///
/// Kenapa manual:
/// - Tidak nambah biaya/quota Firestore kecuali user benar-benar klik
///   tombolnya.
/// - Data tracking (sleep/daily/analysis/achievement) tetap local-first
///   sesuai desain awal MVP; backup ini cuma jaring pengaman tambahan,
///   bukan pengganti local storage.
///
/// Catatan penting:
/// - Foto makanan (meal photo) TIDAK ikut ter-backup — yang disimpan
///   cuma path, note, dan waktunya. File foto aslinya cuma ada di local
///   storage device, jadi kalau restore di HP lain, foto tidak akan
///   muncul lagi (butuh fitur upload ke cloud storage terpisah untuk
///   itu).
class BackupRepository {
  final FirebaseFirestore _firestore;
  final LocalSleepService _sleepService;
  final LocalDailyLogService _dailyLogService;
  final AnalysisRepository _analysisRepository;
  final LocalAchievementService _achievementService;

  BackupRepository({
    FirebaseFirestore? firestore,
    LocalSleepService? sleepService,
    LocalDailyLogService? dailyLogService,
    AnalysisRepository? analysisRepository,
    LocalAchievementService? achievementService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _sleepService = sleepService ?? LocalSleepService(),
        _dailyLogService = dailyLogService ?? LocalDailyLogService(),
        _analysisRepository = analysisRepository ?? AnalysisRepository(),
        _achievementService = achievementService ?? LocalAchievementService();

  DocumentReference<Map<String, dynamic>> _backupDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('backups')
        .doc('latest');
  }

  /// Ambil info backup terakhir TANPA melakukan restore — dipakai untuk
  /// menampilkan "Backup terakhir: ..." di Profile.
  Future<BackupSummary?> getBackupInfo(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _backupDoc(uid).get();

    if (!doc.exists) {
      return null;
    }

    final Map<String, dynamic>? data = doc.data();

    if (data == null) {
      return null;
    }

    final Map<String, dynamic> counts =
        (data['counts'] as Map<String, dynamic>?) ?? {};
    final Timestamp? backedUpAtRaw = data['backedUpAt'] as Timestamp?;

    return BackupSummary(
      sleepLogCount: _toInt(counts['sleepLogs']),
      dailyLogCount: _toInt(counts['dailyLogs']),
      analysisCacheCount: _toInt(counts['analysisCaches']),
      achievementCount: _toInt(counts['unlockedAchievements']),
      backedUpAt: backedUpAtRaw?.toDate(),
    );
  }

  /// Upload semua data lokal user ke Firestore, menimpa backup lama
  /// (kalau ada).
  Future<BackupSummary> backupToCloud(String uid) async {
    final List<SleepLog> sleepLogs = _sleepService.getAllSleepLogs();
    final List<DailyLog> dailyLogs = _dailyLogService.getAllDailyLogs();
    final List<AnalysisCache> analysisCaches =
        _analysisRepository.getAllAnalysisCaches();
    final Map<String, DateTime> unlockedAchievements =
        _achievementService.getUnlockedAchievementMap();

    final Map<String, String> unlockedAchievementsEncoded =
        unlockedAchievements.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );

    await _backupDoc(uid).set({
      'sleepLogs': sleepLogs.map((log) => log.toMap()).toList(),
      'dailyLogs': dailyLogs.map((log) => log.toMap()).toList(),
      'analysisCaches': analysisCaches.map((cache) => cache.toMap()).toList(),
      'unlockedAchievements': unlockedAchievementsEncoded,
      'backedUpAt': FieldValue.serverTimestamp(),
      'counts': {
        'sleepLogs': sleepLogs.length,
        'dailyLogs': dailyLogs.length,
        'analysisCaches': analysisCaches.length,
        'unlockedAchievements': unlockedAchievements.length,
      },
    });

    return BackupSummary(
      sleepLogCount: sleepLogs.length,
      dailyLogCount: dailyLogs.length,
      analysisCacheCount: analysisCaches.length,
      achievementCount: unlockedAchievements.length,
      backedUpAt: DateTime.now(),
    );
  }

  /// Timpa semua data lokal user dengan data dari backup cloud terakhir.
  /// Melempar [StateError] kalau belum pernah ada backup tersimpan untuk
  /// akun ini.
  Future<BackupSummary> restoreFromCloud(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _backupDoc(uid).get();

    if (!doc.exists) {
      throw StateError('Belum ada backup tersimpan untuk akun ini.');
    }

    final Map<String, dynamic>? data = doc.data();

    if (data == null) {
      throw StateError('Data backup kosong atau rusak.');
    }

    final List<dynamic> rawSleepLogs =
        (data['sleepLogs'] as List<dynamic>?) ?? [];
    final List<dynamic> rawDailyLogs =
        (data['dailyLogs'] as List<dynamic>?) ?? [];
    final List<dynamic> rawAnalysisCaches =
        (data['analysisCaches'] as List<dynamic>?) ?? [];
    final Map<String, dynamic> rawUnlockedAchievements =
        (data['unlockedAchievements'] as Map<String, dynamic>?) ?? {};

    // Full overwrite: data lokal lama dibuang dulu sebelum diisi ulang
    // dari snapshot cloud, supaya tidak ada data lama yang tercampur.
    await _sleepService.clearAllSleepLogs();
    await _dailyLogService.clearAllDailyLogs();
    await _analysisRepository.clearAllAnalysisCaches();
    await _achievementService.clearUnlockedAchievementsOnly();

    for (final dynamic item in rawSleepLogs) {
      final SleepLog sleepLog = SleepLog.fromMap(
        Map<dynamic, dynamic>.from(item as Map),
      );
      await _sleepService.addSleepLog(sleepLog);
    }

    for (final dynamic item in rawDailyLogs) {
      final DailyLog dailyLog = DailyLog.fromMap(
        Map<dynamic, dynamic>.from(item as Map),
      );
      await _dailyLogService.addDailyLog(dailyLog);
    }

    for (final dynamic item in rawAnalysisCaches) {
      final AnalysisCache cache = AnalysisCache.fromMap(
        Map<dynamic, dynamic>.from(item as Map),
      );
      await _analysisRepository.saveAnalysisCache(cache);
    }

    final Map<String, DateTime> unlockedAchievements = {};

    rawUnlockedAchievements.forEach((key, value) {
      final DateTime? parsed = DateTime.tryParse(value.toString());

      if (parsed != null) {
        unlockedAchievements[key] = parsed;
      }
    });

    await _achievementService.restoreUnlockedAchievementMap(
      unlockedAchievements,
    );

    return BackupSummary(
      sleepLogCount: rawSleepLogs.length,
      dailyLogCount: rawDailyLogs.length,
      analysisCacheCount: rawAnalysisCaches.length,
      achievementCount: unlockedAchievements.length,
      backedUpAt: DateTime.now(),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
