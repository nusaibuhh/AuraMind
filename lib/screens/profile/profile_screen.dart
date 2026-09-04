import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_palette.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';
import '../consultations/my_consultations_screen.dart';
import '../consultations/psychiatrist_list_screen.dart';
import '../home/mood_analytics_screen.dart';
import '../consultations/practitioner_finder_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsultationProvider>().loadBookings();
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openPsychiatrists() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PsychiatristListScreen()),
    );
    if (mounted) {
      context.read<ConsultationProvider>().loadBookings();
    }
  }

  Future<void> _openMyConsultations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyConsultationsScreen()),
    );
    if (mounted) {
      context.read<ConsultationProvider>().loadBookings();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out'),
        content: const Text('Are you sure you want to sign out of AuraMind?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.read<AppThemeProvider>().resetCheckIn();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _changeTheme() async {
    final currentPalette = context.read<AppThemeProvider>().palette;

    final palette = await showModalBottomSheet<ThemePalette>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'Choose Color Theme',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalize the look and feel of your app',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...allThemePalettes.map((item) {
            final isSelected = item.id == currentPalette.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? item.primary
                      : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: item.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, item),
              ),
            );
          }),
        ],
      ),
    );

    if (palette == null || !mounted) return;
    try {
      await context.read<AppThemeProvider>().changeTheme(
            palette,
            context.read<AuthProvider>().api,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change theme.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final currentPalette = context.watch<AppThemeProvider>().palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        children: [
          // User Information Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: currentPalette.primary.withValues(alpha: 0.15),
                    child: Text(
                      (user?.name.isNotEmpty == true)
                          ? user!.name[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: currentPalette.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User Profile',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (user?.emergencyContact != null &&
                            user!.emergencyContact!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.contact_emergency_rounded,
                                  size: 13, color: Colors.teal.shade700),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user.emergencyContact!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.teal.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Wellbeing Section
          _sectionTitle('Wellbeing & Personalization'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: currentPalette.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text('Change Theme Color',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    currentPalette.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _changeTheme,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: const Icon(Icons.insights_rounded, color: Colors.purple),
                  title: const Text('Mood Insights',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('View your 7, 30 and 90-day trends'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MoodAnalyticsScreen(),
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: const Icon(Icons.near_me_rounded, color: Colors.blue),
                  title: const Text('Find Nearby Practitioners',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Explore mental-health clinics nearby'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PractitionerFinderScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Consultations Section
          _sectionTitle('Consultations'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.medical_services_outlined,
                      color: Colors.teal),
                  title: const Text('View Psychiatrists',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Browse verified doctors and book slots'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openPsychiatrists,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Consumer<ConsultationProvider>(
                  builder: (context, consultations, _) {
                    final hasBookings = consultations.bookings.isNotEmpty;
                    return ListTile(
                      leading: const Icon(Icons.calendar_month_rounded,
                          color: Colors.indigo),
                      title: const Text('My Booked Appointments',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        hasBookings
                            ? '${consultations.bookings.length} booking(s)'
                            : (consultations.error ?? 'No bookings yet'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasBookings)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${consultations.bookings.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: _openMyConsultations,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account Settings Section
          _sectionTitle('Account'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Account Settings',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Edit profile and password'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openSettings,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.red.shade700),
                  title: Text(
                    'Log Out',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
