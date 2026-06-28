import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_daily_log_service.dart';
import '../../data/models/daily_log.dart';

final dailyLogRepositoryProvider = Provider<LocalDailyLogService>((ref) {
  return LocalDailyLogService();
});

final todayDailyLogProvider = Provider<DailyLog?>((ref) {
  final LocalDailyLogService dailyLogService = ref.watch(
    dailyLogRepositoryProvider,
  );

  return dailyLogService.getDailyLogByDate(DateTime.now());
});
