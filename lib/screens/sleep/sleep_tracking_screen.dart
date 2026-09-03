import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sleep_log.dart';
import '../../providers/sleep_provider.dart';
import '../../providers/theme_provider.dart';
import 'log_sleep_screen.dart';

class SleepTrackingScreen extends StatefulWidget {
  const SleepTrackingScreen({super.key});

  @override
  State<SleepTrackingScreen> createState() => _SleepTrackingScreenState();
}

class _SleepTrackingScreenState extends State<SleepTrackingScreen> {
  int _selectedDays = 7;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final provider = context.read<SleepProvider>();
    await Future.wait([
      provider.fetchMetrics(days: _selectedDays),
      provider.fetchSleepLogs(days: _selectedDays),
      provider.fetchCorrelations(days: _selectedDays),
      provider.fetchWarnings(),
    ]);
  }

  Future<void> _logSleep() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogSleepScreen()),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<AppThemeProvider>().palette;
    final provider = context.watch<SleepProvider>();
    final entries = provider.metrics?.entries ?? provider.sleepLogs;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        title: const Text('Sleep Tracking'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logSleep,
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        tooltip: 'Log new sleep',
        child: const Icon(Icons.add),
      ),
      body: provider.isLoading && entries.isEmpty
          ? Center(child: CircularProgressIndicator(color: palette.primary))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                children: [
                  _SleepChart(
                    entries: entries,
                    color: palette.primary,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 Days')),
                      ButtonSegment(value: 30, label: Text('30 Days')),
                    ],
                    selected: {_selectedDays},
                    onSelectionChanged: (selected) {
                      setState(() => _selectedDays = selected.first);
                      _refresh();
                    },
                  ),
                  if (provider.warnings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _WarningsCard(warnings: provider.warnings),
                  ],
                  if (provider.metrics != null) ...[
                    const SizedBox(height: 16),
                    _WellbeingSummary(
                      metrics: provider.metrics!,
                      correlations: provider.correlations,
                    ),
                  ],
                  if (provider.correlations?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    _MoodCorrelationChart(
                      correlations: provider.correlations!,
                      color: palette.primary,
                      moodColor: palette.accent,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Sleep history',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (provider.error != null)
                    Text(provider.error!,
                        style: const TextStyle(color: Colors.red)),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                          child: Text(
                              'No sleep logged yet. Tap + to add your first night.')),
                    )
                  else
                    ...entries.map(
                      (log) => _HistoryRow(log: log, color: palette.primary),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.entries, required this.color});

  final List<SleepLog> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ordered = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep duration',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Sleep duration by night',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: ordered.isEmpty
                  ? const Center(
                      child: Text('Your sleep chart will appear here.'))
                  : CustomPaint(
                      painter: _SleepChartPainter(ordered, color),
                      child: const SizedBox.expand(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepChartPainter extends CustomPainter {
  _SleepChartPainter(this.entries, this.color);

  final List<SleepLog> entries;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(28, 10, size.width - 42, size.height - 35);
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = TextPainter(
        text: TextSpan(
            text: '${i * 4}h',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - 7));
    }
    final points = <Offset>[];
    for (var i = 0; i < entries.length; i++) {
      final x = entries.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (entries.length - 1);
      final hours = entries[i].totalHours.clamp(0.0, 12.0);
      final y = chart.bottom - chart.height * hours / 12;
      points.add(Offset(x, y));
      canvas.drawCircle(points.last, 4, Paint()..color = color);
      if (entries.length <= 10) {
        final label = TextPainter(
          text: TextSpan(
              text: '${entries[i].date.day}/${entries[i].date.month}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, chart.bottom + 8));
      }
    }
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SleepChartPainter oldDelegate) =>
      oldDelegate.entries != entries || oldDelegate.color != color;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.log, required this.color});

  final SleepLog log;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .14),
          child: Icon(Icons.bedtime_rounded, color: color),
        ),
        title: Text('${log.sleepHours}h ${log.sleepMinutes}m',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${log.date.day}/${log.date.month}/${log.date.year}  •  ${_qualityLabel(log.quality)} sleep'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (index) => Icon(
                  index < log.quality.index + 1
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 16,
                  color: _qualityColor(log.quality),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(_feelingLabel(log.postWakeFeeling)),
          ],
        ),
      ),
    );
  }

  String _qualityLabel(SleepQuality quality) =>
      quality.name[0].toUpperCase() + quality.name.substring(1);

  String _feelingLabel(PostWakeFeeling feeling) =>
      feeling.name[0].toUpperCase() + feeling.name.substring(1);

  Color _qualityColor(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.poor:
        return Colors.red;
      case SleepQuality.fair:
        return Colors.orange;
      case SleepQuality.okay:
        return Colors.amber;
      case SleepQuality.good:
        return Colors.lightGreen;
      case SleepQuality.excellent:
        return Colors.green;
    }
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<WellbeingWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Wellbeing Check',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ...warnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${warning.title}: ${warning.message}'),
                )),
          ],
        ),
      ),
    );
  }
}

