import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/user_session_service.dart';
import '../models/sleep_log.dart';

class LocalSleepService {
  /// Nama box ini sekarang per-akun (UID), bukan global lagi.
  /// Lihat [UserSessionService] untuk alasannya.
  static String get sleepLogsBoxName {
    final String? uid = UserSessionService.currentUid;

    if (uid == null) {
      throw StateError(
        'Tidak ada user yang login — box sleep log belum bisa diakses.',
      );
    }

    return UserSessionService.boxNameFor(
      UserSessionService.sleepLogsPrefix,
      uid,
    );
  }

  Box get _box => Hive.box(sleepLogsBoxName);

  Future<void> addSleepLog(SleepLog sleepLog) async {
    final SleepLog normalizedLog = sleepLog.withNormalizedDate();

    await _box.put(normalizedLog.id, normalizedLog.toMap());
  }

  Future<void> saveSleepLogForDate(SleepLog sleepLog) async {
    final DateTime targetDate = SleepLog.dateOnly(sleepLog.date);
    final SleepLog? existingLog = getSleepLogByDate(targetDate);

    if (existingLog == null) {
      await addSleepLog(sleepLog.copyWith(date: targetDate));
      return;
    }

    final SleepLog updatedLog = sleepLog.copyWith(
      id: existingLog.id,
      date: targetDate,
      createdAt: existingLog.createdAt,
      updatedAt: DateTime.now(),
    );

    await _box.put(existingLog.id, updatedLog.toMap());
  }

  List<SleepLog> getAllSleepLogs() {
    final List<SleepLog> logs = [];

    for (final dynamic item in _box.values) {
      try {
        final SleepLog log = SleepLog.fromMap(item as Map<dynamic, dynamic>);
        logs.add(log.withNormalizedDate());
      } catch (_) {
        continue;
      }
    }

    logs.sort(_compareSleepLogsDescending);

    return logs;
  }

  SleepLog? getSleepLogByDate(DateTime date) {
    final DateTime targetDate = SleepLog.dateOnly(date);
    final List<SleepLog> logs = getAllSleepLogs();

    for (final SleepLog log in logs) {
      if (SleepLog.isSameDate(log.date, targetDate)) {
        return log;
      }
    }

    return null;
  }

  bool hasSleepLogByDate(DateTime date) {
    return getSleepLogByDate(date) != null;
  }

  List<SleepLog> getSleepLogsBetween({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<SleepLog> logs = getAllSleepLogs();

    final List<SleepLog> filteredLogs = logs.where((log) {
      return SleepLog.isDateInRange(
        date: log.date,
        startDate: startDate,
        endDate: endDate,
      );
    }).toList();

    filteredLogs.sort((a, b) => a.date.compareTo(b.date));

    return filteredLogs;
  }

  Future<void> updateSleepLog(SleepLog sleepLog) async {
    final SleepLog updatedLog = sleepLog.copyWith(
      date: SleepLog.dateOnly(sleepLog.date),
      updatedAt: DateTime.now(),
    );

    await _box.put(updatedLog.id, updatedLog.toMap());
  }

  SleepLog? getLatestSleepLog() {
    final List<SleepLog> logs = getAllSleepLogs();

    if (logs.isEmpty) {
      return null;
    }

    return logs.first;
  }

  DateTime? getLatestSleepLogDate() {
    final SleepLog? latestLog = getLatestSleepLog();

    if (latestLog == null) {
      return null;
    }

    return SleepLog.dateOnly(latestLog.date);
  }

  List<DateTime> getMissingSleepDates({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final DateTime start = SleepLog.dateOnly(startDate);
    final DateTime end = SleepLog.dateOnly(endDate);

    final Set<String> recordedDates =
        getSleepLogsBetween(startDate: start, endDate: end).map((log) {
          final DateTime logDate = SleepLog.dateOnly(log.date);
          return _dateKey(logDate);
        }).toSet();

    final List<DateTime> missingDates = [];

    DateTime currentDate = start;

    while (!currentDate.isAfter(end)) {
      if (!recordedDates.contains(_dateKey(currentDate))) {
        missingDates.add(currentDate);
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return missingDates;
  }

  Future<void> deleteSleepLog(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteSleepLogByDate(DateTime date) async {
    final SleepLog? log = getSleepLogByDate(date);

    if (log == null) {
      return;
    }

    await deleteSleepLog(log.id);
  }

  /// Hapus SEMUA data di box sleep log (termasuk sesi tidur aktif kalau
  /// ada). Dipakai saat restore dari cloud backup, supaya data lama tidak
  /// tercampur dengan data hasil restore.
  Future<void> clearAllSleepLogs() async {
    await _box.clear();
  }

  // ─── Active Sleep Session ─────────────────────────────────────────────────
  // Kunci khusus pakai prefix __meta_ agar tidak bentrok dengan ID sleep log.

  static const String _activeSleepStartKey = '__meta_active_sleep_start';
  static const String _activeSleepDateKey = '__meta_active_sleep_date';

  /// Simpan sesi tidur aktif ke Hive.
  /// Dipanggil saat user tap START. Timer akurat meski app ditutup/HP mati
  /// karena waktu mulai tersimpan permanen, bukan di memori.
  Future<void> saveActiveSleepSession({
    required DateTime startTime,
    required DateTime targetDate,
  }) async {
    await _box.put(_activeSleepStartKey, startTime.toIso8601String());
    await _box.put(_activeSleepDateKey, targetDate.toIso8601String());
  }

  /// Hapus sesi tidur aktif setelah berhasil disimpan sebagai SleepLog.
  Future<void> clearActiveSleepSession() async {
    await _box.delete(_activeSleepStartKey);
    await _box.delete(_activeSleepDateKey);
  }

  /// Baca sesi tidur aktif dari Hive. Null jika tidak ada.
  ({DateTime startTime, DateTime targetDate})? getActiveSleepSession() {
    final dynamic startRaw = _box.get(_activeSleepStartKey);
    final dynamic dateRaw = _box.get(_activeSleepDateKey);

    if (startRaw == null || dateRaw == null) return null;

    final DateTime? startTime = DateTime.tryParse(startRaw.toString());
    final DateTime? targetDate = DateTime.tryParse(dateRaw.toString());

    if (startTime == null || targetDate == null) return null;

    return (startTime: startTime, targetDate: targetDate);
  }

  // ──────────────────────────────────────────────────────────────────────────

  int _compareSleepLogsDescending(SleepLog first, SleepLog second) {
    final int dateCompare = second.date.compareTo(first.date);

    if (dateCompare != 0) {
      return dateCompare;
    }

    final int wakeCompare = second.wakeTime.compareTo(first.wakeTime);

    if (wakeCompare != 0) {
      return wakeCompare;
    }

    return second.createdAt.compareTo(first.createdAt);
  }

  String _dateKey(DateTime value) {
    final DateTime date = SleepLog.dateOnly(value);
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
