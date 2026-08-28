import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
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
  }

  @override
  void dispose() { _name.dispose(); _email.dispose(); _emergency.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await context.read<AuthProvider>().updateProfile(
      name: _name.text, email: _email.text, emergencyContact: _emergency.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Profile saved')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 38)), const SizedBox(height: 22),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
      const SizedBox(height: 14), TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
      const SizedBox(height: 14), TextField(controller: _emergency, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Emergency contact number', helperText: 'Optional')),
      const SizedBox(height: 20), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save changes')),
      const SizedBox(height: 28), const Text('Wellbeing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8), Card(child: ListTile(leading: const Icon(Icons.insights_rounded), title: const Text('Mood Insights'), subtitle: const Text('View your 7, 30 and 90-day trends'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodAnalyticsScreen())))),
    ]),
  );
}
