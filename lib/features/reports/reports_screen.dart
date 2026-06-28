import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/local/local_sleep_service.dart';
import '../../data/models/sleep_log.dart';

enum ReportPeriod { weekly, monthly }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const int _rowsPerPage = 10;

  final LocalSleepService _localSleepService = LocalSleepService();

  ReportPeriod _selectedPeriod = ReportPeriod.weekly;
  DateTimeRange? _customDateRange;

  List<SleepLog> _allSleepLogs = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSleepLogs();
  }

  void _loadSleepLogs() {
    setState(() {
      _allSleepLogs = _localSleepService.getAllSleepLogs();
      _currentPage = 0;
    });
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime get _today {
    return _dateOnly(DateTime.now());
  }

  DateTime get _defaultStartDate {
    final int days = _selectedPeriod == ReportPeriod.weekly ? 7 : 30;
    return _today.subtract(Duration(days: days - 1));
  }

  DateTime get _activeStartDate {
    return _customDateRange == null
        ? _defaultStartDate
        : _dateOnly(_customDateRange!.start);
  }

  DateTime get _activeEndDate {
    return _customDateRange == null ? _today : _dateOnly(_customDateRange!.end);
  }

  List<SleepLog> _getFilteredLogs() {
    final DateTime startDate = _activeStartDate;
    final DateTime endDate = _activeEndDate;

    final List<SleepLog> filteredLogs = _allSleepLogs.where((log) {
      final DateTime logDate = _dateOnly(log.date);

      return !logDate.isBefore(startDate) && !logDate.isAfter(endDate);
    }).toList();

    filteredLogs.sort((a, b) => a.date.compareTo(b.date));

    return filteredLogs;
  }

  List<SleepLog> _getCurrentPageLogs(List<SleepLog> logs) {
    if (logs.isEmpty) {
      return [];
    }

    final int safePage = _safeCurrentPage(logs);
    final int startIndex = safePage * _rowsPerPage;
    final int endIndex = min(startIndex + _rowsPerPage, logs.length);

    return logs.sublist(startIndex, endIndex);
  }

  int _totalPages(List<SleepLog> logs) {
    if (logs.isEmpty) {
      return 1;
    }

    return (logs.length / _rowsPerPage).ceil();
  }

  int _safeCurrentPage(List<SleepLog> logs) {
    final int total = _totalPages(logs);

    if (_currentPage < 0) {
      return 0;
    }

    if (_currentPage >= total) {
      return total - 1;
    }

    return _currentPage;
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

  int _averageScore(List<SleepLog> logs) {
    if (logs.isEmpty) {
      return 0;
    }

    final int total = logs.fold<int>(
      0,
      (sum, log) => sum + _calculateSleepScore(log.durationMinutes),
    );

    return total ~/ logs.length;
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

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }

  String _formatFullDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatChartDate(DateTime date) {
    return DateFormat('dd/MM').format(date);
  }

  String _formatMinutes(int minutes) {
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;

    return '${hours}h ${remainingMinutes}m';
  }

  String get _periodLabel {
    return _selectedPeriod == ReportPeriod.weekly ? 'Weekly' : 'Monthly';
  }

  String get _rangeLabel {
    final String start = _formatFullDate(_activeStartDate);
    final String end = _formatFullDate(_activeEndDate);

    if (_customDateRange != null) {
      return 'Custom: $start - $end';
    }

    return '$_periodLabel: $start - $end';
  }

  void _changePeriod(ReportPeriod period) {
    setState(() {
      _selectedPeriod = period;
      _customDateRange = null;
      _currentPage = 0;
    });
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _today,
      initialDateRange: DateTimeRange(
        start: _activeStartDate,
        end: _activeEndDate,
      ),
      helpText: 'Filter report date',
    );

    if (pickedRange == null) {
      return;
    }

    setState(() {
      _customDateRange = DateTimeRange(
        start: _dateOnly(pickedRange.start),
        end: _dateOnly(pickedRange.end),
      );
      _currentPage = 0;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _customDateRange = null;
      _currentPage = 0;
    });
  }

  void _previousPage(List<SleepLog> logs) {
    final int safePage = _safeCurrentPage(logs);

    if (safePage <= 0) {
      return;
    }

    setState(() {
      _currentPage = safePage - 1;
    });
  }

  void _nextPage(List<SleepLog> logs) {
    final int safePage = _safeCurrentPage(logs);
    final int total = _totalPages(logs);

    if (safePage >= total - 1) {
      return;
    }

    setState(() {
      _currentPage = safePage + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<SleepLog> filteredLogs = _getFilteredLogs();

    return AppScaffold(
      currentIndex: 3,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(filteredLogs),
            const SizedBox(height: 18),
            _buildPeriodToggle(),
            const SizedBox(height: 14),
            _buildFilterCard(),
            const SizedBox(height: 18),
            if (filteredLogs.isEmpty)
              _buildEmptyState()
            else ...[
              _buildSummaryCards(filteredLogs),
              const SizedBox(height: 18),
              _buildChartCard(filteredLogs),
              const SizedBox(height: 18),
              _buildTableCard(filteredLogs),
            ],
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(List<SleepLog> logs) {
    return AppCard(
      color: AppColors.surfaceVariant.withOpacity(0.58),
      padding: const EdgeInsets.all(24),
      radius: 38,
      isGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep reports',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primaryFixedDim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text('Your sleep story', style: AppTextStyles.displayMedium),
          const SizedBox(height: 10),
          Text(
            'Track duration, quality score, and patterns across your selected period.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 18),
          AppCard(
            color: AppColors.surfaceLow,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: 26,
            child: Row(
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  color: AppColors.primaryFixedDim,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_rangeLabel, style: AppTextStyles.bodyMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return AppCard(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.all(10),
      radius: 32,
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              text: 'Weekly',
              icon: Icons.view_week_rounded,
              period: ReportPeriod.weekly,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildToggleButton(
              text: 'Monthly',
              icon: Icons.calendar_month_rounded,
              period: ReportPeriod.monthly,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String text,
    required IconData icon,
    required ReportPeriod period,
  }) {
    final bool isActive = _selectedPeriod == period && _customDateRange == null;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _changePeriod(period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.primaryGradient : null,
          color: isActive ? null : AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.onPrimary : AppColors.primaryFixedDim,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(
                color: isActive
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(18),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_rounded,
                color: AppColors.primaryFixedDim,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Date Filter', style: AppTextStyles.cardTitle),
              ),
              IconButton(
                tooltip: 'Refresh report',
                onPressed: _loadSleepLogs,
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primaryFixedDim,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_rangeLabel, style: AppTextStyles.subtitle),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Pick Date'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _customDateRange == null ? null : _clearDateFilter,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<SleepLog> logs) {
    final int averageMinutes = _averageSleepMinutes(logs);
    final int averageScore = _averageScore(logs);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.bedtime_rounded,
            label: 'Logs',
            value: logs.length.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.timer_rounded,
            label: 'Avg Sleep',
            value: _formatMinutes(averageMinutes),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.auto_awesome_rounded,
            label: 'Avg Score',
            value: averageScore.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      radius: 28,
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryFixedDim, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.small, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final String periodText = _customDateRange != null
        ? 'custom date filter'
        : _selectedPeriod == ReportPeriod.weekly
        ? 'weekly period'
        : 'monthly period';

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(24),
      radius: 38,
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.calmGradient,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: AppColors.primaryFixedDim,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No report data yet',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No sleep logs found for this $periodText.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<SleepLog> logs) {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep Duration Chart', style: AppTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            'Hours of sleep across selected dates.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: _SleepDurationChart(
              logs: logs,
              formatChartDate: _formatChartDate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(List<SleepLog> logs) {
    final int safePage = _safeCurrentPage(logs);
    final int totalPages = _totalPages(logs);
    final List<SleepLog> pageLogs = _getCurrentPageLogs(logs);

    final int startDataNumber = logs.isEmpty ? 0 : safePage * _rowsPerPage + 1;
    final int endDataNumber = min((safePage + 1) * _rowsPerPage, logs.length);

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep Data', style: AppTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            'Showing $startDataNumber-$endDataNumber of ${logs.length} data.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.surfaceContainerHighest,
              ),
              dataRowColor: WidgetStateProperty.all(AppColors.surfaceLow),
              headingTextStyle: AppTextStyles.label.copyWith(
                color: AppColors.primaryFixedDim,
              ),
              dataTextStyle: AppTextStyles.body,
              columnSpacing: 28,
              horizontalMargin: 16,
              dividerThickness: 0,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Duration')),
                DataColumn(label: Text('Score')),
                DataColumn(label: Text('Sleep')),
                DataColumn(label: Text('Wake')),
              ],
              rows: pageLogs.map((log) {
                final int score = _calculateSleepScore(log.durationMinutes);

                return DataRow(
                  cells: [
                    DataCell(Text(_formatDate(log.date))),
                    DataCell(Text(log.formattedDuration)),
                    DataCell(Text(score.toString())),
                    DataCell(Text(DateFormat('HH:mm').format(log.sleepTime))),
                    DataCell(Text(DateFormat('HH:mm').format(log.wakeTime))),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildPaginationControls(
            logs: logs,
            currentPage: safePage,
            totalPages: totalPages,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls({
    required List<SleepLog> logs,
    required int currentPage,
    required int totalPages,
  }) {
    final bool canPrevious = currentPage > 0;
    final bool canNext = currentPage < totalPages - 1;

    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 26,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: canPrevious ? () => _previousPage(logs) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primaryFixedDim,
            disabledColor: AppColors.onSurfaceMuted,
          ),
          Expanded(
            child: Text(
              'Page ${currentPage + 1} of $totalPages\n10 data per page',
              style: AppTextStyles.small,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: canNext ? () => _nextPage(logs) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.primaryFixedDim,
            disabledColor: AppColors.onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _SleepDurationChart extends StatelessWidget {
  final List<SleepLog> logs;
  final String Function(DateTime date) formatChartDate;

  const _SleepDurationChart({
    required this.logs,
    required this.formatChartDate,
  });

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = [];

    for (int index = 0; index < logs.length; index++) {
      final SleepLog log = logs[index];
      final double durationHours = log.durationMinutes / 60;

      spots.add(FlSpot(index.toDouble(), durationHours));
    }

    final double maxDuration = logs
        .map((log) => log.durationMinutes / 60)
        .fold<double>(0, max);

    final double maxY = maxDuration < 8 ? 10 : maxDuration + 2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.surfaceVariant.withOpacity(0.55),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: AppTextStyles.small,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: _getBottomInterval(logs.length),
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();

                if (index < 0 || index >= logs.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    formatChartDate(logs[index].date),
                    style: AppTextStyles.small,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 4,
            color: AppColors.tertiary,
            dotData: FlDotData(show: logs.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.tertiary.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }

  double _getBottomInterval(int itemCount) {
    if (itemCount <= 7) {
      return 1;
    }

    return (itemCount / 5).ceilToDouble();
  }
}
