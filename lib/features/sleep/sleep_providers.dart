import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_sleep_service.dart';
import '../../data/models/sleep_log.dart';

final sleepLogRepositoryProvider = Provider<LocalSleepService>((ref) {
  return LocalSleepService();
});

final latestSleepLogProvider = Provider<SleepLog?>((ref) {
  final LocalSleepService sleepService = ref.watch(sleepLogRepositoryProvider);
  return sleepService.getLatestSleepLog();
});

final allSleepLogsProvider = Provider<List<SleepLog>>((ref) {
  final LocalSleepService sleepService = ref.watch(sleepLogRepositoryProvider);
  return sleepService.getAllSleepLogs();
});
