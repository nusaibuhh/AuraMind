import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sleep_log.dart';
import '../../providers/sleep_provider.dart';
import '../../providers/theme_provider.dart';

class LogSleepScreen extends StatefulWidget {
  const LogSleepScreen({super.key});

  @override
  State<LogSleepScreen> createState() => _LogSleepScreenState();
}

class _LogSleepScreenState extends State<LogSleepScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
        title: const Text('Log Sleep'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sleep Duration Section
            _SectionCard(
              icon: Icons.bedtime,
              iconColor: palette.primary,
              title: 'Sleep Duration',
              subtitle: 'How did you sleep last night?',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DurationPicker(
                        label: 'Hours',
                        value: sleepProvider.hours,
                        minValue: 0,
                        maxValue: 23,
                        onChanged: (val) =>
                            sleepProvider.setHours(val),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ':',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 12),
                      _DurationPicker(
                        label: 'Minutes',
                        value: sleepProvider.minutes,
                        minValue: 0,
                        maxValue: 59,
                        step: 5,
                        onChanged: (val) =>
                            sleepProvider.setMinutes(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total: ${sleepProvider.hours.toString().padLeft(2, '0')}:${sleepProvider.minutes.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sleep Quality Section
            _SectionCard(
              icon: Icons.star,
              iconColor: palette.primary,
              title: 'Sleep Quality',
              subtitle: 'How would you rate your sleep?',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: SleepQuality.values.map((quality) {
                  final isSelected = sleepProvider.quality == quality;
                  return _QualityButton(
                    emoji: _getQualityEmoji(quality),
                    label: _getQualityLabel(quality),
                    isSelected: isSelected,
                    color: palette.primary,
                    onTap: () => sleepProvider.setQuality(quality),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Post-Wake Feeling Section
            _SectionCard(
              icon: Icons.mood,
              iconColor: palette.primary,
              title: 'How do you feel after waking up?',
              child: Column(
                children: PostWakeFeeling.values.map((feeling) {
                  final isSelected =
                      sleepProvider.postWakeFeeling == feeling;
                  return _RadioTile(
                    title: _getPostWakeFeelingLabel(feeling),
                    selected: isSelected,
                    color: palette.primary,
                    onChanged: () =>
                        sleepProvider.setPostWakeFeeling(feeling),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Notes Section
            _SectionCard(
              icon: Icons.notes,
              iconColor: palette.primary,
              title: 'Notes (Optional)',
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 120,
                decoration: InputDecoration(
                  hintText: 'Write anything about your sleep...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: palette.surface,
                ),
                onChanged: (val) => sleepProvider.setNotes(val),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: sleepProvider.isLoading
                    ? null
                    : () async {
                        await sleepProvider.saveSleepLog();
                        if (!context.mounted) return;

                        if (sleepProvider.error != null) {
                          // Save actually failed (e.g. network/auth error) —
                          // tell the user instead of pretending it worked.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Could not save sleep log: ${sleepProvider.error}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sleep logged successfully!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.onPrimary,
                ),
                child: sleepProvider.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Sleep Log',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  final String label;
  final int value;
  final int minValue;
  final int maxValue;
  final int step;
  final Function(int) onChanged;

  const _DurationPicker({
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            readOnly: true,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            controller: TextEditingController(
              text: value.toString().padLeft(2, '0'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: value > minValue
                    ? () => onChanged(value - step)
                    : null,
                icon: const Icon(Icons.remove),
                constraints: const BoxConstraints(
                  minHeight: 32,
                  minWidth: 32,
                ),
              ),
              IconButton(
                onPressed: value < maxValue
                    ? () => onChanged(value + step)
                    : null,
                icon: const Icon(Icons.add),
                constraints: const BoxConstraints(
                  minHeight: 32,
                  minWidth: 32,
                ),
              ),
            ],
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _QualityButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _QualityButton({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? color : Colors.grey,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String title;
  final bool selected;
  final Color color;
  final VoidCallback onChanged;

  const _RadioTile({
    required this.title,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      leading: Radio(
        value: true,
        groupValue: selected,
        onChanged: (_) => onChanged(),
        activeColor: color,
      ),
    );
  }
}

// Helper functions
String _getQualityEmoji(SleepQuality quality) {
  switch (quality) {
    case SleepQuality.poor:
      return '😴';
    case SleepQuality.fair:
      return '😕';
    case SleepQuality.okay:
      return '😐';
    case SleepQuality.good:
      return '🙂';
    case SleepQuality.excellent:
      return '😄';
  }
}

String _getQualityLabel(SleepQuality quality) {
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

String _getPostWakeFeelingLabel(PostWakeFeeling feeling) {
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
