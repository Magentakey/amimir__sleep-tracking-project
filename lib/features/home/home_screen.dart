import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/models/sleep_log.dart';
import '../../routes/app_router.dart';
import '../sleep/sleep_providers.dart';
import '../achievements/achievement_providers.dart';

enum SleepPreviewAction { save, edit, cancel }

class HomeScreen extends ConsumerStatefulWidget {
  final DateTime? targetDailyDate;

  const HomeScreen({super.key, this.targetDailyDate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _timer;

  late DateTime _targetDailyDate;

  SleepLog? _existingSleepLog;

  DateTime? _sleepStartTime;
  Duration _sleepDuration = Duration.zero;
  bool _isSleeping = false;

  /// True hanya jika target date = hari ini (atau kemarin jika jam 00–04).
  /// Auto sleep tracker HANYA tersedia untuk tanggal ini.
  bool get _isAutoSleepEnabled {
    final DateTime resolvedToday = _resolveTargetDailyDate(null);
    return SleepLog.isSameDate(_targetDailyDate, resolvedToday);
  }

  @override
  void initState() {
    super.initState();
    _targetDailyDate = _resolveTargetDailyDate(widget.targetDailyDate);
    _loadSleepLogForTargetDate();
    _restoreActiveSleepSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _resolveTargetDailyDate(DateTime? incomingDate) {
    if (incomingDate != null) {
      return _dateOnly(incomingDate);
    }

    final DateTime now = DateTime.now();
    final DateTime today = _dateOnly(now);

    if (now.hour >= 0 && now.hour < 4) {
      return today.subtract(const Duration(days: 1));
    }

    return today;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void _loadSleepLogForTargetDate() {
    final sleepService = ref.read(sleepLogRepositoryProvider);

    setState(() {
      _existingSleepLog = sleepService.getSleepLogByDate(_targetDailyDate);
    });
  }

  /// Cek Hive untuk active session yang tersimpan sebelumnya.
  /// Sleep timer tetap akurat meski app ditutup/HP mati karena startTime
  /// disimpan ke Hive, bukan hanya di memori.
  void _restoreActiveSleepSession() {
    if (!_isAutoSleepEnabled) return;

    final sleepService = ref.read(sleepLogRepositoryProvider);
    final session = sleepService.getActiveSleepSession();

    if (session == null) return;

    // Stale check: session lebih dari 24 jam → hapus otomatis
    if (DateTime.now().difference(session.startTime).inHours > 24) {
      sleepService.clearActiveSleepSession();
      return;
    }

    // Pastikan session untuk tanggal yang sama dengan view saat ini
    if (!SleepLog.isSameDate(session.targetDate, _targetDailyDate)) return;

    setState(() {
      _sleepStartTime = session.startTime;
      _sleepDuration = DateTime.now().difference(session.startTime);
      _isSleeping = true;
    });

    _startTimer();

    // Tampilkan ulang notifikasi OS — bisa saja sudah hilang kalau HP
    // di-restart atau notifikasi di-swipe dari luar app.
    unawaited(
      NotificationService().showSleepActiveNotification(
        startTime: session.startTime,
      ),
    );
  }

  /// Hanya menjalankan UI timer. Tidak menyentuh Hive.
  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (_sleepStartTime == null || !mounted) return;

      setState(() {
        _sleepDuration = DateTime.now().difference(_sleepStartTime!);
      });
    });
  }

  Future<void> _startSleep() async {
    if (_existingSleepLog != null) {
      _showMessage(
        'Sleep log untuk tanggal ini sudah ada. Gunakan Edit Sleep Log.',
      );
      return;
    }

    final DateTime now = DateTime.now();

    setState(() {
      _sleepStartTime = now;
      _sleepDuration = Duration.zero;
      _isSleeping = true;
    });

    // Persist ke Hive → timer akurat meski app ditutup, ganti halaman, atau HP sleep
    final sleepService = ref.read(sleepLogRepositoryProvider);
    await sleepService.saveActiveSleepSession(
      startTime: now,
      targetDate: _targetDailyDate,
    );

    _startTimer();

    // Tampilkan notifikasi OS "Tidur sedang aktif" di status bar.
    // Fire-and-forget — tidak perlu await karena tidak memblokir UI.
    unawaited(
      NotificationService().showSleepActiveNotification(startTime: now),
    );
  }

  Future<void> _stopSleep() async {
    final DateTime? startTime = _sleepStartTime;

    if (startTime == null) return;

    final DateTime wakeTime = DateTime.now();

    final bool saved = await _showPreviewBeforeSave(
      sleepTime: startTime,
      wakeTime: wakeTime,
    );

    if (!saved) return;

    _timer?.cancel();

    // Hapus session dari Hive hanya setelah berhasil disimpan sebagai SleepLog
    final sleepService = ref.read(sleepLogRepositoryProvider);
    await sleepService.clearActiveSleepSession();

    // Batalkan notifikasi OS karena timer sudah dihentikan.
    unawaited(NotificationService().cancelSleepNotification());

    setState(() {
      _sleepStartTime = null;
      _sleepDuration = Duration.zero;
      _isSleeping = false;
    });

    _loadSleepLogForTargetDate();
  }

  Future<void> _handleSleepButton() async {
    if (_existingSleepLog != null) {
      _showMessage('Sleep log sudah ada. Gunakan Edit Sleep Log.');
      return;
    }

    if (_isSleeping) {
      await _stopSleep();
    } else {
      await _startSleep();
    }
  }

  Future<void> _showManualSleepInput() async {
    await _showSleepInputFlow(existingLog: _existingSleepLog);
  }

  Future<void> _showSleepInputFlow({required SleepLog? existingLog}) async {
    final DateTime now = DateTime.now();

    final DateTime initialSleepTime =
        existingLog?.sleepTime ?? now.subtract(const Duration(hours: 8));

    final DateTime initialWakeTime = existingLog?.wakeTime ?? now;

    final DateTime? selectedSleepTime = await _pickDateTime(
      title: 'Select sleep time',
      initialDateTime: initialSleepTime,
    );

    if (selectedSleepTime == null) return;

    if (!_isDateTimeNotFuture(selectedSleepTime)) {
      _showMessage('Sleep time tidak boleh melewati waktu sekarang.');
      return;
    }

    final DateTime? selectedWakeTime = await _pickDateTime(
      title: 'Select wake time',
      initialDateTime: initialWakeTime,
    );

    if (selectedWakeTime == null) return;

    if (!_isDateTimeNotFuture(selectedWakeTime)) {
      _showMessage('Wake time tidak boleh melewati waktu sekarang.');
      return;
    }

    if (!_isValidSleepRange(
      sleepTime: selectedSleepTime,
      wakeTime: selectedWakeTime,
    )) {
      _showMessage(
        'Wake time harus setelah sleep time dan durasi tidur harus valid.',
      );
      return;
    }

    final bool saved = await _showPreviewBeforeSave(
      sleepTime: selectedSleepTime,
      wakeTime: selectedWakeTime,
    );

    if (!saved) return;

    _loadSleepLogForTargetDate();
  }

  Future<DateTime?> _pickDateTime({
    required String title,
    required DateTime initialDateTime,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime safeInitialDate = initialDateTime.isAfter(now)
        ? now
        : initialDateTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      helpText: title,
      initialDate: DateTime(
        safeInitialDate.year,
        safeInitialDate.month,
        safeInitialDate.day,
      ),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (pickedDate == null) return null;
    if (!mounted) return null;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      helpText: title,
      initialTime: TimeOfDay(
        hour: safeInitialDate.hour,
        minute: safeInitialDate.minute,
      ),
    );

    if (pickedTime == null) return null;

    final DateTime result = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (result.isAfter(DateTime.now())) {
      _showMessage('$title tidak boleh melewati waktu sekarang.');
      return null;
    }

    return result;
  }

  Future<bool> _showPreviewBeforeSave({
    required DateTime sleepTime,
    required DateTime wakeTime,
  }) async {
    DateTime editedSleepTime = sleepTime;
    DateTime editedWakeTime = wakeTime;

    while (mounted) {
      final SleepPreviewAction? action = await _showSleepPreviewDialog(
        sleepTime: editedSleepTime,
        wakeTime: editedWakeTime,
      );

      if (action == null || action == SleepPreviewAction.cancel) {
        return false;
      }

      if (action == SleepPreviewAction.save) {
        if (!_isDateTimeNotFuture(editedSleepTime)) {
          _showMessage('Sleep time tidak boleh melewati waktu sekarang.');
          continue;
        }

        if (!_isDateTimeNotFuture(editedWakeTime)) {
          _showMessage('Wake time tidak boleh melewati waktu sekarang.');
          continue;
        }

        if (!_isValidSleepRange(
          sleepTime: editedSleepTime,
          wakeTime: editedWakeTime,
        )) {
          _showMessage(
            'Wake time harus setelah sleep time dan durasi tidur harus valid.',
          );
          continue;
        }

        await _saveSleepLog(
          sleepTime: editedSleepTime,
          wakeTime: editedWakeTime,
        );

        return true;
      }

      if (action == SleepPreviewAction.edit) {
        final DateTime? newSleepTime = await _pickDateTime(
          title: 'Edit sleep time',
          initialDateTime: editedSleepTime,
        );

        if (newSleepTime == null) continue;

        if (!_isDateTimeNotFuture(newSleepTime)) {
          _showMessage('Sleep time tidak boleh melewati waktu sekarang.');
          continue;
        }

        final DateTime? newWakeTime = await _pickDateTime(
          title: 'Edit wake time',
          initialDateTime: editedWakeTime,
        );

        if (newWakeTime == null) continue;

        if (!_isDateTimeNotFuture(newWakeTime)) {
          _showMessage('Wake time tidak boleh melewati waktu sekarang.');
          continue;
        }

        if (!_isValidSleepRange(
          sleepTime: newSleepTime,
          wakeTime: newWakeTime,
        )) {
          _showMessage(
            'Wake time harus setelah sleep time dan durasi tidur harus valid.',
          );
          continue;
        }

        editedSleepTime = newSleepTime;
        editedWakeTime = newWakeTime;
      }
    }

    return false;
  }

  Future<SleepPreviewAction?> _showSleepPreviewDialog({
    required DateTime sleepTime,
    required DateTime wakeTime,
  }) {
    final Duration duration = wakeTime.difference(sleepTime);

    final bool isSleepTimeFuture = sleepTime.isAfter(DateTime.now());
    final bool isWakeTimeFuture = wakeTime.isAfter(DateTime.now());
    final bool isDurationValid = duration.inMinutes > 0;

    final bool canSave =
        !isSleepTimeFuture && !isWakeTimeFuture && isDurationValid;

    return showDialog<SleepPreviewAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Sleep Log?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPreviewDialogRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Daily log date',
                  value: _formatShortDate(_targetDailyDate),
                ),
                const SizedBox(height: 10),
                _buildPreviewDialogRow(
                  icon: Icons.bedtime_rounded,
                  label: 'Sleep time',
                  value: _formatDateTime(sleepTime),
                ),
                const SizedBox(height: 10),
                _buildPreviewDialogRow(
                  icon: Icons.wb_twilight_rounded,
                  label: 'Wake time',
                  value: _formatDateTime(wakeTime),
                ),
                const SizedBox(height: 10),
                _buildPreviewDialogRow(
                  icon: Icons.timer_rounded,
                  label: 'Duration',
                  value: isDurationValid
                      ? _formatDuration(duration)
                      : 'Invalid',
                ),
                if (!canSave) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Sleep time dan wake time tidak boleh melewati waktu sekarang.'
                    ' Wake time juga harus setelah sleep time.',
                    style: AppTextStyles.small.copyWith(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(SleepPreviewAction.cancel);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(SleepPreviewAction.edit);
              },
              child: const Text('Edit'),
            ),
            ElevatedButton(
              onPressed: canSave
                  ? () {
                      Navigator.of(context).pop(SleepPreviewAction.save);
                    }
                  : null,
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewDialogRow({
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
          Icon(icon, size: 20, color: AppColors.primaryFixedDim),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.subtitle)),
          const SizedBox(width: 12),
          Flexible(
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

  bool _isDateTimeNotFuture(DateTime value) {
    return !value.isAfter(DateTime.now());
  }

  bool _isValidSleepRange({
    required DateTime sleepTime,
    required DateTime wakeTime,
  }) {
    return wakeTime.difference(sleepTime).inMinutes > 0;
  }

  Future<void> _saveSleepLog({
    required DateTime sleepTime,
    required DateTime wakeTime,
  }) async {
    if (!_isDateTimeNotFuture(sleepTime)) {
      _showMessage('Sleep time tidak boleh melewati waktu sekarang.');
      return;
    }

    if (!_isDateTimeNotFuture(wakeTime)) {
      _showMessage('Wake time tidak boleh melewati waktu sekarang.');
      return;
    }

    if (!_isValidSleepRange(sleepTime: sleepTime, wakeTime: wakeTime)) {
      _showMessage(
        'Wake time harus setelah sleep time dan durasi tidur harus valid.',
      );
      return;
    }

    final Duration duration = wakeTime.difference(sleepTime);
    final int durationMinutes = duration.inMinutes;
    final int score = _calculateSleepScore(durationMinutes);
    final DateTime now = DateTime.now();

    final SleepLog sleepLog = SleepLog(
      id: _existingSleepLog?.id ?? now.millisecondsSinceEpoch.toString(),
      date: _targetDailyDate,
      sleepTime: sleepTime,
      wakeTime: wakeTime,
      durationMinutes: durationMinutes,
      sleepScore: score,
      createdAt: _existingSleepLog?.createdAt ?? now,
      updatedAt: now,
    );

    final sleepService = ref.read(sleepLogRepositoryProvider);
    await sleepService.saveSleepLogForDate(sleepLog);

    ref.invalidate(latestSleepLogProvider);
    ref.invalidate(allSleepLogsProvider);
    // Progress achievement bergantung pada sleep log — invalidate supaya
    // achievement baru langsung terdeteksi setelah tidur dicatat.
    ref.invalidate(achievementProgressProvider);

    if (!mounted) return;

    _showMessage('Sleep log saved for ${_formatShortDate(_targetDailyDate)}.');
    _loadSleepLogForTargetDate();
  }

  int _calculateSleepScore(int durationMinutes) {
    const int idealSleepMinutes = 8 * 60;

    final int difference = (durationMinutes - idealSleepMinutes).abs();
    final int penalty = difference ~/ 5;
    final int score = 100 - penalty;

    if (score < 0) return 0;
    if (score > 100) return 100;

    return score;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToDashboard() {
    context.go(AppRoutePath.dashboard);
  }

  String _formatDateTime(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
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

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes % 60;
    final int seconds = duration.inSeconds % 60;
    final int millis = (duration.inMilliseconds % 1000) ~/ 10; // 2 digit

    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    final String ms = millis.toString().padLeft(2, '0');

    return '${hours}h ${mm}m ${ss}s.$ms';
  }

  // ────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      showBottomNavigation: false,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 18),
            if (_existingSleepLog != null)
              _buildExistingSleepCard(_existingSleepLog!)
            else if (_isAutoSleepEnabled)
              _buildSleepTrackerCard()
            else
              _buildPastDateNoLogCard(),
            const SizedBox(height: 18),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return AppCard(
      color: AppColors.surfaceVariant.withOpacity(0.58),
      padding: const EdgeInsets.all(24),
      radius: 38,
      isGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep ritual',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primaryFixedDim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text('Ready for night?', style: AppTextStyles.displayMedium),
          const SizedBox(height: 10),
          Text(
            'This sleep log will be attached to your selected daily log date.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 18),
          AppCard(
            color: AppColors.surfaceLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            radius: 26,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primaryFixedDim,
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sleep for Daily Log',
                    style: AppTextStyles.subtitle,
                  ),
                ),
                Text(
                  _formatShortDate(_targetDailyDate),
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Auto sleep tracker — hanya tampil untuk hari ini ──────────────────────

  Widget _buildSleepTrackerCard() {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(26),
      radius: 40,
      child: Column(
        children: [
          _buildCircularSleepButton(),
          const SizedBox(height: 24),
          Text(
            _isSleeping ? _formatDuration(_sleepDuration) : 'Ready to sleep',
            style: AppTextStyles.metricSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _isSleeping
                ? 'Sleep timer is running. Tap the circle to stop.'
                : 'Tap the circle to start your sleep timer.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          if (_sleepStartTime != null) ...[
            const SizedBox(height: 16),
            _buildInfoTile(
              icon: Icons.bedtime_rounded,
              label: 'Started at',
              value: _formatDateTime(_sleepStartTime!),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_done_rounded,
                  size: 13,
                  color: AppColors.primaryFixedDim,
                ),
                const SizedBox(width: 5),
                Text(
                  'Timer tetap berjalan meski app ditutup',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.primaryFixedDim,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularSleepButton() {
    final bool isActive = _isSleeping;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _handleSleepButton,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 190,
        height: 190,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isActive ? AppColors.sleepGradient : AppColors.calmGradient,
          boxShadow: const [
            BoxShadow(
              color: AppColors.softGlow,
              blurRadius: 42,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withOpacity(0.28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? Icons.stop_rounded : Icons.nightlight_round,
                size: 54,
                color: isActive ? AppColors.onPrimary : AppColors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                isActive ? 'STOP' : 'START',
                style: AppTextStyles.label.copyWith(
                  color: isActive ? AppColors.onPrimary : AppColors.primary,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SLEEP',
                style: AppTextStyles.small.copyWith(
                  color: isActive
                      ? AppColors.onPrimary.withOpacity(0.72)
                      : AppColors.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Past date — tidak ada sleep log ───────────────────────────────────────

  Widget _buildPastDateNoLogCard() {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(26),
      radius: 40,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceVariant,
            ),
            child: const Icon(
              Icons.bedtime_outlined,
              size: 38,
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Sleep Log',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Auto-tracking tidak tersedia untuk tanggal lalu.\nTambahkan sleep log secara manual.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showManualSleepInput,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Sleep Log'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Existing sleep card ────────────────────────────────────────────────────

  Widget _buildExistingSleepCard(SleepLog sleepLog) {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(26),
      radius: 40,
      child: Column(
        children: [
          _buildSleepScoreArc(sleepLog.sleepScore),
          const SizedBox(height: 22),
          const Text(
            'Sleep Log Recorded',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            sleepLog.formattedDuration,
            style: AppTextStyles.metric,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This date already has one main sleep log.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          _buildInfoTile(
            icon: Icons.calendar_month_rounded,
            label: 'Daily date',
            value: _formatShortDate(sleepLog.date),
          ),
          const SizedBox(height: 10),
          _buildInfoTile(
            icon: Icons.bedtime_rounded,
            label: 'Sleep',
            value: _formatDateTime(sleepLog.sleepTime),
          ),
          const SizedBox(height: 10),
          _buildInfoTile(
            icon: Icons.wb_twilight_rounded,
            label: 'Wake',
            value: _formatDateTime(sleepLog.wakeTime),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showManualSleepInput,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit Sleep Log'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepScoreArc(int score) {
    final double progress = (score.clamp(0, 100)) / 100;

    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 124,
            height: 124,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 12,
              color: AppColors.surfaceVariant,
            ),
          ),
          SizedBox(
            width: 124,
            height: 124,
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
                '$score\nQUALITY',
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

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 26,
      child: Row(
        children: [
          Icon(icon, size: 21, color: AppColors.primaryFixedDim),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.subtitle)),
          const SizedBox(width: 12),
          Flexible(
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

  // ── Action buttons ─────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return AppCard(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.all(18),
      radius: 34,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _goToDashboard,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to Dashboard'),
        ),
      ),
    );
  }
}
