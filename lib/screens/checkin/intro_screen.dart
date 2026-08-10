import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/questionnaire_provider.dart';
import 'questionnaire_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final user = context.watch<AuthProvider>().user;
    final name = user?.name.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 112,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primary.withValues(alpha: 0.2),
                        const Color(0xFFDFF0DA),
                        const Color(0xFFF7FBF2),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 12,
                        top: 8,
                        child: Icon(
                          Icons.wb_sunny_rounded,
                          color: primary.withValues(alpha: 0.65),
                          size: 28,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: Icon(
                          Icons.water_drop_rounded,
                          color: primary.withValues(alpha: 0.35),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                _greeting(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Let's check in with how you're feeling today",
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 26),
              _InfoRowCard(
                icon: Icons.timer_outlined,
                text: 'Takes less than 1 minute',
                accentColor: primary,
              ),
              const SizedBox(height: 12),
              _InfoRowCard(
                icon: Icons.verified_user_outlined,
                text: 'Your responses are private and safe',
                accentColor: const Color(0xFF7CB27A),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<QuestionnaireProvider>().reset();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuestionnaireScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Start Check-in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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

class _InfoRowCard extends StatelessWidget {
  const _InfoRowCard({
    required this.icon,
    required this.text,
    required this.accentColor,
  });

  final IconData icon;
  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.5,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
