import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/breathing_session.dart';
import '../../providers/breathing_provider.dart';
import '../../providers/theme_provider.dart';

class BreathingHistoryScreen extends StatefulWidget {
  const BreathingHistoryScreen({super.key});

  @override
  State<BreathingHistoryScreen> createState() => _BreathingHistoryScreenState();
}

class _BreathingHistoryScreenState extends State<BreathingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final breathing = context.read<BreathingProvider>();
      breathing.fetchHistory();
      breathing.fetchMetrics();
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Today at $hour:$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m min ${s > 0 ? '$s s' : ''}';
    }
    return '$s sec';
  }

  @override
  Widget build(BuildContext context) {
    final breathing = context.watch<BreathingProvider>();
    final palette = context.watch<AppThemeProvider>().palette;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Breathing History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: breathing.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await breathing.fetchHistory();
                  await breathing.fetchMetrics();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Metrics Banner
                      if (breathing.metrics != null) ...[
                        _MetricsOverviewBanner(
                          metrics: breathing.metrics!,
                          palette: palette,
                        ),
                        const SizedBox(height: 20),
                      ],

                      Text(
                        'Past Sessions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (breathing.history.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.spa_outlined,
                                size: 52,
                                color: palette.primary.withValues(alpha: 0.45),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No breathing sessions yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Start a mindful breathing exercise to begin tracking your calm moments.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: breathing.history.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final session = breathing.history[index];
                            return _SessionHistoryCard(
                              session: session,
                              palette: palette,
                              formattedDate: _formatDate(session.createdAt),
                              formattedDuration:
                                  _formatDuration(session.durationSeconds),
                              onDelete: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Session'),
                                    content: const Text(
                                      'Are you sure you want to delete this breathing log?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await breathing.deleteSession(session.id);
                                }
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _MetricsOverviewBanner extends StatelessWidget {
  final BreathingMetrics metrics;
  final dynamic palette;

  const _MetricsOverviewBanner({
    required this.metrics,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: palette.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Practice Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'Total Minutes',
                  value: '${metrics.totalMinutes.toStringAsFixed(1)}m',
                  icon: Icons.timer_outlined,
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  title: 'Sessions',
                  value: '${metrics.totalSessions}',
                  icon: Icons.spa_outlined,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  title: 'Cycles',
                  value: '${metrics.totalCycles}',
                  icon: Icons.repeat_rounded,
                  color: const Color(0xFF6B8F71),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  final BreathingSession session;
  final dynamic palette;
  final String formattedDate;
  final String formattedDuration;
  final VoidCallback onDelete;

  const _SessionHistoryCard({
    required this.session,
    required this.palette,
    required this.formattedDate,
    required this.formattedDuration,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.spa_rounded,
              color: palette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      session.technique,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 14,
                          color: palette.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${session.cyclesCompleted} cycles',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (session.moodAfter != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Felt: ${session.moodAfter}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
