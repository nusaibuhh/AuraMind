import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/breathing_session.dart';
import '../../providers/breathing_provider.dart';
import '../../providers/theme_provider.dart';
import 'breathing_history_screen.dart';
import 'widgets/breathing_visualizer.dart';
import 'widgets/session_complete_dialog.dart';
import 'widgets/sound_selector_sheet.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final breathing = context.read<BreathingProvider>();
      if (breathing.isCompleted) {
        breathing.reset();
      }
    });
  }

  void _showTechniquePicker(BuildContext context) {
    final breathing = context.read<BreathingProvider>();
    final palette = context.read<AppThemeProvider>().palette;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Breathing Techniques',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a breathing pattern designed for your wellness goal',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: BreathingTechnique.all.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tech = BreathingTechnique.all[index];
                    final isSelected = tech.id == breathing.technique.id;

                    return InkWell(
                      onTap: () {
                        breathing.setTechnique(tech);
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? palette.primary.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? palette.primary
                                : Colors.black.withValues(alpha: 0.06),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.primary
                                    : palette.background,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.spa_rounded,
                                color: isSelected ? Colors.white : palette.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        tech.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tech.subtitle,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: palette.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tech.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: palette.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breathing = context.watch<BreathingProvider>();
    final palette = context.watch<AppThemeProvider>().palette;
    final theme = Theme.of(context);

    // Listen for completion to automatically show dialog
    if (breathing.isCompleted && ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SessionCompleteDialog.show(context);
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
              colors: [
                palette.background,
                palette.background.withValues(alpha: 0.94),
              ],
            ),
          ),
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      onPressed: () async {
                        if (breathing.isRunning) {
                          final shouldExit = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Leave Exercise?'),
                              content: const Text(
                                'Your current breathing session is active. Are you sure you want to exit?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Stay'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Exit'),
                                ),
                              ],
                            ),
                          );
                          if (shouldExit == true) {
                            breathing.reset();
                            if (context.mounted) Navigator.of(context).pop();
                          }
                        } else {
                          breathing.reset();
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    // Technique Selector Pill
                    InkWell(
                      onTap: breathing.isRunning
                          ? null
                          : () => _showTechniquePicker(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: palette.primary.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.spa_rounded,
                              size: 16,
                              color: palette.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              breathing.technique.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // History Button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BreathingHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle & Rhythm Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  breathing.isRunning
                      ? breathing.currentPhase.instruction
                      : breathing.technique.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ),

              // Main Breathing Visualizer Center Stage
              const Expanded(
                child: BreathingVisualizer(),
              ),

              // Background Sound Quick Selector Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: () => SoundSelectorSheet.show(context),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
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
                        Text(
                          breathing.selectedSound.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                breathing.selectedSound.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                breathing.selectedSound.id == 'silent'
                                    ? 'Sound off'
                                    : 'Volume ${(breathing.soundVolume * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: palette.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Action Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _ControlBar(palette: palette),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final dynamic palette;

  const _ControlBar({required this.palette});

  @override
  Widget build(BuildContext context) {
    final breathing = context.watch<BreathingProvider>();

    if (breathing.isIdle) {
      return Row(
        children: [
          // Cycle Selector Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 18,
                  color: palette.primary,
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: breathing.targetCycles,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [3, 4, 5, 8, 10].map((c) {
                    return DropdownMenuItem<int>(
                      value: c,
                      child: Text(
                        '$c cycles',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) breathing.setTargetCycles(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Big Start Button
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => breathing.start(),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Start Exercise',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                  shadowColor: palette.primary.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (breathing.isRunning) {
      return Row(
        children: [
          // Pause Button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => breathing.pause(),
                icon: const Icon(Icons.pause_rounded, size: 26),
                label: const Text(
                  'Pause',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: palette.primary,
                  side: BorderSide(color: palette.primary, width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Stop / Finish Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: () => breathing.stop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE45D52),
                  side: BorderSide(
                    color: const Color(0xFFE45D52).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Icon(Icons.stop_rounded, size: 26),
              ),
            ),
          ),
        ],
      );
    } else {
      // Paused State
      return Row(
        children: [
          // Resume Button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => breathing.resume(),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Resume',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Complete / End Early Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: () => breathing.stop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: palette.primary,
                  side: BorderSide(color: palette.primary, width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Finish',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
}
