import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/breathing_session.dart';
import '../../../providers/breathing_provider.dart';
import '../../../providers/theme_provider.dart';

class BreathingVisualizer extends StatelessWidget {
  const BreathingVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    final breathing = context.watch<BreathingProvider>();
    final palette = context.watch<AppThemeProvider>().palette;

    // Calculate dynamic scale and phase animation
    final double targetScale;
    if (breathing.isIdle) {
      targetScale = 0.95;
    } else {
      switch (breathing.currentPhase) {
        case BreathPhase.inhale:
          // Inhale grows from 0.85 to 1.30
          targetScale = 0.85 + (0.45 * _easeInOutCubic(breathing.phaseProgress));
          break;
        case BreathPhase.holdIn:
          // Hold stays fully expanded with a subtle gentle pulse
          final pulse = math.sin(breathing.phaseProgress * math.pi) * 0.04;
          targetScale = 1.30 + pulse;
          break;
        case BreathPhase.exhale:
          // Exhale contracts from 1.30 to 0.85
          targetScale = 1.30 - (0.45 * _easeInOutCubic(breathing.phaseProgress));
          break;
        case BreathPhase.holdOut:
          // Hold out rests at contracted state with subtle pulse
          final pulse = math.sin(breathing.phaseProgress * math.pi) * 0.03;
          targetScale = 0.85 - pulse;
          break;
      }
    }

    final primaryColor = palette.primary;
    final accentColor = palette.accent;

    return Center(
      child: SizedBox(
        width: 320,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer subtle progress ring track
            CustomPaint(
              size: const Size(310, 310),
              painter: _ProgressRingPainter(
                progress: breathing.isIdle ? 0.0 : breathing.phaseProgress,
                trackColor: primaryColor.withValues(alpha: 0.12),
                progressColor: primaryColor,
              ),
            ),

            // Outermost pulsing glowing aura
            Transform.scale(
              scale: targetScale * 1.08,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.22),
                      primaryColor.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Mid glowing ripple ring
            Transform.scale(
              scale: targetScale * 1.03,
              child: Container(
                width: 215,
                height: 215,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.14),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
              ),
            ),

            // Inner main breathing orb
            Transform.scale(
              scale: targetScale,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      accentColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),

            // Central Content (Phase name, Countdown, Instructions)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (breathing.isIdle) ...[
                  const Icon(
                    Icons.spa_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ready?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap Start below',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ] else ...[
                  // Active Phase Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Text(
                      breathing.currentPhase.label,
                      key: ValueKey<BreathPhase>(breathing.currentPhase),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Countdown digits
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${breathing.phaseRemainingSeconds}s',
                      key: ValueKey<int>(breathing.phaseRemainingSeconds),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Cycle badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Cycle ${breathing.currentCycle} of ${breathing.targetCycles}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static double _easeInOutCubic(double x) {
    return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
