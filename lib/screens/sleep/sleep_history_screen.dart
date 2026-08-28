import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sleep_log.dart';
import '../../models/theme_palette.dart';
import '../../providers/sleep_provider.dart';
import '../../providers/theme_provider.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SleepProvider>().fetchSleepLogs(days: 30);
    });
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
        title: const Text('Sleep History'),
        elevation: 0,
      ),
      body: sleepProvider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: palette.primary),
            )
          : sleepProvider.error != null
              ? Center(
                  child: Text(
                    'Error: ${sleepProvider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : sleepProvider.sleepLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bedtime,
                            size: 64,
                            color: palette.primary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sleep logs recorded yet',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start logging your sleep to see your history',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sleepProvider.sleepLogs.length,
                  itemBuilder: (context, index) {
                    final log = sleepProvider.sleepLogs[index];
                    return _SleepLogCard(
                      log: log,
                      palette: palette,
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Sleep Log?'),
                            content: const Text(
                              'Are you sure you want to delete this sleep log? This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && context.mounted) {
                          await sleepProvider.deleteSleepLog(log.id);
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _SleepLogCard extends StatelessWidget {
  final SleepLog log;
  final ThemePalette palette;
  final VoidCallback onDelete;

  const _SleepLogCard({
    required this.log,
    required this.palette,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayName = _getDayName(log.date);
    final dateStr = _formatDate(log.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Day
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),

            // Sleep Duration
            _InfoRow(
              icon: Icons.schedule,
              label: 'Duration',
              value:
                  '${log.sleepHours}h ${log.sleepMinutes}m (${log.totalHours.toStringAsFixed(1)}h)',
              color: palette.primary,
            ),
            const SizedBox(height: 8),

            // Sleep Quality
            _InfoRow(
              icon: Icons.star,
              label: 'Quality',
              value: _getQualityLabelFromEnum(log.quality),
              color: _getQualityColorFromEnum(log.quality),
            ),
            const SizedBox(height: 8),

            // Post-Wake Feeling
            _InfoRow(
              icon: Icons.mood,
              label: 'Feeling',
              value: _getPostWakeFeelingLabelFromEnum(log.postWakeFeeling),
              color: palette.secondary,
            ),

            // Notes
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
        ),
      ],
    );
  }
}

// Helper functions
String _getDayName(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date).inDays;

  switch (difference) {
    case 0:
      return 'Today';
    case 1:
      return 'Yesterday';
    default:
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
  }
}

String _formatDate(DateTime date) {
  return '${date.day} ${_getMonth(date.month)} ${date.year}';
}

String _getMonth(int month) {
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
    'Dec'
  ];
  return months[month - 1];
}

String _getQualityLabel(int quality) {
  switch (quality) {
    case 0:
      return 'Poor';
    case 1:
      return 'Fair';
    case 2:
      return 'Okay';
    case 3:
      return 'Good';
    case 4:
      return 'Excellent';
    default:
      return 'Unknown';
  }
}

String _getQualityLabelFromEnum(SleepQuality quality) {
  switch (quality) {
    case SleepQuality.poor:
      return 'Poor';
    case SleepQuality.fair:
      return 'Fair';
    case SleepQuality.okay:
      return 'Okay';
    case SleepQuality.good:
      return 'Good';
    case SleepQuality.excellent:
      return 'Excellent';
  }
}

Color _getQualityColor(int quality) {
  switch (quality) {
    case 0:
      return Colors.red;
    case 1:
      return Colors.orange;
    case 2:
      return Colors.amber;
    case 3:
      return Colors.lightGreen;
    case 4:
      return Colors.green;
    default:
      return Colors.grey;
  }
}

Color _getQualityColorFromEnum(SleepQuality quality) {
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

String _getPostWakeFeelingLabel(int feeling) {
  switch (feeling) {
    case 0:
      return 'Tired';
    case 1:
      return 'Normal';
    case 2:
      return 'Refreshed';
    case 3:
      return 'Annoyed';
    default:
      return 'Unknown';
  }
}

String _getPostWakeFeelingLabelFromEnum(PostWakeFeeling feeling) {
  switch (feeling) {
    case PostWakeFeeling.tired:
      return 'Tired';
    case PostWakeFeeling.normal:
      return 'Normal';
    case PostWakeFeeling.refreshed:
      return 'Refreshed';
    case PostWakeFeeling.annoyed:
      return 'Annoyed';
  }
}
