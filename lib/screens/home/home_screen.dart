import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../../providers/theme_provider.dart';
import '../checkin/intro_screen.dart';
import '../sleep/log_sleep_screen.dart';
import '../sleep/sleep_insights_screen.dart';
import '../sleep/sleep_history_screen.dart';
import '../breathing/breathing_screen.dart';
import 'mood_analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _handleNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.watch<AppThemeProvider>().palette;
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.name.split(' ').first ?? '';

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
                palette.background.withValues(alpha: 0.96),
              ],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopHeader(
                        greeting: _greeting(),
                        name: firstName,
                        accent: theme.colorScheme.primary,
                        onProfileTap: () {
                          // Show profile dialog with actual user name and logout option
                          final auth = context.read<AuthProvider>();
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(auth.user?.name ?? 'Profile'),
                              content: const Text('View your profile information.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    auth.logout();
                                    context.read<AppThemeProvider>().resetCheckIn();
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (_) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  },
                                  child: const Text('Log out'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _QuickCheckInCard(
                        palette: palette,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const IntroScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _MoodInsightsCard(
                        accent: theme.colorScheme.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MoodAnalyticsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      const _SectionTitle(
                        title: 'Recommended for you',
                        subtitle: 'Small actions to keep your day steady',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RecommendationTile(
                              background: const Color(0xFFEAF3E8),
                              icon: Icons.spa_outlined,
                              iconColor: const Color(0xFF6D8E71),
                              title: 'Breathing\nExercise',
                              subtitle: '3 min',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const BreathingScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: _RecommendationTile(
                              background: Color(0xFFEAF2FB),
                              icon: Icons.menu_book_outlined,
                              iconColor: Color(0xFF5A87B3),
                              title: 'Journal',
                              subtitle: 'Write your\nthoughts',
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: _RecommendationTile(
                              background: Color(0xFFF0EBF8),
                              icon: Icons.local_florist_outlined,
                              iconColor: Color(0xFF8A74B8),
                              title: 'Grounding\n5-4-3-2-1',
                              subtitle: 'Anxiety relief',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _DailyReflectionCard(
                        accent: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      const _SectionTitle(
                        title: "Today's reminder",
                        subtitle: 'A small note for your attention',
                      ),
                      const SizedBox(height: 12),
                      _ReminderCard(
                        accent: theme.colorScheme.primary,
                        text:
                            "It's okay to take a break. You are still doing your best.",
                      ),
                    ],
                  ),
                ),
              ),
              _BottomNavBar(
                selectedIndex: _selectedIndex,
                onTap: _handleNavTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.greeting,
    required this.name,
    required this.accent,
    required this.onProfileTap,
  });

  final String greeting;
  final String name;
  final Color accent;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 16,
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
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How are you feeling today?',
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            _CircleIconButton(
              icon: Icons.person_rounded,
              background: const Color(0xFFE8F0E2),
              iconColor: const Color(0xFF5F7F63),
              onTap: onProfileTap,
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  background: const Color(0xFFF3F5EF),
                  iconColor: accent,
                  onTap: () {},
                ),
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE45D52),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _CircleIconButton(
                  icon: Icons.logout_rounded,
                  background: const Color(0xFFF8EDEB),
                  iconColor: const Color(0xFFE45D52),
                  onTap: () {
                    // immediate logout and navigate to login
                    final auth = context.read<AuthProvider>();
                    auth.logout();
                    context.read<AppThemeProvider>().resetCheckIn();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCheckInCard extends StatelessWidget {
  const _QuickCheckInCard({required this.palette, required this.onTap});

  final dynamic palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Check-in',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How are you feeling right now?',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sentiment_satisfied_alt_rounded,
                  color: palette.primary,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final Color background;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodInsightsCard extends StatelessWidget {
  const _MoodInsightsCard({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.insights_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood Insights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF193222),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Track your 7, 30 and 90-day emotional trends.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF6D7B72),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyReflectionCard extends StatelessWidget {
  const _DailyReflectionCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Daily Reflection',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take a moment to reflect on your day.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 122,
              height: 94,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.12),
                    const Color(0xFFE5EFE0),
                    const Color(0xFFF7FAF3),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Icon(
                      Icons.terrain_rounded,
                      size: 46,
                      color: accent.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 14,
                    child: Icon(
                      Icons.terrain_rounded,
                      size: 40,
                      color: accent.withValues(alpha: 0.12),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: accent,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.accent, required this.text});

  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 34,
            color: accent.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.favorite_border_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.bedtime_rounded, 'Sleep'),
      (Icons.spa_outlined, 'Exercises'),
      (Icons.menu_book_outlined, 'Journal'),
      (Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == selectedIndex;
          final color = selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.45);

          return Expanded(
            child: InkWell(
              onTap: () {
                onTap(index);
                // Handle navigation for sleep tab
                if (index == 1) {
                  // Navigate to sleep tracking
                  _handleSleepNavigation(context);
                } else if (index == 2) {
                  // Navigate to breathing exercise
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BreathingScreen(),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$1, color: color),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _handleSleepNavigation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Sleep Tracking',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Log Sleep'),
                subtitle: const Text('Record your sleep duration and quality'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LogSleepScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.insights),
                title: const Text('Sleep & Mood Insights'),
                subtitle: const Text('View your sleep patterns and wellness'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SleepInsightsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Sleep History'),
                subtitle: const Text('View all your past sleep logs'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SleepHistoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
