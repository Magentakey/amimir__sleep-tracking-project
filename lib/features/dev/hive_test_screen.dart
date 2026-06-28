import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/local/local_achievement_service.dart';
import '../../data/local/local_daily_log_service.dart';
import '../../data/local/local_sleep_service.dart';
import '../../data/models/achievement.dart';
import '../../data/models/analysis_cache.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/sleep_log.dart';
import '../../data/repositories/analysis_repository.dart';

class HiveTestScreen extends StatefulWidget {
  const HiveTestScreen({super.key});

  @override
  State<HiveTestScreen> createState() => _HiveTestScreenState();
}

class _HiveTestScreenState extends State<HiveTestScreen> {
  final LocalSleepService _sleepService = LocalSleepService();
  final LocalDailyLogService _dailyLogService = LocalDailyLogService();
  final AnalysisRepository _analysisRepository = AnalysisRepository();
  final LocalAchievementService _achievementService = LocalAchievementService();

  List<SleepLog> _sleepLogs = [];
  List<DailyLog> _dailyLogs = [];
  List<AnalysisCache> _analysisCaches = [];
  List<AchievementProgress> _achievements = [];

  String? _equippedAchievementId;

  @override
  void initState() {
    super.initState();
    _loadHiveData();
  }

  Future<void> _loadHiveData() async {
    final List<SleepLog> sleepLogs = _sleepService.getAllSleepLogs();
    final List<DailyLog> dailyLogs = _dailyLogService.getAllDailyLogs();
    final List<AnalysisCache> analysisCaches = _analysisRepository
        .getAllAnalysisCaches();

    final result = await _achievementService.refreshAchievements(
      sleepLogs: sleepLogs,
      dailyLogs: dailyLogs,
      analysisCaches: analysisCaches,
    );
    final List<AchievementProgress> achievements = result.all;

    setState(() {
      _sleepLogs = sleepLogs;
      _dailyLogs = dailyLogs;
      _analysisCaches = analysisCaches;
      _achievements = achievements;
      _equippedAchievementId = _achievementService.getEquippedAchievementId();
    });
  }

  Future<void> _addDummySleepLog() async {
    final DateTime now = DateTime.now();
    final DateTime sleepTime = now.subtract(
      const Duration(hours: 7, minutes: 30),
    );

    final SleepLog sleepLog = SleepLog(
      id: now.millisecondsSinceEpoch.toString(),
      date: DateTime(now.year, now.month, now.day),
      sleepTime: sleepTime,
      wakeTime: now,
      durationMinutes: now.difference(sleepTime).inMinutes,
      sleepScore: 80,
      createdAt: now,
      updatedAt: now,
    );

    await _sleepService.addSleepLog(sleepLog);
    await _loadHiveData();
  }

  Future<void> _addDummyDailyLog() async {
    final DateTime now = DateTime.now();

    final DailyLog dailyLog = DailyLog(
      id: now.millisecondsSinceEpoch.toString(),
      date: DateTime(now.year, now.month, now.day),
      mood: 'happy',
      conditionType: 'stress',
      conditionNote: 'Stress ujian nasional',
      sleepHelpers: const [
        'No screen before sleep',
        'Dark room',
        'Relaxing music',
      ],
      caffeineLogs: [
        CaffeineLog(
          name: 'Espresso',
          dateTime: now.subtract(const Duration(hours: 10)),
        ),
        CaffeineLog(
          name: 'Es teh',
          dateTime: now.subtract(const Duration(hours: 3)),
        ),
      ],
      mealLogs: [
        MealLog(
          photoPath: '',
          dateTime: now.subtract(const Duration(hours: 5)),
          note: 'Dummy meal note',
        ),
      ],
      activity: 'Moderate',
      activityDuration: 30,
      createdAt: now,
      updatedAt: now,
    );

    await _dailyLogService.addDailyLog(dailyLog);
    await _loadHiveData();
  }

  Future<void> _addDummyAnalysisCache() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final AnalysisCache analysisCache = AnalysisCache(
      id: now.millisecondsSinceEpoch.toString(),
      periodType: 'daily',
      periodStart: today,
      periodEnd: today,
      summary: 'Dummy summary: Sleep data berhasil dianalisis.',
      insight:
          'Dummy insight: Your sleep duration is slightly lower than ideal.',
      recommendation:
          'Dummy recommendation: Try sleeping earlier and reduce caffeine at night.',
      createdAt: now,
    );

