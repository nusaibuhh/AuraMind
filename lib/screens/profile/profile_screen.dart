import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/consultation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../consultations/my_consultations_screen.dart';
import '../consultations/psychiatrist_list_screen.dart';
import '../home/mood_analytics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _emergency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _emergency = TextEditingController(text: user.emergencyContact ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsultationProvider>().loadBookings();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _emergency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final emergency = _emergency.text.trim();
    if (emergency.isNotEmpty && !emergency.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid emergency contact email'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final error = await context.read<AuthProvider>().updateProfile(
          name: _name.text,
          email: _email.text,
          emergencyContact: _emergency.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Profile saved')),
    );
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const CircleAvatar(
              radius: 36,
              child: Icon(Icons.person, size: 38),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emergency,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Emergency contact email',
                hintText: 'e.g. contact@example.com',
                helperText: 'Optional',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
            const SizedBox(height: 28),
            const Text(
              'Wellbeing',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
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
