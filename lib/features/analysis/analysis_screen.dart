import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/local/local_daily_log_service.dart';
import '../../data/local/local_sleep_service.dart';
import '../../data/models/analysis_cache.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/sleep_log.dart';
import '../../data/remote/ai_analysis_service.dart';
import '../../data/repositories/analysis_repository.dart';
import '../daily_log/daily_log_providers.dart';
import '../sleep/sleep_providers.dart';
import 'analysis_providers.dart';

enum AnalysisPeriod { daily, weekly, monthly }

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late final LocalSleepService _localSleepService;
  late final LocalDailyLogService _dailyLogService;
  late final AnalysisRepository _analysisRepository;
  late final AiAnalysisService _aiAnalysisService;

  AnalysisPeriod _selectedPeriod = AnalysisPeriod.daily;

  late DateTime _selectedAnalysisDate;
  late DateTime _selectedEndDate;

  AnalysisCache? _latestCache;

  String _summary = '';
  String _insight = '';
  String _recommendation = '';
  String _warningMessage = '';
  String _missingDataMessage = '';

  bool _isGenerating = false;
  bool _isUsingFallback = false;

  @override
  void initState() {
    super.initState();

    _localSleepService = ref.read(sleepLogRepositoryProvider);
    _dailyLogService = ref.read(dailyLogRepositoryProvider);
    _analysisRepository = ref.read(analysisRepositoryProvider);
    _aiAnalysisService = ref.read(aiAnalysisServiceProvider);

    final DateTime defaultDate = _getDefaultAnalysisDate();

    _selectedAnalysisDate = defaultDate;
    _selectedEndDate = defaultDate;

    _refreshAnalysisState();
  }

  DateTime _getDefaultAnalysisDate() {
    final DateTime? latestSleepDate = _localSleepService
        .getLatestSleepLogDate();

    if (latestSleepDate != null) {
      return _dateOnly(latestSleepDate);
    }

    return _dateOnly(DateTime.now());
  }

  void _changePeriod(AnalysisPeriod period) {
    setState(() {
      _selectedPeriod = period;
      _warningMessage = '';
      _isUsingFallback = false;
      _summary = '';
      _insight = '';
      _recommendation = '';
      _latestCache = null;
    });

    _refreshAnalysisState();
  }

  void _refreshAnalysisState() {
    final _AnalysisData data = _buildAnalysisData();

    _loadCacheForData(data);
    _loadMissingDataWarning(data);
  }

  void _loadCacheForData(_AnalysisData data) {
    final AnalysisCache? cache = _analysisRepository
        .getLatestAnalysisCacheByPeriodAndRange(
          periodType: data.periodType,
          periodStart: data.periodStart,
          periodEnd: data.periodEnd,
        );

    if (cache == null) {
      setState(() {
        _latestCache = null;
        _summary = '';
        _insight = '';
        _recommendation = '';
      });
      return;
    }

    setState(() {
      _latestCache = cache;
      _summary = cache.summary;
      _insight = cache.insight;
      _recommendation = cache.recommendation;
    });
  }

  void _loadMissingDataWarning(_AnalysisData data) {
    setState(() {
      _missingDataMessage = _buildMissingDataMessage(data);
    });
  }

  Future<void> _pickAnalysisDate() async {
    final DateTime currentValue = _selectedPeriod == AnalysisPeriod.daily
        ? _selectedAnalysisDate
        : _selectedEndDate;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _dateOnly(DateTime.now()),
      helpText: _selectedPeriod == AnalysisPeriod.daily
          ? 'Select analysis date'
          : 'Select period end date',
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      if (_selectedPeriod == AnalysisPeriod.daily) {
        _selectedAnalysisDate = _dateOnly(pickedDate);
      } else {
        _selectedEndDate = _dateOnly(pickedDate);
      }

      _warningMessage = '';
      _isUsingFallback = false;
    });

    _refreshAnalysisState();
  }

  Future<void> _generateAnalysis() async {
    setState(() {
      _warningMessage = '';
      _isGenerating = true;
      _isUsingFallback = false;
    });

    final _AnalysisData data = _buildAnalysisData();

    if (data.sleepLogs.isEmpty) {
      setState(() {
        _warningMessage = _buildNoSleepDataMessage();
        _summary = '';
        _insight = '';
        _recommendation = '';
        _latestCache = null;
        _missingDataMessage = _buildMissingDataMessage(data);
        _isGenerating = false;
      });
      return;
    }

    String generatedSummary = '';
    String generatedInsight = '';
    String generatedRecommendation = '';
    bool usingFallback = false;

    try {
      final AiAnalysisResult aiResult = await _aiAnalysisService
          .generateSleepAnalysis(
            periodType: data.periodType,
            periodStart: data.periodStart,
            periodEnd: data.periodEnd,
            sleepLogs: data.sleepLogs,
            dailyLogs: data.dailyLogs,
            missingSleepDates: data.missingSleepDates,
          );

      generatedSummary = aiResult.summary;
      generatedInsight = aiResult.insight;
      generatedRecommendation = aiResult.recommendation;
    } catch (_) {
      usingFallback = true;

      generatedSummary = _buildFallbackSummary(data);
      generatedInsight = _buildFallbackInsight(data);
      generatedRecommendation = _buildFallbackRecommendation(data);
    }

    final AnalysisCache cache = AnalysisCache(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      periodType: data.periodType,
      periodStart: data.periodStart,
      periodEnd: data.periodEnd,
      summary: generatedSummary,
      insight: generatedInsight,
      recommendation: generatedRecommendation,
      createdAt: DateTime.now(),
    );

    await _analysisRepository.saveAnalysisCache(cache);

    if (!mounted) {
      return;
    }

    setState(() {
      _latestCache = cache;
      _warningMessage = '';
      _missingDataMessage = _buildMissingDataMessage(data);
      _summary = generatedSummary;
      _insight = generatedInsight;
      _recommendation = generatedRecommendation;
      _isGenerating = false;
      _isUsingFallback = usingFallback;
    });

    if (usingFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI API gagal, menggunakan analysis lokal.'),
        ),
      );
    }
  }

  _AnalysisData _buildAnalysisData() {
    if (_selectedPeriod == AnalysisPeriod.daily) {
      final DateTime targetDate = _dateOnly(_selectedAnalysisDate);

      final SleepLog? sleepLog = _localSleepService.getSleepLogByDate(
        targetDate,
      );

      final DailyLog? dailyLog = _dailyLogService.getDailyLogByDate(targetDate);

      return _AnalysisData(
        periodType: _periodTypeText,
        periodStart: targetDate,
        periodEnd: targetDate,
        sleepLogs: sleepLog == null ? [] : [sleepLog],
        dailyLogs: dailyLog == null ? [] : [dailyLog],
        missingSleepDates: sleepLog == null ? [targetDate] : [],
      );
    }

    final int days = _selectedPeriod == AnalysisPeriod.weekly ? 7 : 30;
    final DateTime periodEnd = _dateOnly(_selectedEndDate);
    final DateTime periodStart = periodEnd.subtract(Duration(days: days - 1));

    final List<SleepLog> sleepLogs = _localSleepService.getSleepLogsBetween(
      startDate: periodStart,
      endDate: periodEnd,
    );

    final List<DailyLog> dailyLogs = _dailyLogService.getDailyLogsBetween(
      startDate: periodStart,
      endDate: periodEnd,
    );

    final List<DateTime> missingSleepDates = _localSleepService
        .getMissingSleepDates(startDate: periodStart, endDate: periodEnd);

    return _AnalysisData(
      periodType: _periodTypeText,
      periodStart: periodStart,
      periodEnd: periodEnd,
      sleepLogs: sleepLogs,
      dailyLogs: dailyLogs,
      missingSleepDates: missingSleepDates,
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String get _periodTypeText {
    switch (_selectedPeriod) {
      case AnalysisPeriod.daily:
        return 'daily';
      case AnalysisPeriod.weekly:
        return 'weekly';
      case AnalysisPeriod.monthly:
        return 'monthly';
    }
  }

  String _periodLabel(AnalysisPeriod period) {
    switch (period) {
      case AnalysisPeriod.daily:
        return 'Daily';
      case AnalysisPeriod.weekly:
        return 'Weekly';
      case AnalysisPeriod.monthly:
        return 'Monthly';
    }
  }

  IconData _periodIcon(AnalysisPeriod period) {
    switch (period) {
      case AnalysisPeriod.daily:
        return Icons.today_rounded;
      case AnalysisPeriod.weekly:
        return Icons.view_week_rounded;
      case AnalysisPeriod.monthly:
        return Icons.calendar_month_rounded;
    }
  }

  String _buildNoSleepDataMessage() {
    switch (_selectedPeriod) {
      case AnalysisPeriod.daily:
        return 'Belum ada sleep log untuk ${_formatDate(_selectedAnalysisDate)}. Daily analysis membutuhkan minimal 1 sleep log pada tanggal yang dipilih.';
      case AnalysisPeriod.weekly:
        return 'Belum ada sleep log dalam range weekly ${_formatDate(_currentPeriodStart)} sampai ${_formatDate(_currentPeriodEnd)}.';
      case AnalysisPeriod.monthly:
        return 'Belum ada sleep log dalam range monthly ${_formatDate(_currentPeriodStart)} sampai ${_formatDate(_currentPeriodEnd)}.';
    }
  }

  String _buildMissingDataMessage(_AnalysisData data) {
    if (data.sleepLogs.isEmpty) {
      return '';
    }

    if (_selectedPeriod == AnalysisPeriod.daily) {
      if (data.dailyLogs.isEmpty) {
        return 'Daily log untuk ${_formatDate(data.periodStart)} belum diisi. Analysis tetap bisa dibuat dari sleep log, tetapi data tambahan belum tersedia.';
      }

      return '';
    }

    if (data.missingSleepDates.isEmpty) {
      if (data.dailyLogs.isEmpty) {
        return 'Tidak ada daily log tambahan dalam periode ini. Analysis tetap bisa dibuat dari sleep log.';
      }

      return '';
    }

    final int missingCount = data.missingSleepDates.length;

    return 'Ada $missingCount hari tanpa sleep log pada periode ${_formatDate(data.periodStart)} sampai ${_formatDate(data.periodEnd)}. Analysis tetap dibuat, tetapi konsistensi data belum lengkap.';
  }

  String _buildFallbackSummary(_AnalysisData data) {
    final int averageMinutes = _averageSleepMinutes(data.sleepLogs);

    return 'Pada periode ${_periodLabel(_selectedPeriod)} ${_formatDate(data.periodStart)} sampai ${_formatDate(data.periodEnd)}, terdapat ${data.sleepLogs.length} sleep log dengan rata-rata durasi tidur ${_formatMinutes(averageMinutes)}.';
  }

  String _buildFallbackInsight(_AnalysisData data) {
    final int averageMinutes = _averageSleepMinutes(data.sleepLogs);
    final List<String> insights = [];

    if (averageMinutes < 7 * 60) {
      insights.add(
        'Rata-rata durasi tidur masih di bawah 7 jam, sehingga waktu istirahat kemungkinan belum optimal.',
      );
    } else if (averageMinutes <= 9 * 60) {
      insights.add(
        'Rata-rata durasi tidur berada dalam rentang yang cukup baik.',
      );
    } else {
      insights.add(
        'Rata-rata durasi tidur lebih panjang dari biasanya. Perlu diperhatikan apakah tidur terasa berkualitas atau justru berlebihan.',
      );
    }

    if (data.dailyLogs.isEmpty) {
      insights.add(
        'Data tambahan seperti mood, caffeine, meal, activity, dan kondisi belum tercatat, sehingga insight masih terbatas.',
      );
    } else {
      final bool hasNightCaffeine = data.dailyLogs.any((dailyLog) {
        return dailyLog.caffeineLogs.any((caffeine) {
          return caffeine.dateTime.hour >= 18;
        });
      });

      if (hasNightCaffeine) {
        insights.add(
          'Terdapat caffeine yang dicatat pada sore atau malam hari. Ini mungkin berpengaruh pada kualitas tidur, terutama jika dikonsumsi dekat waktu tidur.',
        );
      }

      final bool hasConditionIssue = data.dailyLogs.any((dailyLog) {
        return dailyLog.conditionType != 'normal' ||
            dailyLog.conditionNote.trim().isNotEmpty;
      });

      if (hasConditionIssue) {
        insights.add(
          'Ada catatan kondisi tubuh atau pikiran yang mungkin memengaruhi tidur.',
        );
      }

      final bool hasSleepHelpers = data.dailyLogs.any((dailyLog) {
        return dailyLog.sleepHelpers.isNotEmpty;
      });

      if (hasSleepHelpers) {
        insights.add(
          'Sleep helpers sudah tercatat. Kebiasaan seperti mengurangi layar, ruangan gelap, atau relaksasi bisa membantu rutinitas tidur.',
        );
      }

      final bool hasMeal = data.dailyLogs.any((dailyLog) {
        return dailyLog.mealLogs.isNotEmpty;
      });

      if (hasMeal) {
        insights.add(
          'Meal photo sudah tercatat. Jika image recognition aktif, data makanan dapat membantu melihat kemungkinan pengaruh makan malam terhadap tidur.',
        );
      }
    }

    if (data.missingSleepDates.isNotEmpty) {
      insights.add(
        'Ada beberapa tanggal tanpa sleep log, sehingga pola tidur pada periode ini belum sepenuhnya lengkap.',
      );
    }

    return insights.join(' ');
  }

  String _buildFallbackRecommendation(_AnalysisData data) {
    final int averageMinutes = _averageSleepMinutes(data.sleepLogs);
    final List<String> recommendations = [];

    if (averageMinutes < 7 * 60) {
      recommendations.add(
        'Coba majukan waktu tidur secara bertahap agar durasi tidur mendekati 7 sampai 9 jam.',
      );
    } else {
      recommendations.add(
        'Pertahankan durasi tidur yang sudah cukup dan lanjutkan pencatatan secara konsisten.',
      );
    }

    recommendations.add(
      'Isi daily log seperti caffeine, meal, mood, activity, dan condition agar analisis berikutnya lebih akurat.',
    );

    if (data.missingSleepDates.isNotEmpty) {
      recommendations.add(
        'Usahakan mencatat sleep log setiap hari agar weekly/monthly analysis lebih stabil.',
      );
    }

    return recommendations.join(' ');
  }

  int _averageSleepMinutes(List<SleepLog> logs) {
    if (logs.isEmpty) {
      return 0;
    }

    final int total = logs.fold<int>(
      0,
      (sum, log) => sum + log.durationMinutes,
    );

    return total ~/ logs.length;
  }

  String _formatMinutes(int minutes) {
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;

    return '${hours}h ${remainingMinutes}m';
  }

  DateTime get _currentPeriodStart {
    if (_selectedPeriod == AnalysisPeriod.daily) {
      return _dateOnly(_selectedAnalysisDate);
    }

    final int days = _selectedPeriod == AnalysisPeriod.weekly ? 7 : 30;

    return _dateOnly(_selectedEndDate).subtract(Duration(days: days - 1));
  }

  DateTime get _currentPeriodEnd {
    if (_selectedPeriod == AnalysisPeriod.daily) {
      return _dateOnly(_selectedAnalysisDate);
    }

    return _dateOnly(_selectedEndDate);
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

  @override
  Widget build(BuildContext context) {
    final _AnalysisData data = _buildAnalysisData();

    return AppScaffold(
      currentIndex: 1,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(data),
            const SizedBox(height: 18),
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildDateSelectorCard(data),
            if (_warningMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildMessageCard(
                icon: Icons.error_outline_rounded,
                message: _warningMessage,
                color: AppColors.error.withOpacity(0.16),
                iconColor: AppColors.error,
              ),
            ],
            if (_missingDataMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildMessageCard(
                icon: Icons.info_outline_rounded,
                message: _missingDataMessage,
                color: AppColors.surfaceVariant,
                iconColor: AppColors.primaryFixedDim,
              ),
            ],
            const SizedBox(height: 16),
            _buildGenerateButton(),
            const SizedBox(height: 18),
            _buildResultSection(),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(_AnalysisData data) {
    final String period = _periodLabel(_selectedPeriod);
    final int sleepCount = data.sleepLogs.length;
    final int dailyCount = data.dailyLogs.length;

    return AppCard(
      color: AppColors.surfaceVariant.withOpacity(0.58),
      padding: const EdgeInsets.all(24),
      radius: 38,
      isGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI sleep insight',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primaryFixedDim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text('$period Analysis', style: AppTextStyles.displayMedium),
          const SizedBox(height: 10),
          Text(
            'Sleep data becomes a quiet story about your nightly rhythm.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildHeroMetric(
                  icon: Icons.bedtime_rounded,
                  label: 'Sleep logs',
                  value: sleepCount.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeroMetric(
                  icon: Icons.notes_rounded,
                  label: 'Daily logs',
                  value: dailyCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(14),
      radius: 26,
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryFixedDim, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.metricSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.small, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return AppCard(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.all(10),
      radius: 32,
      child: Row(
        children: AnalysisPeriod.values.map((period) {
          final bool isSelected = _selectedPeriod == period;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _changePeriod(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _periodIcon(period),
                        size: 20,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.primaryFixedDim,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _periodLabel(period),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          color: isSelected
                              ? AppColors.onPrimary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateSelectorCard(_AnalysisData data) {
    final String title = _selectedPeriod == AnalysisPeriod.daily
        ? 'Daily Analysis Date'
        : '${_periodLabel(_selectedPeriod)} End Date';

    final String mainDate = _selectedPeriod == AnalysisPeriod.daily
        ? _formatShortDate(_selectedAnalysisDate)
        : _formatShortDate(_selectedEndDate);

    final String rangeText = _selectedPeriod == AnalysisPeriod.daily
        ? 'Pairing DailyLog + SleepLog on this date.'
        : 'Range: ${_formatDate(data.periodStart)} to ${_formatDate(data.periodEnd)}';

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerHighest,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primaryFixedDim,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            mainDate,
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            rangeText,
            style: AppTextStyles.small,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _pickAnalysisDate,
            icon: const Icon(Icons.edit_calendar_rounded),
            label: const Text('Pick Date'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    final String label = _isGenerating
        ? 'Generating...'
        : 'Generate ${_periodLabel(_selectedPeriod)} Analysis';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateAnalysis,
        icon: _isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: AppColors.onPrimary,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(label),
      ),
    );
  }

  Widget _buildResultSection() {
    if (_summary.isEmpty && _insight.isEmpty && _recommendation.isEmpty) {
      return AppCard(
        color: AppColors.surfaceContainer,
        padding: const EdgeInsets.all(22),
        radius: 34,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.calmGradient,
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.primaryFixedDim,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada analysis',
              style: AppTextStyles.cardTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih tanggal atau range, lalu tekan Generate Analysis.',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCacheInfoCard(),
        const SizedBox(height: 14),
        _buildResultCard(
          icon: Icons.nights_stay_rounded,
          title: 'Simpulan',
          text: _summary,
        ),
        const SizedBox(height: 14),
        _buildResultCard(
          icon: Icons.psychology_alt_rounded,
          title: 'Insight',
          text: _insight,
        ),
        const SizedBox(height: 14),
        _buildResultCard(
          icon: Icons.spa_rounded,
          title: 'Rekomendasi',
          text: _recommendation,
        ),
      ],
    );
  }

  Widget _buildCacheInfoCard() {
    final List<Widget> children = [];

    if (_latestCache != null) {
      children.add(
        _buildMiniInfoPill(
          icon: Icons.cached_rounded,
          text:
              'Cached ${_formatDate(_latestCache!.periodStart)} - ${_formatDate(_latestCache!.periodEnd)}',
        ),
      );
    }

    if (_isUsingFallback) {
      children.add(
        _buildMiniInfoPill(
          icon: Icons.offline_bolt_rounded,
          text: 'Using local fallback',
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(14),
      radius: 28,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildMiniInfoPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryFixedDim),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.small.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required String title,
    required String text,
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
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                ),
                child: Icon(icon, color: AppColors.primaryFixedDim, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            text.isEmpty ? '-' : text,
            style: AppTextStyles.body.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String message,
    required Color color,
    required Color iconColor,
  }) {
    return AppCard(
      color: color,
      padding: const EdgeInsets.all(16),
      radius: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _AnalysisData {
  final String periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<SleepLog> sleepLogs;
  final List<DailyLog> dailyLogs;
  final List<DateTime> missingSleepDates;

  const _AnalysisData({
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.sleepLogs,
    required this.dailyLogs,
    required this.missingSleepDates,
  });
}
