import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mood_analytics.dart';
import '../../providers/mood_analytics_provider.dart';

class MoodAnalyticsScreen extends StatefulWidget {
  const MoodAnalyticsScreen({super.key});

  @override
  State<MoodAnalyticsScreen> createState() => _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends State<MoodAnalyticsScreen> {
  int? _selectedPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MoodAnalyticsProvider>().load(days: 7);
    });
  }

  void _showExercise(BuildContext context, InterventionExercise exercise) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE4DE),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  exercise.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF193222),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  exercise.description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF66756B),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<MoodAnalyticsProvider>();
    final analytics = provider.analytics;
    final accent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mood Insights',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        color: accent,
        onRefresh: provider.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            const Text(
              'Your emotional journey',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Color(0xFF193222),
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'See how your wellbeing has changed over time.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 20),
            _PeriodSelector(
              selectedDays: provider.selectedDays,
              onSelected: (days) {
                setState(() => _selectedPoint = null);
                provider.load(days: days);
              },
            ),
            const SizedBox(height: 16),
            if (provider.isLoading && analytics == null)
              const SizedBox(
                height: 330,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && analytics == null)
              _ErrorCard(
                message: provider.error!,
                onRetry: () => provider.load(),
              )
            else if (analytics != null) ...[
              _SummaryCard(analytics: analytics, accent: accent),
              const SizedBox(height: 16),
              _ChartCard(
                analytics: analytics,
                selectedIndex: _selectedPoint,
                accent: accent,
                onPointSelected: (index) {
                  setState(() => _selectedPoint = index);
                },
              ),
              const SizedBox(height: 16),
              _TrendCard(analytics: analytics, accent: accent),
              const SizedBox(height: 16),
              _InterventionCard(
                analytics: analytics,
                accent: accent,
                onStart: () => _showExercise(
                  context,
                  analytics.intervention.exercise,
                ),
              ),
            ],
            if (provider.isLoading && analytics != null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selectedDays, required this.onSelected});

  final int selectedDays;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE4EAE4)),
      ),
      child: Row(
        children: [
          _item(7, '7 Days', accent),
          _item(30, '30 Days', accent),
          _item(90, '90 Days', accent),
        ],
      ),
    );
  }

  Widget _item(int days, String label, Color accent) {
    final selected = selectedDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(days),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF66756B),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.analytics, required this.accent});

  final MoodAnalytics analytics;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final score = analytics.latestScore;
    final scoreLabel = score >= 7.5
        ? 'Feeling steady'
        : score >= 5
            ? 'Room to recharge'
            : 'Needs more support';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.15),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current wellbeing',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B796F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  scoreLabel,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF193222),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${analytics.points.length} check-in${analytics.points.length == 1 ? '' : 's'} in ${analytics.periodDays} days',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A877F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.analytics,
    required this.selectedIndex,
    required this.accent,
    required this.onPointSelected,
  });

  final MoodAnalytics analytics;
  final int? selectedIndex;
  final Color accent;
  final ValueChanged<int> onPointSelected;

  @override
  Widget build(BuildContext context) {
    if (!analytics.hasData) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(Icons.insights_rounded, size: 42, color: Color(0xFF93A39A)),
            SizedBox(height: 12),
            Text(
              'Your mood journey starts here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Complete a few mood check-ins to see a personalized trend graph.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF718077)),
            ),
          ],
        ),
      );
    }

    final point = selectedIndex != null && selectedIndex! < analytics.points.length
        ? analytics.points[selectedIndex!]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mood trend',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (point != null)
                Text(
                  '${point.score.toStringAsFixed(1)} / 10',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            point == null
                ? 'Tap a point to inspect a check-in.'
                : _formatDate(point.timestamp),
            style: const TextStyle(fontSize: 12, color: Color(0xFF7B887F)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 235,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final left = 36.0;
                    final right = constraints.maxWidth - 14.0;
                    final usable = math.max(1.0, right - left);
                    final x = details.localPosition.dx.clamp(left, right).toDouble();
                    final fraction = (x - left) / usable;
                    final index = (fraction * (analytics.points.length - 1))
                        .round()
                        .clamp(0, analytics.points.length - 1)
                        .toInt();
                    onPointSelected(index);
                  },
                  child: CustomPaint(
                    painter: _MoodChartPainter(
                      points: analytics.points,
                      accent: accent,
                      selectedIndex: selectedIndex,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF9AA69E)),
              SizedBox(width: 4),
              Text(
                'Tap a point for details',
                style: TextStyle(fontSize: 11, color: Color(0xFF8A968E)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A193222),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      );

  static String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _MoodChartPainter extends CustomPainter {
  _MoodChartPainter({
    required this.points,
    required this.accent,
    required this.selectedIndex,
  });

  final List<MoodPoint> points;
  final Color accent;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const right = 14.0;
    const top = 10.0;
    const bottom = 30.0;
    final width = math.max(1.0, size.width - left - right);
    final height = math.max(1.0, size.height - top - bottom);

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDE9)
      ..strokeWidth = 1;

    final labelStyle = const TextStyle(
      color: Color(0xFF8A968E),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    for (final value in [0, 5, 10]) {
      final y = top + height - (value / 10) * height;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);
      _drawText(canvas, '$value', Offset(3, y - 7), labelStyle);
    }

    if (points.length == 1) {
      final p = _offsetFor(0, points[0].score, left, top, width, height);
      _drawPoint(canvas, p, accent, true);
      return;
    }

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final p = _offsetFor(i, points[i].score, left, top, width, height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fillPath.moveTo(p.dx, top + height);
        fillPath.lineTo(p.dx, p.dy);
      } else {
        final previous = _offsetFor(
          i - 1,
          points[i - 1].score,
          left,
          top,
          width,
          height,
        );
        final controlX = (previous.dx + p.dx) / 2;
        path.cubicTo(controlX, previous.dy, controlX, p.dy, p.dx, p.dy);
        fillPath.cubicTo(controlX, previous.dy, controlX, p.dy, p.dx, p.dy);
      }
    }

    final last = _offsetFor(
      points.length - 1,
      points.last.score,
      left,
      top,
      width,
      height,
    );
    fillPath.lineTo(last.dx, top + height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.20),
          accent.withValues(alpha: 0.015),
        ],
      ).createShader(Rect.fromLTWH(left, top, width, height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final p = _offsetFor(i, points[i].score, left, top, width, height);
      _drawPoint(canvas, p, accent, selectedIndex == i);
    }

    final first = points.first.timestamp;
    final lastDate = points.last.timestamp;
    _drawText(canvas, _shortDate(first), Offset(left, size.height - 18), labelStyle);
    final lastText = _shortDate(lastDate);
    final painter = TextPainter(
      text: TextSpan(text: lastText, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(size.width - right - painter.width, size.height - 18));
  }

  Offset _offsetFor(
    int index,
    double score,
    double left,
    double top,
    double width,
    double height,
  ) {
    final x = points.length <= 1
        ? left + width / 2
        : left + (index / (points.length - 1)) * width;
    final y = top + height - (score.clamp(0.0, 10.0).toDouble() / 10.0) * height;
    return Offset(x, y);
  }

  void _drawPoint(Canvas canvas, Offset point, Color color, bool selected) {
    final halo = Paint()..color = color.withValues(alpha: selected ? 0.18 : 0.10);
    canvas.drawCircle(point, selected ? 9 : 6, halo);
    final core = Paint()..color = Colors.white;
    canvas.drawCircle(point, selected ? 6 : 4, core);
    final dot = Paint()..color = color;
    canvas.drawCircle(point, selected ? 4 : 3, dot);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _shortDate(DateTime date) => '${date.day}/${date.month}';

  @override
  bool shouldRepaint(covariant _MoodChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.accent != accent;
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.analytics, required this.accent});

  final MoodAnalytics analytics;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDown = analytics.trendLabel == 'Declining';
    final isUp = analytics.trendLabel == 'Improving';
    final icon = isDown
        ? Icons.trending_down_rounded
        : isUp
            ? Icons.trending_up_rounded
            : Icons.trending_flat_rounded;
    final iconColor = isDown
        ? const Color(0xFFD9776B)
        : isUp
            ? accent
            : const Color(0xFF7A8A80);

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: iconColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Trend insight',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      analytics.trendLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  analytics.isDeclining
                      ? 'Your latest check-ins form a sustained downward trajectory. AuraMind has increased your support level.'
                      : analytics.trendLabel == 'Improving'
                          ? 'Your recent check-ins are moving in a positive direction. Keep the small routines that help you feel well.'
                          : 'Your recent check-ins are relatively steady. Keep checking in so AuraMind can spot meaningful changes early.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF6C7A71),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterventionCard extends StatelessWidget {
  const _InterventionCard({
    required this.analytics,
    required this.accent,
    required this.onStart,
  });

  final MoodAnalytics analytics;
  final Color accent;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final intervention = analytics.intervention;
    final tier = intervention.tier;
    final tierProgress = tier / 4;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF193222),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18193222),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your support plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Level $tier / 4',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: tierProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            intervention.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            intervention.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _iconFor(intervention.exercise.icon),
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggested next step',
                        style: TextStyle(
                          color: Color(0xFFB9C7BD),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        intervention.exercise.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onStart,
                  child: Text(
                    'View',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String icon) {
    switch (icon) {
      case 'spa':
        return Icons.spa_rounded;
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'support_agent':
        return Icons.support_agent_rounded;
      default:
        return Icons.self_improvement_rounded;
    }
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: Color(0xFF9AA69E)),
          const SizedBox(height: 12),
          const Text(
            'Could not load mood insights',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF718077)),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
