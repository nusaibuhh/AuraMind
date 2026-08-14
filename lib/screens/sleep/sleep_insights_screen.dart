import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sleep_log.dart';
import '../../models/theme_palette.dart';
import '../../providers/sleep_provider.dart';
import '../../providers/theme_provider.dart';

class SleepInsightsScreen extends StatefulWidget {
  const SleepInsightsScreen({super.key});

  @override
  State<SleepInsightsScreen> createState() => _SleepInsightsScreenState();
}

class _SleepInsightsScreenState extends State<SleepInsightsScreen> {
  int _selectedDays = 7;  // Default to 7 days instead of 30

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<SleepProvider>();
    await Future.wait([
      provider.fetchMetrics(days: _selectedDays),
      provider.fetchCorrelations(days: _selectedDays),
      provider.fetchWarnings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<AppThemeProvider>().palette;
    final sleepProvider = context.watch<SleepProvider>();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        title: const Text('Sleep & Mood Insights'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            _PeriodSelector(
              selectedDays: _selectedDays,
              onChanged: (days) {
                setState(() => _selectedDays = days);
                _loadData();
              },
              color: palette.primary,
            ),
            const SizedBox(height: 16),

            // Wellbeing Warnings
            if (sleepProvider.warnings.isNotEmpty)
              _WarningsSection(
                warnings: sleepProvider.warnings,
                onDismiss: (id) => sleepProvider.dismissWarning(id),
                palette: palette,
              ),

            // Your Wellbeing Section
            if (sleepProvider.metrics != null) ...[
              const SizedBox(height: 16),
              _WellbeingSection(
                metrics: sleepProvider.metrics!,
                correlations: sleepProvider.correlations,
                palette: palette,
              ),
            ],

            // Correlation Chart
            if (sleepProvider.correlations != null &&
                sleepProvider.correlations!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CorrelationChart(
                correlations: sleepProvider.correlations!,
                palette: palette,
              ),
            ],

            // Loading State
            if (sleepProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // Error State
            if (sleepProvider.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: ${sleepProvider.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets

class _PeriodSelector extends StatelessWidget {
  final int selectedDays;
  final Function(int) onChanged;
  final Color color;

  const _PeriodSelector({
    required this.selectedDays,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 Days')),
              ButtonSegment(value: 30, label: Text('30 Days')),
            ],
            selected: {selectedDays},
            onSelectionChanged: (selected) => onChanged(selected.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                return states.contains(WidgetState.selected)
                    ? color
                    : Colors.grey.shade200;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.grey.shade700;
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _WarningsSection extends StatelessWidget {
  final List<WellbeingWarning> warnings;
  final Function(String) onDismiss;
  final ThemePalette palette;

  const _WarningsSection({
    required this.warnings,
    required this.onDismiss,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text(
              'Wellbeing Check',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...warnings.map(
          (warning) => _WarningCard(
            warning: warning,
            onDismiss: () => onDismiss(warning.id),
          ),
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  final WellbeingWarning warning;
  final VoidCallback onDismiss;

  const _WarningCard({
    required this.warning,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    warning.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              warning.message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // TODO: Navigate to sleep tips
              },
              child: const Text(
                'View Sleep Tips →',
                style: TextStyle(
                  color: Color(0xFF5555FF),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellbeingSection extends StatelessWidget {
  final SleepMetrics metrics;
  final List<SleepMoodCorrelation>? correlations;
  final ThemePalette palette;

  const _WellbeingSection({
    required this.metrics,
    required this.correlations,
    required this.palette,
  });

  /// Splits the correlation series in half and returns (recentAvg, olderAvg)
  /// mood scores so we can show a real week-over-week trend instead of a
  /// hardcoded value.
  (double, double)? _moodHalves(List<SleepMoodCorrelation> data) {
    if (data.length < 2) return null;
    final recentCount = (data.length / 2).ceil();
    final older = data.sublist(0, data.length - recentCount);
    final recent = data.sublist(data.length - recentCount);
    final olderAvg = older.map((c) => c.moodScore).reduce((a, b) => a + b) / older.length;
    final recentAvg = recent.map((c) => c.moodScore).reduce((a, b) => a + b) / recent.length;
    return (recentAvg, olderAvg);
  }

  @override
  Widget build(BuildContext context) {
    final sleepTrend = metrics.getTrend();
    final sleepTrendText = sleepTrend > 0 ? '↑ ' : sleepTrend < 0 ? '↓ ' : '';
    final sleepTrendColor = sleepTrend > 0 ? Colors.green : sleepTrend < 0 ? Colors.red : Colors.grey;

    // Real mood data comes from mood check-ins (via /sleep/correlation),
    // not from sleep quality — those are two different things.
    final data = correlations ?? const <SleepMoodCorrelation>[];
    final hasMoodData = data.isNotEmpty;
    final halves = hasMoodData ? _moodHalves(data) : null;
    final avgMood = hasMoodData
        ? data.map((c) => c.moodScore).reduce((a, b) => a + b) / data.length
        : null;
    final moodDelta = halves != null ? halves.$1 - halves.$2 : 0.0;
    final moodTrendText = halves == null
        ? 'Not enough data'
        : moodDelta > 0
            ? '↑ ${moodDelta.toStringAsFixed(1)} from last period'
            : moodDelta < 0
                ? '↓ ${moodDelta.abs().toStringAsFixed(1)} from last period'
                : 'Stable';
    final moodTrendColor = halves == null
        ? Colors.grey
        : moodDelta > 0
            ? Colors.green
            : moodDelta < 0
                ? Colors.red
                : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Wellbeing',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Average Sleep',
                value: '${metrics.averageSleep.toStringAsFixed(1)}h',
                unit: '05m',
                trend: '${sleepTrendText}${(metrics.getTrend().abs()).toStringAsFixed(1)}h',
                trendColor: sleepTrendColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Average Mood',
                value: hasMoodData ? '${avgMood!.toStringAsFixed(1)}/10' : 'No check-ins yet',
                unit: hasMoodData ? 'from mood check-ins' : 'Log a mood check-in',
                trend: moodTrendText,
                trendColor: moodTrendColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String trend;
  final Color trendColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.trend,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: trendColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrelationChart extends StatelessWidget {
  final List<SleepMoodCorrelation> correlations;
  final ThemePalette palette;

  const _CorrelationChart({
    required this.correlations,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    if (correlations.isEmpty) return const SizedBox();

    final maxSleep =
        correlations.map((c) => c.sleepHours).reduce((a, b) => a > b ? a : b);
    const maxMood = 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sleep & Mood Correlation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Chart (simplified line chart visualization)
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      correlations: correlations,
                      maxSleep: maxSleep,
                      maxMood: maxMood,
                      sleepColor: palette.primary,
                      moodColor: palette.accent,
                    ),
                    size: const Size(double.infinity, 200),
                  ),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  children: [
                    _LegendItem(
                      label: 'Sleep (hours)',
                      color: palette.primary,
                    ),
                    const SizedBox(width: 24),
                    _LegendItem(
                      label: 'Mood (score)',
                      color: palette.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Correlation: Higher sleep correlates with better mood scores',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<SleepMoodCorrelation> correlations;
  final double maxSleep;
  final double maxMood;
  final Color sleepColor;
  final Color moodColor;

  _LineChartPainter({
    required this.correlations,
    required this.maxSleep,
    required this.maxMood,
    required this.sleepColor,
    required this.moodColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (correlations.isEmpty) return;

    const padding = 30.0;
    final chartWidth = size.width - (padding * 2);
    final chartHeight = size.height - (padding * 2);
    final stepX = chartWidth / (correlations.length - 1).clamp(1, double.infinity);

    // Draw sleep line
    final sleepPaint = Paint()
      ..color = sleepColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw mood line
    final moodPaint = Paint()
      ..color = moodColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Calculate points
    List<Offset> sleepPoints = [];
    List<Offset> moodPoints = [];

    for (int i = 0; i < correlations.length; i++) {
      final corr = correlations[i];
      final x = padding + (i * stepX);
      final sleepY =
          padding + (chartHeight * (1 - (corr.sleepHours / maxSleep)));
      final moodY = padding + (chartHeight * (1 - (corr.moodScore / maxMood)));

      sleepPoints.add(Offset(x, sleepY));
      moodPoints.add(Offset(x, moodY));
    }

    // Draw lines
    for (int i = 0; i < sleepPoints.length - 1; i++) {
      canvas.drawLine(sleepPoints[i], sleepPoints[i + 1], sleepPaint);
      canvas.drawLine(moodPoints[i], moodPoints[i + 1], moodPaint);
    }

    // Draw points
    final pointPaint = Paint()..strokeWidth = 4;
    for (final point in sleepPoints) {
      pointPaint.color = sleepColor;
      canvas.drawPoints(ui.PointMode.points, [point], pointPaint);
    }
    for (final point in moodPoints) {
      pointPaint.color = moodColor;
      canvas.drawPoints(ui.PointMode.points, [point], pointPaint);
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) => false;
}