class _WellbeingSummary extends StatelessWidget {
  const _WellbeingSummary({required this.metrics, required this.correlations});

  final SleepMetrics metrics;
  final List<SleepMoodCorrelation>? correlations;

  @override
  Widget build(BuildContext context) {
    final mood = correlations;
    final averageMood = mood == null || mood.isEmpty
        ? null
        : mood.map((item) => item.moodScore).reduce((a, b) => a + b) /
            mood.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Wellbeing',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _SummaryMetric(
                    label: 'Average Sleep',
                    value: '${metrics.averageSleep.toStringAsFixed(1)}h')),
            const SizedBox(width: 10),
            Expanded(
                child: _SummaryMetric(
                    label: 'Average Mood',
                    value: averageMood == null
                        ? 'No check-ins'
                        : '${averageMood.toStringAsFixed(1)}/10')),
          ],
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _MoodCorrelationChart extends StatelessWidget {
  const _MoodCorrelationChart(
      {required this.correlations,
      required this.color,
      required this.moodColor});
  final List<SleepMoodCorrelation> correlations;
  final Color color;
  final Color moodColor;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sleep and mood insights',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Compare recorded sleep hours with mood scores.'),
            const SizedBox(height: 12),
            SizedBox(
                height: 190,
                child: CustomPaint(
                    painter: _MoodChartPainter(correlations, color, moodColor),
                    child: const SizedBox.expand())),
            const SizedBox(height: 8),
            Wrap(spacing: 16, children: [
              _ChartLegend(label: 'Sleep hours', color: color),
              _ChartLegend(label: 'Mood score', color: moodColor),
            ]),
          ]),
        ),
      );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 5),
        Text(label)
      ]);
}

class _MoodChartPainter extends CustomPainter {
  _MoodChartPainter(this.data, this.sleepColor, this.moodColor);
  final List<SleepMoodCorrelation> data;
  final Color sleepColor;
  final Color moodColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const padding = 24.0;
    final width = size.width - padding * 2;
    final height = size.height - padding * 2;
    final step = width / (data.length - 1).clamp(1, double.infinity);
    final sleepPoints = <Offset>[];
    final moodPoints = <Offset>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final x = padding + index * step;
      sleepPoints.add(Offset(
          x, padding + height * (1 - (item.sleepHours / 12).clamp(0, 1))));
      moodPoints.add(Offset(
          x, padding + height * (1 - (item.moodScore / 10).clamp(0, 1))));
    }
    _drawSeries(canvas, sleepPoints, sleepColor);
    _drawSeries(canvas, moodPoints, moodColor);
  }

  void _drawSeries(Canvas canvas, List<Offset> points, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) path.lineTo(point.dx, point.dy);
    canvas.drawPath(path, paint);
    final dotPaint = Paint()..color = color;
    for (final point in points) canvas.drawCircle(point, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MoodChartPainter oldDelegate) =>
      oldDelegate.data != data;
}