    await _analysisRepository.saveAnalysisCache(analysisCache);
    await _loadHiveData();
  }

  Future<void> _updateLatestSleepLog() async {
    if (_sleepLogs.isEmpty) {
      _showMessage('Sleep log masih kosong.');
      return;
    }

    final SleepLog latestLog = _sleepLogs.first;

    final SleepLog updatedLog = latestLog.copyWith(
      sleepScore: latestLog.sleepScore + 1,
      updatedAt: DateTime.now(),
    );

    await _sleepService.updateSleepLog(updatedLog);
    await _loadHiveData();
  }

  Future<void> _updateLatestDailyLog() async {
    if (_dailyLogs.isEmpty) {
      _showMessage('Daily log masih kosong.');
      return;
    }

    final DailyLog latestLog = _dailyLogs.first;

    final DailyLog updatedLog = latestLog.copyWith(
      caffeineLogs: [
        ...latestLog.caffeineLogs,
        CaffeineLog(name: 'Updated caffeine', dateTime: DateTime.now()),
      ],
      mood: 'updated mood',
      conditionNote: 'Updated condition note',
      updatedAt: DateTime.now(),
    );

    await _dailyLogService.updateDailyLog(updatedLog);
    await _loadHiveData();
  }

  Future<void> _deleteLatestSleepLog() async {
    if (_sleepLogs.isEmpty) {
      _showMessage('Sleep log masih kosong.');
      return;
    }

    await _sleepService.deleteSleepLog(_sleepLogs.first.id);
    await _loadHiveData();
  }

  Future<void> _deleteLatestDailyLog() async {
    if (_dailyLogs.isEmpty) {
      _showMessage('Daily log masih kosong.');
      return;
    }

    await _dailyLogService.deleteDailyLog(_dailyLogs.first.id);
    await _loadHiveData();
  }

  Future<void> _deleteLatestAnalysisCache() async {
    if (_analysisCaches.isEmpty) {
      _showMessage('Analysis cache masih kosong.');
      return;
    }

    await _analysisRepository.deleteAnalysisCache(_analysisCaches.first.id);
    await _loadHiveData();
  }

  Future<void> _clearAllAnalysisCaches() async {
    if (_analysisCaches.isEmpty) {
      _showMessage('Analysis cache masih kosong.');
      return;
    }

    await _analysisRepository.clearAllAnalysisCaches();
    await _loadHiveData();
  }

  Future<void> _refreshAchievements() async {
    await _loadHiveData();
    _showMessage('Achievement refreshed.');
  }

  Future<void> _equipFirstUnlockedAchievement() async {
    final List<AchievementProgress> unlockedAchievements = _achievements
        .where((achievement) => achievement.isUnlocked)
        .toList();

    if (unlockedAchievements.isEmpty) {
      _showMessage('Belum ada achievement unlocked.');
      return;
    }

    await _achievementService.equipAchievement(unlockedAchievements.first.id);
    await _loadHiveData();
    _showMessage('${unlockedAchievements.first.definition.title} equipped.');
  }

  Future<void> _unequipAchievement() async {
    await _achievementService.unequipAchievement();
    await _loadHiveData();
    _showMessage('Achievement unequipped.');
  }

  Future<void> _clearAchievementData() async {
    await _achievementService.clearAchievementData();
    await _loadHiveData();
    _showMessage('Achievement data cleared.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      showBottomNavigation: false,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 24),
            _buildAchievementsSection(),
            const SizedBox(height: 24),
            _buildSleepLogsSection(),
            const SizedBox(height: 24),
            _buildDailyLogsSection(),
            const SizedBox(height: 24),
            _buildAnalysisCachesSection(),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppCard(
      color: AppColors.surfaceVariant.withOpacity(0.58),
      padding: const EdgeInsets.all(24),
      radius: 38,
      isGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hive Test Page', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Halaman ini dipakai untuk melihat dan mengetes data Hive lokal.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 14),
          AppCard(
            color: AppColors.surfaceLow,
            padding: const EdgeInsets.all(14),
            radius: 26,
            child: Text(
              'Equipped Achievement ID: ${_equippedAchievementId ?? '-'}',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(18),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _loadHiveData,
            child: const Text('Refresh Data'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _addDummySleepLog,
            child: const Text('Add Dummy Sleep Log'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _addDummyDailyLog,
            child: const Text('Add Dummy Daily Log'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _addDummyAnalysisCache,
            child: const Text('Add Dummy Analysis Cache'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshAchievements,
            child: const Text('Refresh Achievements'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _equipFirstUnlockedAchievement,
            child: const Text('Equip First Unlocked Achievement'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _unequipAchievement,
            child: const Text('Unequip Achievement'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _updateLatestSleepLog,
            child: const Text('Update Latest Sleep Log'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _updateLatestDailyLog,
            child: const Text('Update Latest Daily Log'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _deleteLatestSleepLog,
            child: const Text('Delete Latest Sleep Log'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _deleteLatestDailyLog,
            child: const Text('Delete Latest Daily Log'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _deleteLatestAnalysisCache,
            child: const Text('Delete Latest Analysis Cache'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _clearAllAnalysisCaches,
            child: const Text('Clear All Analysis Cache'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _clearAchievementData,
            child: const Text('Clear Achievement Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final int unlockedCount = _achievements.where((achievement) {
      return achievement.isUnlocked;
    }).length;

    return _buildSectionCard(
      title: 'Achievements: $unlockedCount/${_achievements.length}',
      child: _achievements.isEmpty
          ? const Text('Belum ada data achievement.')
          : Column(children: _achievements.map(_buildAchievementCard).toList()),
    );
  }

  Widget _buildAchievementCard(AchievementProgress achievement) {
    return AppCard(
      color: achievement.isUnlocked
          ? AppColors.surfaceLow
          : AppColors.surfaceContainer,
      padding: const EdgeInsets.all(14),
      radius: 24,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(achievement.definition.title, style: AppTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text(
            achievement.definition.description,
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 8),
          Text('ID: ${achievement.id}', style: AppTextStyles.small),
          Text(
            'Category: ${achievement.definition.category.name}',
            style: AppTextStyles.small,
          ),
          Text(
            'Rarity: ${achievement.definition.rarity.name}',
            style: AppTextStyles.small,
          ),
          Text(
            'Progress: ${achievement.progressText}',
            style: AppTextStyles.small,
          ),
          Text(
            'Unlocked: ${achievement.isUnlocked}',
            style: AppTextStyles.small,
          ),
          Text(
            'Equipped: ${achievement.isEquipped}',
            style: AppTextStyles.small,
          ),
          if (achievement.unlockedAt != null)
            Text(
              'Unlocked At: ${_formatDateTime(achievement.unlockedAt!)}',
              style: AppTextStyles.small,
            ),
        ],
      ),
    );
  }

  Widget _buildSleepLogsSection() {
    return _buildSectionCard(
      title: 'Sleep Logs: ${_sleepLogs.length}',
      child: _sleepLogs.isEmpty
          ? const Text('Belum ada data sleep log.')
          : Column(children: _sleepLogs.map(_buildSleepLogCard).toList()),
    );
  }

  Widget _buildDailyLogsSection() {
    return _buildSectionCard(
      title: 'Daily Logs: ${_dailyLogs.length}',
      child: _dailyLogs.isEmpty
          ? const Text('Belum ada data daily log.')
          : Column(children: _dailyLogs.map(_buildDailyLogCard).toList()),
    );
  }

  Widget _buildAnalysisCachesSection() {
    return _buildSectionCard(
      title: 'Analysis Caches: ${_analysisCaches.length}',
      child: _analysisCaches.isEmpty
          ? const Text('Belum ada data analysis cache.')
          : Column(
              children: _analysisCaches.map(_buildAnalysisCacheCard).toList(),
            ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(18),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAnalysisCacheCard(AnalysisCache cache) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(14),
      radius: 24,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${cache.id}'),
          Text('Period Type: ${cache.periodType}'),
          Text('Period Start: ${_formatDateTime(cache.periodStart)}'),
          Text('Period End: ${_formatDateTime(cache.periodEnd)}'),
          const SizedBox(height: 6),
          const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(cache.summary),
          const SizedBox(height: 6),
          const Text('Insight:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(cache.insight),
          const SizedBox(height: 6),
          const Text(
            'Recommendation:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(cache.recommendation),
          const SizedBox(height: 6),
          Text('Created At: ${_formatDateTime(cache.createdAt)}'),
        ],
      ),
    );
  }

  Widget _buildSleepLogCard(SleepLog log) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(14),
      radius: 24,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${log.id}'),
          Text('Date: ${_formatDateTime(log.date)}'),
          Text('Sleep Time: ${_formatDateTime(log.sleepTime)}'),
          Text('Wake Time: ${_formatDateTime(log.wakeTime)}'),
          Text('Duration: ${log.formattedDuration}'),
          Text('Score: ${log.sleepScore}'),
          Text('Created At: ${_formatDateTime(log.createdAt)}'),
          Text('Updated At: ${_formatDateTime(log.updatedAt)}'),
        ],
      ),
    );
  }

  Widget _buildDailyLogCard(DailyLog log) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(14),
      radius: 24,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${log.id}'),
          Text('Date: ${_formatDateTime(log.date)}'),
          Text('Mood: ${log.mood}'),
          Text('Condition Type: ${log.conditionType}'),
          Text('Condition Note: ${log.conditionNote}'),
          Text('Sleep Helpers: ${log.sleepHelpers}'),
          const SizedBox(height: 8),
          const Text(
            'Caffeine Logs:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (log.caffeineLogs.isEmpty)
            const Text('- Empty')
          else
            ...log.caffeineLogs.map((item) {
              return Text(
                '- ${item.name} at ${_formatDateTime(item.dateTime)}',
              );
            }),
          const SizedBox(height: 8),
          const Text(
            'Meal Logs:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (log.mealLogs.isEmpty)
            const Text('- Empty')
          else
            ...log.mealLogs.map((item) {
              return Text(
                '- note: ${item.note}, path: ${item.photoPath}, time: ${_formatDateTime(item.dateTime)}',
              );
            }),
          const SizedBox(height: 8),
          Text('Activity: ${log.activity}'),
          Text('Activity Duration: ${log.activityDuration} minutes'),
          Text('Created At: ${_formatDateTime(log.createdAt)}'),
          Text('Updated At: ${_formatDateTime(log.updatedAt)}'),
        ],
      ),
    );
  }
}
