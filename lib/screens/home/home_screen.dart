import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/best_self_vision.dart';
import '../../models/question.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../../providers/theme_provider.dart';
import '../checkin/intro_screen.dart';
import '../sleep/log_sleep_screen.dart';
import '../sleep/sleep_insights_screen.dart';
import '../sleep/sleep_history_screen.dart';
import '../breathing/breathing_screen.dart';
import '../grounding/grounding_screen.dart';
import '../community/community_forum_screen.dart';
import '../relaxation/muscle_relaxation_screen.dart';
import '../momentum/mood_momentum_walk_screen.dart';
import '../best_self/best_self_canvas_screen.dart';
import '../exercises/exercises_screen.dart';
import '../journal/journal_screen.dart';
import '../profile/profile_screen.dart';
import '../behavioral_activation/behavioral_activation_screen.dart';
import '../savoring/savoring_log_screen.dart';
import 'mood_analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<BestSelfVision> _bestPossibleSelves = [];

  @override
  void initState() {
    super.initState();
    _loadBestPossibleSelf();
  }

  Future<void> _loadBestPossibleSelf() async {
    try {
      final visions = await context.read<AuthProvider>().api.getBestSelfVisions();
      if (mounted) setState(() => _bestPossibleSelves = visions);
    } catch (_) {
      // A missing server should not stop the home screen from rendering.
    }
  }

  Future<void> _openBestPossibleSelf() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const BestSelfCanvasScreen(),
      ),
    );
    await _loadBestPossibleSelf();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _handleNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  List<({String title, String subtitle, IconData icon, Color color, VoidCallback onTap})> _recommendations(MentalHealthCategory category) {
    final grounding = (title: 'Grounding\n5-4-3-2-1', subtitle: 'Be present', icon: Icons.visibility_outlined, color: const Color(0xFF8A74B8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroundingScreen())));
    final breathing = (title: 'Breathing\nExercise', subtitle: '3 minutes', icon: Icons.air_rounded, color: const Color(0xFF6D8E71), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingScreen())));
    final bestSelf = (title: 'Best Possible\nSelf', subtitle: 'Future vision', icon: Icons.auto_awesome_rounded, color: const Color(0xFFD39B42), onTap: _openBestPossibleSelf);
    final walk = (title: 'Mood Momentum\nWalk', subtitle: '5–10 minutes', icon: Icons.directions_walk_rounded, color: const Color(0xFF507C67), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodMomentumWalkScreen())));
    final relaxation = (title: 'Muscle\nRelaxation', subtitle: 'Release tension', icon: Icons.self_improvement_rounded, color: const Color(0xFF694A70), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MuscleRelaxationScreen())));
    return switch (category) {
      MentalHealthCategory.depression => [walk, grounding, bestSelf],
      MentalHealthCategory.anxiety || MentalHealthCategory.stress => [grounding, breathing, relaxation],
      MentalHealthCategory.normal => [bestSelf, grounding, breathing],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.watch<AppThemeProvider>().palette;
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.name.split(' ').first ?? '';
    final recommended = _recommendations(context.watch<AppThemeProvider>().wellbeingCategory);

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
                        onProfileTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                      ),
                      const SizedBox(height: 18),
                      _ReminderCard(accent: theme.colorScheme.primary, text: "It's okay to take a break. You are still doing your best."),
                      const SizedBox(height: 18),
                      _BehavioralActivationCard(
                        accent: theme.colorScheme.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const BehavioralActivationScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _SavoringLogCard(
                        accent: theme.colorScheme.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SavoringLogScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _CommunityForumCard(
                        accent: theme.colorScheme.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CommunityForumScreen(),
                            ),
                          );
                        },
                      ),
                      if (_bestPossibleSelves.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _PinnedBestSelfCard(
                          vision: _bestPossibleSelves.first,
                          onTap: _openBestPossibleSelf,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _QuickCheckInCard(palette: palette, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntroScreen()))),
                      const SizedBox(height: 18),
                      const _SectionTitle(
                        title: 'Recommended exercises',
                        subtitle: 'Chosen for how you are feeling today',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < recommended.length; i++) ...[Expanded(child: _RecommendationTile(background: recommended[i].color.withValues(alpha: .17), icon: recommended[i].icon, iconColor: recommended[i].color, title: recommended[i].title, subtitle: recommended[i].subtitle, onTap: recommended[i].onTap)), if (i < recommended.length - 1) const SizedBox(width: 12)],
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
                          Expanded(
                            child: _RecommendationTile(
                              background: const Color(0xFFF0EBF8),
                              icon: Icons.local_florist_outlined,
                              iconColor: const Color(0xFF8A74B8),
                              title: 'Grounding\n5-4-3-2-1',
                              subtitle: 'Anxiety relief',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const GroundingScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.56),
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

class _PinnedBestSelfCard extends StatelessWidget {
  const _PinnedBestSelfCard({required this.vision, required this.onTap});

  final BestSelfVision vision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6EF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD8E6D7)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFDDEBDD),
              child: Icon(Icons.auto_awesome, color: Color(0xFF5E8C76)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pinned · Your Best Possible Self',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vision.vision.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.35, color: Color(0xFF42524B)),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'View your vision  ›',
                    style: TextStyle(color: Color(0xFF3D755E), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestSelfActions extends StatelessWidget {
  const _BestSelfActions({
    required this.count,
    required this.onViewAll,
    required this.onWriteNew,
  });

  final int count;
  final VoidCallback onViewAll;
  final VoidCallback onWriteNew;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.history, size: 18),
            label: Text('View all $count visions'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onWriteNew,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Write new'),
          ),
        ],
      );
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
                // Handle navigation for tabs
                if (index == 1) {
                  // Navigate to sleep tracking
                  _handleSleepNavigation(context);
                } else if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExercisesScreen(),
                    ),
                  );
                } else if (index == 3) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const JournalScreen(),
                    ),
                  );
                } else if (index == 4) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
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
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
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

