import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/user_session_service.dart';
import '../models/daily_log.dart';

class LocalDailyLogService {
  /// Nama box ini sekarang per-akun (UID), bukan global lagi.
  /// Lihat [UserSessionService] untuk alasannya.
  static String get dailyLogsBoxName {
    final String? uid = UserSessionService.currentUid;

    if (uid == null) {
      throw StateError(
        'Tidak ada user yang login — box daily log belum bisa diakses.',
      );
    }

    return UserSessionService.boxNameFor(
      UserSessionService.dailyLogsPrefix,
      uid,
    );
  }

  Box get _box => Hive.box(dailyLogsBoxName);

  Future<void> addDailyLog(DailyLog dailyLog) async {
    final DailyLog normalizedLog = dailyLog.withNormalizedDate();

    await _box.put(normalizedLog.id, normalizedLog.toMap());
  }

  Future<void> saveDailyLogForDate(DailyLog dailyLog) async {
    final DateTime targetDate = DailyLog.dateOnly(dailyLog.date);
    final DailyLog? existingLog = getDailyLogByDate(targetDate);

    if (existingLog == null) {
      await addDailyLog(dailyLog.copyWith(date: targetDate));
      return;
    }

    final DailyLog updatedLog = dailyLog.copyWith(
      id: existingLog.id,
      date: targetDate,
      createdAt: existingLog.createdAt,
      updatedAt: DateTime.now(),
    );

    await _box.put(existingLog.id, updatedLog.toMap());
  }

  Future<DailyLog> getOrCreateDailyLogByDate(DateTime date) async {
    final DateTime targetDate = DailyLog.dateOnly(date);
    final DailyLog? existingLog = getDailyLogByDate(targetDate);

    if (existingLog != null) {
      return existingLog;
    }

    final DailyLog newLog = DailyLog.empty(targetDate);

    await addDailyLog(newLog);

    return newLog;
  }

  List<DailyLog> getAllDailyLogs() {
    final List<DailyLog> logs = [];

    for (final dynamic item in _box.values) {
      try {
        final DailyLog log = DailyLog.fromMap(item as Map<dynamic, dynamic>);
        logs.add(log.withNormalizedDate());
      } catch (_) {
        continue;
      }
    }

    logs.sort(_compareDailyLogsDescending);

    return logs;
  }

  DailyLog? getDailyLogByDate(DateTime date) {
    final DateTime targetDate = DailyLog.dateOnly(date);
    final List<DailyLog> logs = getAllDailyLogs();

    for (final DailyLog log in logs) {
      if (DailyLog.isSameDate(log.date, targetDate)) {
        return log;
      }
    }

    return null;
  }

  bool hasDailyLogByDate(DateTime date) {
    return getDailyLogByDate(date) != null;
  }

  List<DailyLog> getDailyLogsBetween({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<DailyLog> logs = getAllDailyLogs();

    final List<DailyLog> filteredLogs = logs.where((log) {
      return DailyLog.isDateInRange(
        date: log.date,
        startDate: startDate,
        endDate: endDate,
      );
    }).toList();

    filteredLogs.sort((a, b) => a.date.compareTo(b.date));

    return filteredLogs;
  }

  Future<void> updateDailyLog(DailyLog dailyLog) async {
    final DailyLog updatedLog = dailyLog.copyWith(
      date: DailyLog.dateOnly(dailyLog.date),
      updatedAt: DateTime.now(),
    );

    await _box.put(updatedLog.id, updatedLog.toMap());
  }

  Future<void> deleteDailyLog(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteDailyLogByDate(DateTime date) async {
    final DailyLog? log = getDailyLogByDate(date);

    if (log == null) {
      return;
    }

    await deleteDailyLog(log.id);
  }

  /// Hapus SEMUA data di box daily log. Dipakai saat restore dari cloud
  /// backup, supaya data lama tidak tercampur dengan data hasil restore.
  Future<void> clearAllDailyLogs() async {
    await _box.clear();
  }

  int _compareDailyLogsDescending(DailyLog first, DailyLog second) {
    final int dateCompare = second.date.compareTo(first.date);

    if (dateCompare != 0) {
      return dateCompare;
    }

    return second.createdAt.compareTo(first.createdAt);
  }
}
