import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/consultation.dart';
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
        context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.read<AppThemeProvider>().resetCheckIn();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _changeTheme() async {
    final palette = await showModalBottomSheet<ThemePalette>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('Choose a theme',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...allThemePalettes.map((item) => ListTile(
                leading: CircleAvatar(backgroundColor: item.primary),
                title: Text(item.name),
                subtitle: Text(item.category.name),
                trailing: item.id == context.read<AppThemeProvider>().palette.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, item),
              )),
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const CircleAvatar(
              radius: 36,
              child: Icon(Icons.person, size: 38),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
            ),
            const SizedBox(height: 22),
            const Text(
              'Wellbeing',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Change theme'),
                subtitle: const Text('Choose from all available themes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changeTheme,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.insights_rounded),
                title: const Text('Mood Insights'),
                subtitle: const Text('View your 7, 30 and 90-day trends'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MoodAnalyticsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_searching_rounded),
                title: const Text('Find a practitioner near me'),
                subtitle:
                    const Text('Explore nearby mental-health practitioners'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PractitionerFinderScreen()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Consultation activity',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.medical_services_outlined),
                title: const Text('View Psychiatrists'),
                subtitle: const Text(
                  'See qualifications, chambers, fees and free slots',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openPsychiatrists,
              ),
            ),
            Consumer<ConsultationProvider>(
              builder: (context, consultations, _) {
                if (consultations.bookings.isEmpty) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('My consultation bookings'),
                      subtitle: Text(
                        consultations.error ?? 'No consultation booked yet',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openMyConsultations,
                    ),
                  );
                }
                return Column(
                  children: [
                    ...consultations.bookings.take(2).map(
                          (booking) => _ProfileBookingTile(
                            booking: booking,
                            onTap: _openMyConsultations,
                          ),
                        ),
                    TextButton.icon(
                      onPressed: _openMyConsultations,
                      icon: const Icon(Icons.event_note_rounded),
                      label: const Text('View all consultation bookings'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _ProfileBookingTile extends StatelessWidget {
  const _ProfileBookingTile({required this.booking, required this.onTap});

  final ConsultationBooking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = booking.slot.startsAt;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final paymentText = booking.isPaid ? 'Paid' : 'Payment due';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            booking.isPaid ? Icons.verified_rounded : Icons.schedule_rounded,
          ),
        ),
        title: Text(booking.practitionerName),
        subtitle: Text(
          '${date.day}/${date.month}/${date.year} · '
          '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'} · $paymentText',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
