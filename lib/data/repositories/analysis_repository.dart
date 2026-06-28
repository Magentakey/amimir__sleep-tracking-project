import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/user_session_service.dart';
import '../models/analysis_cache.dart';

class AnalysisRepository {
  /// Nama box ini sekarang per-akun (UID), bukan global lagi.
  /// Lihat [UserSessionService] untuk alasannya.
  static String get analysisCacheBoxName {
    final String? uid = UserSessionService.currentUid;

    if (uid == null) {
      throw StateError(
        'Tidak ada user yang login — box analysis cache belum bisa diakses.',
      );
    }

    return UserSessionService.boxNameFor(
      UserSessionService.analysisCachePrefix,
      uid,
    );
  }

  Box get _box => Hive.box(analysisCacheBoxName);

  Future<void> saveAnalysisCache(AnalysisCache cache) async {
    await _box.put(cache.id, cache.toMap());
  }

  List<AnalysisCache> getAllAnalysisCaches() {
    final List<AnalysisCache> caches = [];

    for (final dynamic item in _box.values) {
      try {
        final AnalysisCache cache = AnalysisCache.fromMap(
          item as Map<dynamic, dynamic>,
        );

        caches.add(cache);
      } catch (_) {
        continue;
      }
    }

    caches.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return caches;
  }

  AnalysisCache? getLatestAnalysisCache() {
    final List<AnalysisCache> caches = getAllAnalysisCaches();

    if (caches.isEmpty) {
      return null;
    }

    return caches.first;
  }

  AnalysisCache? getLatestAnalysisCacheByPeriodType(String periodType) {
    final List<AnalysisCache> caches = getAllAnalysisCaches();

    for (final AnalysisCache cache in caches) {
      if (cache.periodType == periodType) {
        return cache;
      }
    }

    return null;
  }

  AnalysisCache? getLatestAnalysisCacheByPeriodAndRange({
    required String periodType,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final DateTime targetStart = _dateOnly(periodStart);
    final DateTime targetEnd = _dateOnly(periodEnd);

    final List<AnalysisCache> caches = getAllAnalysisCaches();

    for (final AnalysisCache cache in caches) {
      final DateTime cacheStart = _dateOnly(cache.periodStart);
      final DateTime cacheEnd = _dateOnly(cache.periodEnd);

      final bool isSamePeriodType = cache.periodType == periodType;
      final bool isSameStartDate = _isSameDate(cacheStart, targetStart);
      final bool isSameEndDate = _isSameDate(cacheEnd, targetEnd);

      if (isSamePeriodType && isSameStartDate && isSameEndDate) {
        return cache;
      }
    }

    return null;
  }

  Future<void> deleteAnalysisCache(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAllAnalysisCaches() async {
    await _box.clear();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDate(DateTime firstDate, DateTime secondDate) {
    final DateTime first = _dateOnly(firstDate);
    final DateTime second = _dateOnly(secondDate);

    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
