import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _emergency;
  late final TextEditingController _currentPassword;
  late final TextEditingController _newPassword;
  late final TextEditingController _confirmPassword;
  bool _savingProfile = false;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _emergency = TextEditingController(text: user.emergencyContact ?? '');
    _currentPassword = TextEditingController();
    _newPassword = TextEditingController();
    _confirmPassword = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _emergency.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final emergency = _emergency.text.trim();
    if (emergency.isEmpty ||
        !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(emergency)) {
      _show('A valid emergency contact email is required');
      return;
    }
    setState(() => _savingProfile = true);
    final error = await context.read<AuthProvider>().updateProfile(
          name: _name.text,
          email: _email.text,
          emergencyContact: emergency,
        );
    if (!mounted) return;
    setState(() => _savingProfile = false);
    _show(error ?? 'Profile saved');
  }

  Future<void> _changePassword() async {
    if (_newPassword.text.length < 6) {
      _show('New password must be at least 6 characters');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _show('New passwords do not match');
      return;
    }
    setState(() => _changingPassword = true);
    final error = await context.read<AuthProvider>().changePassword(
          currentPassword: _currentPassword.text,
          newPassword: _newPassword.text,
        );
    if (!mounted) return;
    setState(() => _changingPassword = false);
    if (error == null) {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    }
    _show(error ?? 'Password changed');
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Edit profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 14),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 14),
            TextField(
              controller: _emergency,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Emergency contact email *',
                hintText: 'e.g. contact@example.com',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: _savingProfile ? null : _saveProfile,
                child: Text(_savingProfile ? 'Saving...' : 'Save profile')),
            const SizedBox(height: 32),
            const Text('Change password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
                controller: _currentPassword,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current password')),
            const SizedBox(height: 14),
            TextField(
                controller: _newPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password')),
            const SizedBox(height: 14),
            TextField(
                controller: _confirmPassword,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password')),
            const SizedBox(height: 18),
            FilledButton.tonal(
                onPressed: _changingPassword ? null : _changePassword,
                child: Text(
                    _changingPassword ? 'Changing...' : 'Change password')),
          ],
        ),
      );
}
