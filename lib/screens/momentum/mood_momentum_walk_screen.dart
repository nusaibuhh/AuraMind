import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/mood_momentum_provider.dart';
import '../../providers/theme_provider.dart';

class MoodMomentumWalkScreen extends StatefulWidget {
  const MoodMomentumWalkScreen({super.key});

  @override
  State<MoodMomentumWalkScreen> createState() => _MoodMomentumWalkScreenState();
}

class _MoodMomentumWalkScreenState extends State<MoodMomentumWalkScreen> {
  @override
  void dispose() {
    context.read<MoodMomentumProvider>().reset();
    super.dispose();
  }

  Future<void> _leave() async {
    final walk = context.read<MoodMomentumProvider>();
    if (walk.isRunning || walk.isPaused) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave your walk?'),
          content: const Text('Your current Mood Momentum Walk will be stopped.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    walk.reset();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final walk = context.watch<MoodMomentumProvider>();
    final palette = context.watch<AppThemeProvider>().palette;
    final theme = Theme.of(context);

    if (walk.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || walk.isCompleted == false) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('You did it!'),
            content: Text(
              'You completed your ${walk.config.minutes}-minute Mood Momentum Walk and took ${walk.steps} steps. Starting is progress, and every step counts.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  walk.reset();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.background, palette.background.withValues(alpha: 0.94)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _leave,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Mood Momentum Walk',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.directions_walk_rounded),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Column(
                    children: [
                      Text(
                        walk.isIdle
                            ? 'A small walk to help you create momentum.'
                            : walk.currentCue.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        walk.isIdle
                            ? 'Choose 5 or 10 minutes. There is no need to be perfect—just begin with the next step.'
                            : walk.currentCue.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.65), height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      _DurationPicker(walk: walk, accent: palette.primary),
                      const SizedBox(height: 30),
                      _StepProgressRing(walk: walk, accent: palette.primary),
                      const SizedBox(height: 18),
                      Text('Time remaining', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                      Text(
                        walk.formattedRemaining,
                        style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.favorite_outline_rounded, color: palette.primary),
                                const SizedBox(width: 8),
                                Text('Grounding cue', style: TextStyle(fontWeight: FontWeight.w800, color: palette.primary)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(walk.currentCue.message, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                      if (walk.sensorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          walk.sensorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: walk.isRunning
                              ? walk.pause
                              : walk.start,
                          icon: Icon(walk.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              walk.isRunning
                                  ? 'Pause walk'
                                  : walk.isPaused
                                      ? 'Resume walk'
                                      : 'Start ${walk.config.minutes}-minute walk',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      if (!walk.isIdle && !walk.isCompleted) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: walk.reset,
                          child: const Text('End session'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.walk, required this.accent});

  final MoodMomentumProvider walk;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final minutes in [5, 10]) ...[
          Expanded(
            child: InkWell(
              onTap: walk.isIdle ? () => walk.setDuration(minutes) : null,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: walk.config.minutes == minutes ? accent.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: walk.config.minutes == minutes ? accent : Colors.black.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Text('$minutes min', style: TextStyle(fontWeight: FontWeight.w900, color: accent)),
                    const SizedBox(height: 3),
                    Text('${minutes * 100} step goal', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          if (minutes == 5) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _StepProgressRing extends StatelessWidget {
  const _StepProgressRing({required this.walk, required this.accent});

  final MoodMomentumProvider walk;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: walk.stepProgress,
              strokeWidth: 14,
              backgroundColor: accent.withValues(alpha: 0.12),
              strokeCap: StrokeCap.round,
              color: accent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_walk_rounded, size: 34, color: accent),
              const SizedBox(height: 6),
              Text('${walk.steps}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
              Text('of ${walk.config.stepGoal} steps'),
              const SizedBox(height: 4),
              Text('${walk.percentComplete}% movement goal', style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
