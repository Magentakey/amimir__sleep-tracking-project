import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/local/local_daily_log_service.dart';
import '../../data/local/local_sleep_service.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/sleep_log.dart';
import '../../routes/app_router.dart';
import '../daily_log/daily_log_providers.dart';
import '../sleep/sleep_providers.dart';
import '../achievements/achievement_providers.dart';
import 'widgets/add_caffeine_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final LocalSleepService _localSleepService;
  late final LocalDailyLogService _dailyLogService;

  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _conditionNoteController =
      TextEditingController();
  final TextEditingController _mealNoteEditController = TextEditingController();

  late DateTime _selectedDailyDate;

  DailyLog? _selectedDailyLog;
  SleepLog? _selectedSleepLog;

  bool _showOptionalData = false;
  bool _isPickingMeal = false;
  bool _showMidnightWarning = false;

  int? _editingMealIndex;

  static const List<String> _conditionTypes = [
    'normal',
    'sick',
    'stress',
    'tired',
    'other',
  ];

  static const List<String> _sleepHelperOptions = [
    'No screen before sleep',
    'Warm shower',
    'Reading',
    'Meditation',
    'Relaxing music',
    'Dark room',
    'Cool room',
    'Prayer / reflection',
  ];

  @override
  void initState() {
    super.initState();

    _localSleepService = ref.read(sleepLogRepositoryProvider);
    _dailyLogService = ref.read(dailyLogRepositoryProvider);

    _selectedDailyDate = _getInitialSelectedDailyDate();
    _showMidnightWarning = _shouldShowMidnightWarning();

    _loadDashboardData();
  }

  @override
  void dispose() {
    _conditionNoteController.dispose();
    _mealNoteEditController.dispose();
    super.dispose();
  }

  DateTime _getInitialSelectedDailyDate() {
    final DateTime now = DateTime.now();
    final DateTime today = _dateOnly(now);

    if (now.hour >= 0 && now.hour < 4) {
      return today.subtract(const Duration(days: 1));
    }

    return today;
  }

  bool _shouldShowMidnightWarning() {
    final int hour = DateTime.now().hour;
    return hour >= 0 && hour < 4;
  }

  DateTime _todayDateOnly() {
    return _dateOnly(DateTime.now());
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDate(DateTime first, DateTime second) {
    final DateTime firstDate = _dateOnly(first);
    final DateTime secondDate = _dateOnly(second);

    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }

  bool get _canGoNextDay {
    final DateTime today = _todayDateOnly();
    return _selectedDailyDate.isBefore(today);
  }

  void _unfocusKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _loadDashboardData() {
    final DailyLog? dailyLog = _dailyLogService.getDailyLogByDate(
      _selectedDailyDate,
    );

    final SleepLog? sleepLog = _localSleepService.getSleepLogByDate(
      _selectedDailyDate,
    );

    setState(() {
      _selectedDailyLog = dailyLog;
      _selectedSleepLog = sleepLog;
      _conditionNoteController.text = dailyLog?.conditionNote ?? '';
    });
  }

  DailyLog _createEmptySelectedDailyLog() {
    return DailyLog.empty(_selectedDailyDate);
  }

  Future<void> _saveSelectedDailyLog(
    DailyLog Function(DailyLog currentLog) update,
  ) async {
    final DailyLog currentLog =
        _selectedDailyLog ?? _createEmptySelectedDailyLog();

    final DailyLog updatedLog = update(
      currentLog,
    ).copyWith(date: _selectedDailyDate, updatedAt: DateTime.now());

    await _dailyLogService.saveDailyLogForDate(updatedLog);

    ref.invalidate(todayDailyLogProvider);
    // Progress achievement bergantung pada daily log — invalidate supaya
    // achievement baru langsung terdeteksi setelah data harian disimpan.
    ref.invalidate(achievementProgressProvider);

    if (!mounted) {
      return;
    }

    _loadDashboardData();
  }

  void _selectPreviousDay() {
    _unfocusKeyboard();

    setState(() {
      _selectedDailyDate = _selectedDailyDate.subtract(const Duration(days: 1));
      _showMidnightWarning = false;
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });

    _loadDashboardData();
  }

  void _selectNextDay() {
    _unfocusKeyboard();

    if (!_canGoNextDay) {
      _showMessage('Tidak bisa memilih tanggal setelah hari ini.');
      return;
    }

    setState(() {
      _selectedDailyDate = _selectedDailyDate.add(const Duration(days: 1));
      _showMidnightWarning = false;
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });

    _loadDashboardData();
  }

  void _continuePreviousDay() {
    _unfocusKeyboard();

    final DateTime yesterday = _todayDateOnly().subtract(
      const Duration(days: 1),
    );

    setState(() {
      _selectedDailyDate = yesterday;
      _showMidnightWarning = false;
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });

    _loadDashboardData();
  }

  void _startNewDay() {
    _unfocusKeyboard();

    setState(() {
      _selectedDailyDate = _todayDateOnly();
      _showMidnightWarning = false;
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });

    _loadDashboardData();
  }

  Future<void> _selectMood(String mood) async {
    _unfocusKeyboard();

    await _saveSelectedDailyLog((currentLog) {
      return currentLog.copyWith(mood: mood);
    });
  }

  Future<void> _selectConditionType(String conditionType) async {
    _unfocusKeyboard();

    await _saveSelectedDailyLog((currentLog) {
      return currentLog.copyWith(conditionType: conditionType);
    });
  }

  Future<void> _saveConditionNote() async {
    _unfocusKeyboard();

    await _saveSelectedDailyLog((currentLog) {
      return currentLog.copyWith(
        conditionNote: _conditionNoteController.text.trim(),
      );
    });

    if (!mounted) {
      return;
    }

    _showMessage('Condition saved.');
  }

  Future<void> _toggleSleepHelper(String helper) async {
    _unfocusKeyboard();

    await _saveSelectedDailyLog((currentLog) {
      final List<String> updatedHelpers = [...currentLog.sleepHelpers];

      if (updatedHelpers.contains(helper)) {
        updatedHelpers.remove(helper);
      } else {
        updatedHelpers.add(helper);
      }

      return currentLog.copyWith(sleepHelpers: updatedHelpers);
    });
  }

  Future<void> _addOtherSleepHelper() async {
    _unfocusKeyboard();

    String helperText = '';

    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Other sleep helper'),
          content: TextField(
            autofocus: true,
            onChanged: (value) {
              helperText = value;
            },
            decoration: const InputDecoration(
              labelText: 'Helper note',
              hintText: 'Example: minum susu hangat',
              prefixIcon: Icon(Icons.spa_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final String text = helperText.trim();

                if (text.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop('Other: $text');
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) {
      return;
    }

    await _saveSelectedDailyLog((currentLog) {
      return currentLog.copyWith(
        sleepHelpers: [...currentLog.sleepHelpers, result],
      );
    });
  }

  Future<void> _showAddCaffeineDialog() async {
    _unfocusKeyboard();

    final CaffeineLog? result = await showDialog<CaffeineLog>(
      context: context,
      builder: (context) {
        return const AddCaffeineDialog();
      },
    );

    if (result == null || result.name.isEmpty) {
      return;
    }

    await _saveSelectedDailyLog((currentLog) {
      return currentLog.copyWith(
        caffeineLogs: [...currentLog.caffeineLogs, result],
      );
    });
  }

  Future<void> _deleteCaffeineLog(int index) async {
    _unfocusKeyboard();

    await _saveSelectedDailyLog((currentLog) {
      final List<CaffeineLog> updatedLogs = [...currentLog.caffeineLogs];

      if (index < 0 || index >= updatedLogs.length) {
        return currentLog;
      }

      updatedLogs.removeAt(index);

      return currentLog.copyWith(caffeineLogs: updatedLogs);
    });
  }

  Future<void> _addMealLog() async {
    _unfocusKeyboard();

    if (_isPickingMeal) {
      return;
    }

    setState(() {
      _isPickingMeal = true;
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (!mounted) {
        return;
      }

      if (image == null) {
        return;
      }

      final DateTime now = DateTime.now();
      final int newMealIndex = _selectedDailyLog?.mealLogs.length ?? 0;

      final MealLog mealLog = MealLog(
        photoPath: image.path,
        dateTime: now,
        note: '',
      );

      await _saveSelectedDailyLog((currentLog) {
        return currentLog.copyWith(mealLogs: [...currentLog.mealLogs, mealLog]);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _editingMealIndex = newMealIndex;
        _mealNoteEditController.text = '';
      });

      _showMessage('Meal photo saved. Add a meal note if needed.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Gagal mengambil foto meal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingMeal = false;
        });
      }
    }
  }

  void _startEditMealNote({required int index, required MealLog meal}) {
    _unfocusKeyboard();

    setState(() {
      _editingMealIndex = index;
      _mealNoteEditController.text = meal.note;
    });
  }

  void _cancelEditMealNote() {
    _unfocusKeyboard();

    setState(() {
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });
  }

  Future<void> _saveMealNote({
    required int index,
    required MealLog meal,
  }) async {
    _unfocusKeyboard();

    final String newNote = _mealNoteEditController.text.trim();

    await _saveSelectedDailyLog((currentLog) {
      final List<MealLog> updatedMeals = [...currentLog.mealLogs];

      if (index < 0 || index >= updatedMeals.length) {
        return currentLog;
      }

      updatedMeals[index] = meal.copyWith(note: newNote);

      return currentLog.copyWith(mealLogs: updatedMeals);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });

    _showMessage('Meal note saved.');
  }

  Future<void> _deleteMealLog(int index) async {
    _unfocusKeyboard();

    await _saveSelectedDailyLog((currentLog) {
      final List<MealLog> updatedLogs = [...currentLog.mealLogs];

      if (index < 0 || index >= updatedLogs.length) {
        return currentLog;
      }

      updatedLogs.removeAt(index);

      return currentLog.copyWith(mealLogs: updatedLogs);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _editingMealIndex = null;
      _mealNoteEditController.clear();
    });
  }

  Future<void> _selectActivity({
    required String activity,
    required int duration,
  }) async {
    _unfocusKeyboard();

    await _saveSelectedDailyLog((currentLog) {
      return currentLog.copyWith(
        activity: activity,
        activityDuration: duration,
      );
    });
  }

  void _goToHomeForSleep() {
    _unfocusKeyboard();
    context.go(AppRoutePath.home, extra: _selectedDailyDate);
  }

  void _goToAnalysis() {
    _unfocusKeyboard();
    context.go(AppRoutePath.analysis);
  }

  void _toggleOptionalData() {
    _unfocusKeyboard();

    setState(() {
      _showOptionalData = !_showOptionalData;
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _calculateSleepScore(int durationMinutes) {
    const int idealSleepMinutes = 8 * 60;

    final int difference = (durationMinutes - idealSleepMinutes).abs();
    final int penalty = difference ~/ 5;
    final int score = 100 - penalty;

    if (score < 0) {
      return 0;
    }

    if (score > 100) {
      return 100;
    }

    return score;
  }

  String _formatDate(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatShortDate(DateTime value) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final String month = months[value.month - 1];

    return '${value.day} $month ${value.year}';
  }

  String _formatDateTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '${_formatDate(value)} $hour:$minute';
  }

  String _formatTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _unfocusKeyboard,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDashboardHero(),
              const SizedBox(height: 18),
              if (_showMidnightWarning) ...[
                _buildMidnightWarningCard(),
                const SizedBox(height: 18),
              ],
              _buildSleepStatusCard(),
              const SizedBox(height: 16),
              _buildActionRow(),
              if (_showOptionalData) ...[
                const SizedBox(height: 22),
                _buildDailyInputSection(),
              ],
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHero() {
    final bool isToday = _isSameDate(_selectedDailyDate, _todayDateOnly());
    final String mood = _selectedDailyLog?.mood ?? '';
    final bool hasDailyLog = _selectedDailyLog != null;

    return AppCard(
      color: AppColors.surfaceVariant.withOpacity(0.58),
      padding: const EdgeInsets.all(24),
      radius: 38,
      isGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nightly dashboard',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primaryFixedDim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatShortDate(_selectedDailyDate),
            style: AppTextStyles.displayMedium,
          ),
          const SizedBox(height: 10),
          Text(
            isToday
                ? 'Today’s ritual. Fill the day, then sleep gently.'
                : 'Selected day. Review or complete this daily log.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildCircularIconButton(
                tooltip: 'Previous Day',
                icon: Icons.chevron_left_rounded,
                onTap: _selectPreviousDay,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  color: AppColors.surfaceLow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  radius: 24,
                  child: Column(
                    children: [
                      Text(
                        isToday ? 'Today' : 'Selected day',
                        style: AppTextStyles.small,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasDailyLog ? 'Daily data saved' : 'No daily data yet',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (mood.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Mood: $mood',
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.primaryFixedDim,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildCircularIconButton(
                tooltip: 'Next Day',
                icon: Icons.chevron_right_rounded,
                onTap: _canGoNextDay ? _selectNextDay : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null
                ? AppColors.surfaceLow.withOpacity(0.45)
                : AppColors.surfaceContainerHighest,
          ),
          child: Icon(
            icon,
            color: onTap == null
                ? AppColors.onSurfaceMuted
                : AppColors.primaryFixedDim,
          ),
        ),
      ),
    );
  }

  Widget _buildMidnightWarningCard() {
    final DateTime today = _todayDateOnly();
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    return AppCard(
      color: AppColors.tertiaryContainer.withOpacity(0.48),
      padding: const EdgeInsets.all(22),
      radius: 32,
      isGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dark_mode_rounded, color: AppColors.tertiary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sudah lewat tengah malam',
                  style: AppTextStyles.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Apakah kamu masih melanjutkan daily log ${_formatShortDate(yesterday)} sebelum tidur, atau ingin mulai daily log ${_formatShortDate(today)}?',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _continuePreviousDay,
                  child: const Text('Continue Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startNewDay,
                  child: const Text('Start New Day'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepStatusCard() {
    final SleepLog? sleepLog = _selectedSleepLog;

    if (sleepLog == null) {
      return AppCard(
        color: AppColors.surfaceContainerHigh,
        padding: const EdgeInsets.all(24),
        radius: 38,
        child: Column(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.calmGradient,
              ),
              child: const Icon(
                Icons.bedtime_outlined,
                size: 40,
                color: AppColors.primaryFixedDim,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No sleep log',
              style: AppTextStyles.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada sleep log untuk ${_formatShortDate(_selectedDailyDate)}.',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _goToHomeForSleep,
              icon: const Icon(Icons.nightlight_round),
              label: const Text('Time to Sleep'),
            ),
          ],
        ),
      );
    }

    final int sleepScore = _calculateSleepScore(sleepLog.durationMinutes);

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(24),
      radius: 38,
      child: Column(
        children: [
          _buildScoreArc(sleepScore),
          const SizedBox(height: 18),
          Text(
            sleepLog.formattedDuration,
            style: AppTextStyles.metric,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Sleep recorded for ${_formatShortDate(_selectedDailyDate)}',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildSleepTimeRow(
            icon: Icons.bedtime_rounded,
            label: 'Sleep',
            value: _formatDateTime(sleepLog.sleepTime),
          ),
          const SizedBox(height: 10),
          _buildSleepTimeRow(
            icon: Icons.wb_twilight_rounded,
            label: 'Wake',
            value: _formatDateTime(sleepLog.wakeTime),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _goToHomeForSleep,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Sleep Log'),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreArc(int sleepScore) {
    final double progress = (sleepScore.clamp(0, 100)) / 100;

    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 122,
            height: 122,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 12,
              color: AppColors.surfaceVariant,
            ),
          ),
          SizedBox(
            width: 122,
            height: 122,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              color: AppColors.tertiary,
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceLow,
            ),
            child: Center(
              child: Text(
                '$sleepScore\nQUALITY',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.tertiary,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTimeRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 24,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryFixedDim, size: 20),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.subtitle),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleOptionalData,
            icon: Icon(
              _showOptionalData
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.add_rounded,
            ),
            label: Text(_showOptionalData ? 'Hide Add Data' : 'Add Data'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _goToAnalysis,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Analysis'),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily ritual', style: AppTextStyles.headline),
        const SizedBox(height: 6),
        Text(
          'Optional data for ${_formatShortDate(_selectedDailyDate)}.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 16),
        _buildMoodCard(),
        const SizedBox(height: 14),
        _buildConditionCard(),
        const SizedBox(height: 14),
        _buildSleepHelpersCard(),
        const SizedBox(height: 14),
        _buildCaffeineCard(),
        const SizedBox(height: 14),
        _buildMealCard(),
        const SizedBox(height: 14),
        _buildActivityCard(),
      ],
    );
  }

  Widget _buildMoodCard() {
    final String selectedMood = _selectedDailyLog?.mood ?? '';

    return _buildInputCard(
      title: 'Mood',
      subtitle: 'Bagaimana suasana kamu hari ini?',
      icon: Icons.mood_rounded,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildPillButton(
            label: 'Sleepy',
            selected: selectedMood == 'sleepy',
            icon: Icons.hotel_rounded,
            onTap: () => _selectMood('sleepy'),
          ),
          _buildPillButton(
            label: 'Neutral',
            selected: selectedMood == 'neutral',
            icon: Icons.sentiment_neutral_rounded,
            onTap: () => _selectMood('neutral'),
          ),
          _buildPillButton(
            label: 'Happy',
            selected: selectedMood == 'happy',
            icon: Icons.sentiment_satisfied_alt_rounded,
            onTap: () => _selectMood('happy'),
          ),
          _buildPillButton(
            label: 'Love',
            selected: selectedMood == 'love',
            icon: Icons.favorite_rounded,
            onTap: () => _selectMood('love'),
          ),
          _buildPillButton(
            label: 'Active',
            selected: selectedMood == 'fire',
            icon: Icons.local_fire_department_rounded,
            onTap: () => _selectMood('fire'),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCard() {
    final String selectedType = _selectedDailyLog?.conditionType ?? 'normal';

    return _buildInputCard(
      title: 'Condition',
      subtitle: 'Catat kondisi tubuh atau pikiran.',
      icon: Icons.health_and_safety_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _conditionTypes.map((type) {
              final bool isSelected = selectedType == type;

              return _buildPillButton(
                label: type,
                selected: isSelected,
                icon: _conditionIcon(type),
                onTap: () => _selectConditionType(type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _conditionNoteController,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _unfocusKeyboard(),
            decoration: const InputDecoration(
              labelText: 'Condition note',
              hintText: 'sakit, stress ujian, banyak pikiran...',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saveConditionNote,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save condition note'),
          ),
        ],
      ),
    );
  }

  IconData _conditionIcon(String type) {
    switch (type) {
      case 'sick':
        return Icons.sick_rounded;
      case 'stress':
        return Icons.psychology_alt_rounded;
      case 'tired':
        return Icons.battery_1_bar_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      case 'normal':
      default:
        return Icons.check_circle_rounded;
    }
  }

  Widget _buildSleepHelpersCard() {
    final List<String> selectedHelpers = _selectedDailyLog?.sleepHelpers ?? [];

    return _buildInputCard(
      title: 'Sleep Helpers',
      subtitle: 'Kebiasaan kecil yang membantu tidur.',
      icon: Icons.spa_rounded,
      trailing: TextButton.icon(
        onPressed: _addOtherSleepHelper,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Other'),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ..._sleepHelperOptions.map((helper) {
            final bool isSelected = selectedHelpers.contains(helper);

            return _buildPillButton(
              label: helper,
              selected: isSelected,
              onTap: () => _toggleSleepHelper(helper),
            );
          }),
          ...selectedHelpers.where((helper) => helper.startsWith('Other:')).map(
            (helper) {
              return _buildPillButton(
                label: helper,
                selected: true,
                icon: Icons.star_rounded,
                onTap: () => _toggleSleepHelper(helper),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCaffeineCard() {
    final List<CaffeineLog> caffeineList =
        _selectedDailyLog?.caffeineLogs ?? [];

    return _buildInputCard(
      title: 'Caffeine',
      subtitle: 'Catat kopi, teh, atau minuman berkafein.',
      icon: Icons.local_cafe_rounded,
      trailing: TextButton.icon(
        onPressed: _showAddCaffeineDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      child: caffeineList.isEmpty
          ? _buildEmptySection(
              icon: Icons.coffee_outlined,
              text: 'No caffeine added.',
            )
          : Column(
              children: caffeineList.asMap().entries.map((entry) {
                final int index = entry.key;
                final CaffeineLog item = entry.value;

                return _buildListTileCard(
                  icon: Icons.local_cafe_rounded,
                  title: item.name,
                  subtitle: _formatDateTime(item.dateTime),
                  trailing: IconButton(
                    tooltip: 'Delete caffeine',
                    onPressed: () => _deleteCaffeineLog(index),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.onSurfaceVariant,
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMealCard() {
    final List<MealLog> mealList = _selectedDailyLog?.mealLogs ?? [];

    return _buildInputCard(
      title: 'Meals',
      subtitle: 'Foto makanan dan tambahkan catatan singkat.',
      icon: Icons.restaurant_rounded,
      trailing: TextButton.icon(
        onPressed: _isPickingMeal ? null : _addMealLog,
        icon: const Icon(Icons.photo_camera_rounded),
        label: Text(_isPickingMeal ? 'Opening...' : 'Camera'),
      ),
      child: mealList.isEmpty
          ? _buildEmptySection(
              icon: Icons.no_food_rounded,
              text: 'No meal photo captured.',
            )
          : Column(
              children: mealList.asMap().entries.map((entry) {
                final int index = entry.key;
                final MealLog meal = entry.value;
                final bool isEditing = _editingMealIndex == index;

                return AppCard(
                  color: AppColors.surfaceLow,
                  padding: const EdgeInsets.all(12),
                  radius: 28,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          _startEditMealNote(index: index, meal: meal);
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: _buildMealThumbnail(meal.photoPath),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meal.note.isEmpty
                                        ? 'Tap to add meal note'
                                        : meal.note,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(meal.dateTime),
                                    style: AppTextStyles.small,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit note',
                              onPressed: () {
                                _startEditMealNote(index: index, meal: meal);
                              },
                              icon: const Icon(Icons.edit_note_rounded),
                              color: AppColors.primaryFixedDim,
                            ),
                            IconButton(
                              tooltip: 'Delete meal',
                              onPressed: () => _deleteMealLog(index),
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _mealNoteEditController,
                          minLines: 1,
                          maxLines: 3,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            _saveMealNote(index: index, meal: meal);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Meal note',
                            hintText: 'Contoh: nasi goreng, mie ayam, roti...',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancelEditMealNote,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _saveMealNote(index: index, meal: meal);
                                },
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMealThumbnail(String path) {
    if (path.isEmpty) {
      return Container(
        width: 74,
        height: 74,
        color: AppColors.surfaceContainerHighest,
        child: const Icon(
          Icons.image_not_supported_rounded,
          color: AppColors.onSurfaceVariant,
        ),
      );
    }

    return Image.file(
      File(path),
      width: 74,
      height: 74,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 74,
          height: 74,
          color: AppColors.surfaceContainerHighest,
          child: const Icon(
            Icons.broken_image_rounded,
            color: AppColors.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Widget _buildActivityCard() {
    final String selectedActivity = _selectedDailyLog?.activity ?? '';

    return _buildInputCard(
      title: 'Activity',
      subtitle: 'Ringkas aktivitas harianmu.',
      icon: Icons.directions_run_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActivityButton(
                  label: '15m\nLight',
                  activity: 'Light',
                  duration: 15,
                  selectedActivity: selectedActivity,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActivityButton(
                  label: '30m\nModerate',
                  activity: 'Moderate',
                  duration: 30,
                  selectedActivity: selectedActivity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActivityButton(
                  label: '45m\nActive',
                  activity: 'Active',
                  duration: 45,
                  selectedActivity: selectedActivity,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActivityButton(
                  label: '60m+\nIntense',
                  activity: 'Intense',
                  duration: 60,
                  selectedActivity: selectedActivity,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityButton({
    required String label,
    required String activity,
    required int duration,
    required String selectedActivity,
  }) {
    final bool isSelected = selectedActivity == activity;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        _selectActivity(activity: activity, duration: duration);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                ),
                child: Icon(icon, color: AppColors.primaryFixedDim, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.small),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.primaryFixedDim,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySection({required IconData icon, required String text}) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(18),
      radius: 26,
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.subtitle)),
        ],
      ),
    );
  }

  Widget _buildListTileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 26,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primaryFixedDim),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTextStyles.small),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
