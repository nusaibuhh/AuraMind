import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/breathing_provider.dart';
import '../../../providers/theme_provider.dart';

class SessionCompleteDialog extends StatefulWidget {
  const SessionCompleteDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SessionCompleteDialog(),
    );
  }

  @override
  State<SessionCompleteDialog> createState() => _SessionCompleteDialogState();
}

class _SessionCompleteDialogState extends State<SessionCompleteDialog> {
  String _selectedMood = 'Calmer 🧘';
  bool _isSaving = false;

  final List<String> _moods = [
    'Calmer 🧘',
    'Relaxed 🌿',
    'Refreshed ✨',
    'Grounded 🍃',
    'Focused 🎯',
    'Same 😐',
  ];

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m min ${s > 0 ? '$s sec' : ''}';
    }
    return '$s seconds';
  }

  @override
  Widget build(BuildContext context) {
    final breathing = context.watch<BreathingProvider>();
    final palette = context.watch<AppThemeProvider>().palette;
    final theme = Theme.of(context);

    final durationText = _formatDuration(
      breathing.elapsedSeconds > 0
          ? breathing.elapsedSeconds
          : breathing.currentCycle * breathing.technique.cycleDurationSeconds,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Check / Lotus badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 38,
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              'Peaceful Practice Complete',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You took time to nurture your mind and body.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),

            // Metrics Summary Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Duration',
                      value: durationText,
                      icon: Icons.timer_outlined,
                      color: palette.primary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Cycles',
                      value: '${breathing.currentCycle} / ${breathing.targetCycles}',
                      icon: Icons.repeat_rounded,
                      color: palette.primary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Technique',
                      value: breathing.technique.name,
                      icon: Icons.spa_outlined,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mood Reflection Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'How are you feeling right now?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Mood chips wrap
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moods.map((mood) {
                final isSelected = mood == _selectedMood;
                return ChoiceChip(
                  label: Text(mood),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMood = mood);
                    }
                  },
                  selectedColor: palette.primary,
                  backgroundColor: palette.background,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? palette.primary
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save & Finish button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        await breathing.saveSession(moodAfter: _selectedMood);
                        breathing.reset();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save & Finish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // Skip / Done without saving
            TextButton(
              onPressed: () {
                breathing.reset();
                Navigator.of(context).pop();
              },
              child: Text(
                'Done without saving',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
