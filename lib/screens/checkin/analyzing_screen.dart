import 'dart:async';

import 'package:flutter/material.dart';
import 'theme_selection_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ThemeSelectionScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF4AA564);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2E5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.eco_rounded,
                    size: 58,
                    color: primary.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  'Analyzing your\nresponses.....',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Finding the best environment for you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _dotController,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final delay = index * 0.28;
                        final value = (_dotController.value + delay) % 1.0;
                        final opacity = (value < 0.5)
                            ? 0.32 + (value * 1.3)
                            : 1.25 - (value * 1.3);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: primary.withValues(
                              alpha: opacity.clamp(0.3, 1.0),
                            ),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
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