class _MuscleRelaxationCard extends StatelessWidget {
  const _MuscleRelaxationCard({required this.onTap});

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
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A3150),
                Color(0xFF694A70),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A3150).withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.self_improvement_rounded,
                  color: Color(0xFFF1D6F4),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Muscle Relaxation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Audio-guided head-to-toe tense and release exercise.',
                      style: TextStyle(
                        color: Color(0xFFE1D4E3),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFFF1D6F4),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodMomentumCard extends StatelessWidget {
  const _MoodMomentumCard({required this.onTap});

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
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEAF3E8),
                Color(0xFFDCEBDD),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5F7F63).withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: Color(0xFF5F7F63),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood Momentum Walk',
                      style: TextStyle(
                        color: Color(0xFF193222),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A 5–10 minute walk to build positive momentum.',
                      style: TextStyle(
                        color: Color(0xFF5F6F63),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFF5F7F63),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityForumCard extends StatelessWidget {
  const _CommunityForumCard({
    required this.accent,
    required this.onTap,
  });

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
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFFF2EAFB),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2D4F2)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.forum_outlined, color: accent, size: 27),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anonymous Community',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Share and connect without exposing your identity.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF746A7A),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: Color(0xFF8C6AAF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BehavioralActivationCard extends StatelessWidget {
  const _BehavioralActivationCard({required this.accent, required this.onTap});

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
                const Color(0xFF6B8F71).withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: const Color(0xFF6B8F71).withValues(alpha: 0.12)),
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
                child: const Icon(Icons.wb_sunny_outlined,
                    color: Color(0xFF52875C), size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Tiny Step",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2923),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Behavioral Activation — One small action for today.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF5F7365),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF52875C),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavoringLogCard extends StatelessWidget {
  const _SavoringLogCard({required this.accent, required this.onTap});

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
                const Color(0xFFFFD98B).withValues(alpha: 0.34),
                Colors.white.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFD49A37).withValues(alpha: 0.16),
            ),
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
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFC88722),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Three Good Things',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF302719),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Notice three positive moments from today.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF74654C),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: accent,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
