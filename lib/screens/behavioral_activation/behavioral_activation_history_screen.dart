import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/behavioral_activation.dart';
import '../../providers/behavioral_activation_provider.dart';
import '../../providers/theme_provider.dart';

class BehavioralActivationHistoryScreen extends StatefulWidget {
  const BehavioralActivationHistoryScreen({super.key});

  @override
  State<BehavioralActivationHistoryScreen> createState() =>
      _BehavioralActivationHistoryScreenState();
}

class _BehavioralActivationHistoryScreenState
    extends State<BehavioralActivationHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BehavioralActivationProvider>();
      Future.wait([
        provider.loadHistory(),
        provider.loadStats(days: 7),
      ]);
    });
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        final months = [
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
        return '${months[date.month - 1]} ${date.day}';
      }
    } catch (_) {}
    return dateStr;
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'self-care':
        return const Color(0xFF6B8F71);
      case 'physical':
        return const Color(0xFFE8786A);
      case 'social':
        return const Color(0xFF4A90D9);
      case 'enjoyment':
        return const Color(0xFFE8A838);
      case 'outdoor':
        return const Color(0xFF5CB8A8);
      case 'productivity':
        return const Color(0xFF9B8EC4);
      case 'relaxation':
        return const Color(0xFF7BA68C);
      default:
        return const Color(0xFF6B8F71);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<AppThemeProvider>().palette;
    final provider = context.watch<BehavioralActivationProvider>();
    final history = provider.history;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.onBackground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Activity History',
          style: TextStyle(
            color: palette.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              provider.loadHistory(),
              provider.loadStats(days: 7),
            ]);
          },
          child: provider.isHistoryLoading && history.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.error != null && history.isEmpty
                  ? _buildErrorState(provider.error!, palette)
                  : history.isEmpty
                      ? _buildEmptyState(palette)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          itemCount: history.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildHeaderSummary(
                                  provider.stats, palette);
                            }
                            final task = history[index - 1];
                            return _buildHistoryTile(task, palette);
                          },
                        ),
        ),
      ),
    );
  }

  Widget _buildHeaderSummary(
    BehavioralStats? stats,
    dynamic palette,
  ) {
    final completed = stats?.completedCount ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_available_rounded,
                color: palette.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This week: $completed of 7 days completed',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2923),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'A gentle record of the actions you chose to take.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(BehavioralDailyTask task, dynamic palette) {
    final catColor = _getCategoryColor(task.activity.category);
    final dateLabel = _formatDate(task.taskDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date badge
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  dateLabel.split(' ').first,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel.split(' ').length > 1
                      ? dateLabel.split(' ')[1]
                      : '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2923),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Task details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.activity.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2923),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.activity.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: catColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${task.activity.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                    if (task.moodAfter != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Mood: ${task.moodAfter}/5',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: task.isCompleted
                  ? const Color(0xFFE8F5E9)
                  : (task.isSkipped
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFECEFF1)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  task.isCompleted
                      ? Icons.check_rounded
                      : (task.isSkipped
                          ? Icons.pause_rounded
                          : Icons.hourglass_top_rounded),
                  size: 14,
                  color: task.isCompleted
                      ? const Color(0xFF2E7D32)
                      : (task.isSkipped
                          ? const Color(0xFFE65100)
                          : Colors.grey[700]),
                ),
                const SizedBox(width: 4),
                Text(
                  task.isCompleted
                      ? 'Done'
                      : (task.isSkipped ? 'Skipped' : 'Pending'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: task.isCompleted
                        ? const Color(0xFF2E7D32)
                        : (task.isSkipped
                            ? const Color(0xFFE65100)
                            : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: palette.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No activity history yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2923),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your first tiny step will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, dynamic palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Could not load activity history',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                final provider = context.read<BehavioralActivationProvider>();
                Future.wait([
                  provider.loadHistory(),
                  provider.loadStats(days: 7),
                ]);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
