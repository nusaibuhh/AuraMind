import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/behavioral_activation.dart';
import '../../providers/behavioral_activation_provider.dart';
import '../../providers/theme_provider.dart';
import 'behavioral_activation_history_screen.dart';

class BehavioralActivationScreen extends StatefulWidget {
  const BehavioralActivationScreen({super.key});

  @override
  State<BehavioralActivationScreen> createState() =>
      _BehavioralActivationScreenState();
}

class _BehavioralActivationScreenState
    extends State<BehavioralActivationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BehavioralActivationProvider>();
      provider.loadToday();
      provider.loadStats();
    });
  }

  void _showMoodCheckInModal(BuildContext context) {
    int? selectedMood;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final palette = context.read<AppThemeProvider>().palette;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sentiment_satisfied_rounded,
                        color: palette.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nice work. You showed up for yourself today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF193222),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'How do you feel right now? (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(5, (index) {
                        final moodLevel = index + 1;
                        final isSelected = selectedMood == moodLevel;
                        final labels = [
                          'Difficult',
                          'Low',
                          'Neutral',
                          'Pleasant',
                          'Great'
                        ];
                        final icons = [
                          Icons.sentiment_very_dissatisfied_rounded,
                          Icons.sentiment_dissatisfied_rounded,
                          Icons.sentiment_neutral_rounded,
                          Icons.sentiment_satisfied_rounded,
                          Icons.sentiment_very_satisfied_rounded,
                        ];

                        return InkWell(
                          onTap: () {
                            setModalState(() => selectedMood = moodLevel);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 54,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.primary.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? palette.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icons[index],
                                  color: isSelected
                                      ? palette.primary
                                      : Colors.grey[600],
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  labels[index],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? palette.primary
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(modalCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Skip rating'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedMood == null || isSaving
                                ? null
                                : () async {
                                    setModalState(() => isSaving = true);
                                    final success = await context
                                        .read<BehavioralActivationProvider>()
                                        .submitMood(moodAfter: selectedMood);
                                    if (!modalCtx.mounted) return;
                                    Navigator.pop(modalCtx);
                                    if (!success && mounted) {
                                      final message = context
                                              .read<
                                                  BehavioralActivationProvider>()
                                              .error ??
                                          'Could not save your optional mood rating.';
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                        SnackBar(content: Text(message)),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'self-care':
        return Icons.spa_outlined;
      case 'physical':
        return Icons.directions_walk_rounded;
      case 'social':
        return Icons.chat_bubble_outline_rounded;
      case 'enjoyment':
        return Icons.music_note_rounded;
      case 'outdoor':
        return Icons.wb_sunny_outlined;
      case 'productivity':
        return Icons.checklist_rounded;
      case 'relaxation':
        return Icons.self_improvement_rounded;
      default:
        return Icons.local_florist_outlined;
    }
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
    final task = provider.todayTask;

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
          'Behavioral Activation',
          style: TextStyle(
            color: palette.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: palette.onBackground),
            tooltip: 'Activity History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BehavioralActivationHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  "Today's Tiny Step",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: palette.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'One small action is enough for today.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: palette.onBackground.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 22),

                // Main Task Area
                if (provider.isTodayLoading && task == null) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (provider.error != null && task == null) ...[
                  _buildErrorCard(context, provider.error!, palette),
                ] else if (task != null) ...[
                  _buildTaskCard(context, task, provider, palette),
                  if (provider.error != null) ...[
                    const SizedBox(height: 12),
                    _buildInlineError(provider.error!, palette),
                  ],
                ] else ...[
                  _buildEmptyCard(
                    context,
                    palette,
                    noActivitiesAvailable: provider.hasNoAvailableActivities,
                  ),
                ],

                const SizedBox(height: 28),

                // Weekly progress summary
                _buildStatsSection(context, provider, palette),

                const SizedBox(height: 20),

                // Gentle wellbeing reminder
                _buildSupportCard(palette),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    BehavioralDailyTask task,
    BehavioralActivationProvider provider,
    dynamic palette,
  ) {
    final catColor = _getCategoryColor(task.activity.category);
    final catIcon = _getCategoryIcon(task.activity.category);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: task.isCompleted
              ? const Color(0xFF6B8F71).withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Chip & Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(catIcon, size: 16, color: catColor),
                    const SizedBox(width: 6),
                    Text(
                      task.activity.category,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '~${task.activity.durationMinutes} min',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Title
          Text(
            task.activity.title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2923),
              height: 1.25,
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Text(
            task.activity.description,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),

          const SizedBox(height: 24),

          // Status & Actions
          if (task.isCompleted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF6B8F71).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF52875C), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Completed for today',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C5E36),
                    ),
                  ),
                  if (task.moodAfter != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Mood: ${task.moodAfter}/5',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (task.isSkipped) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF4ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE8A838).withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle_outline_rounded,
                      color: Color(0xFFC7831C), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Resting today — that is completely okay.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A590F),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Pending task actions
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.isActionLoading
                        ? null
                        : () async {
                            final success = await provider.completeTask();
                            if (success && context.mounted) {
                              _showMoodCheckInModal(context);
                            } else if (context.mounted &&
                                provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(provider.error!)),
                              );
                            }
                          },
                    icon: provider.isActionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: provider.isActionLoading
                            ? null
                            : () async {
                                final success = await provider.changeTask();
                                if (!success &&
                                    context.mounted &&
                                    provider.error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(provider.error!)),
                                  );
                                }
                              },
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Change Activity'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black.withValues(alpha: 0.65),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: provider.isActionLoading
                            ? null
                            : () async {
                                final success = await provider.skipTask();
                                if (!success &&
                                    context.mounted &&
                                    provider.error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(provider.error!)),
                                  );
                                }
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Skip for today'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    BehavioralActivationProvider provider,
    dynamic palette,
  ) {
    final stats = provider.stats;
    final activeDays = stats?.numberOfActiveDays ?? 0;
    final completedCount = stats?.completedCount ?? 0;
    final rate = stats?.completionRate ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Weekly Rhythm',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2923),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BehavioralActivationHistoryScreen(),
                  ),
                );
              },
              child: Text(
                'View history',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: palette.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                title: 'This Week',
                value: '$completedCount / 7',
                subtitle: 'days active',
                icon: Icons.calendar_today_rounded,
                color: const Color(0xFF5A87B3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatTile(
                title: 'Completion',
                value: '${rate.toInt()}%',
                subtitle: 'rate',
                icon: Icons.pie_chart_outline_rounded,
                color: const Color(0xFF6D8E71),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatTile(
                title: 'Active Days',
                value: '$activeDays',
                subtitle: 'this week',
                icon: Icons.eco_outlined,
                color: const Color(0xFFE8A838),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2923),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(dynamic palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: palette.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tiny positive actions can gently interrupt a period of inactivity. Choose only what feels manageable; skipping is always okay.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: palette.onBackground.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error, dynamic palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Unable to connect to planner',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () =>
                context.read<BehavioralActivationProvider>().loadToday(),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String error, dynamic palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFE8A838).withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFC7831C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF805D31)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(
    BuildContext context,
    dynamic palette, {
    required bool noActivitiesAvailable,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.local_florist_outlined, color: palette.primary, size: 40),
          const SizedBox(height: 12),
          Text(
            noActivitiesAvailable
                ? 'No tiny steps available'
                : 'Ready for your first tiny step',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noActivitiesAvailable
                ? 'No tiny steps are available right now. Please check again later.'
                : 'Tap below to receive today’s positive action.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                context.read<BehavioralActivationProvider>().loadToday(),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              noActivitiesAvailable ? 'Check again' : 'Get Today’s Action',
            ),
          ),
        ],
      ),
    );
  }
}
