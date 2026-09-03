import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class PractitionerDashboardScreen extends StatefulWidget {
  const PractitionerDashboardScreen(
      {super.key,
      this.initialEmail,
      this.initialPassword,
      this.initialLicense});

  final String? initialEmail;
  final String? initialPassword;
  final String? initialLicense;

  @override
  State<PractitionerDashboardScreen> createState() =>
      _PractitionerDashboardScreenState();
}

class _PractitionerDashboardScreenState
    extends State<PractitionerDashboardScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _license;
  final _newPassword = TextEditingController();
  final _minutes = TextEditingController(text: '30');
  final _fee = TextEditingController(text: '0');
  final _location = TextEditingController();
  final _contact = TextEditingController();
  final _qualifications = TextEditingController();
  final _specialty = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _slots = [];
  bool _loggedIn = false;
  bool _mustChangePassword = false;
  bool _busy = false;
  String? _error;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
    _password = TextEditingController(text: widget.initialPassword ?? '');
    _license = TextEditingController(text: widget.initialLicense ?? '');
    if (widget.initialEmail != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => _login());
  }

  @override
  void dispose() {
    for (final controller in [
      _email,
      _password,
      _license,
      _newPassword,
      _minutes,
      _fee,
      _location,
      _contact,
      _qualifications,
      _specialty,
      _start,
      _end
    ]) controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _license.text.trim().isEmpty) {
      setState(
          () => _error = 'Enter your email, password/OTP, and license number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.practitionerLogin(
          email: _email.text.trim(),
          password: _password.text,
          licenseNumber: _license.text.trim());
      _mustChangePassword = result['must_change_password'] as bool? ?? false;
      _loggedIn = true;
      await _loadProfile();
      await _loadBookings();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadBookings() async {
    final results = await Future.wait([
      _api.getPractitionerBookings(),
      _api.getPractitionerSlots(),
    ]);
    _bookings = results[0] as List<Map<String, dynamic>>;
    _slots = results[1] as List<Map<String, dynamic>>;
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.getPractitionerProfile();
      _minutes.text = '${profile['consultation_minutes'] ?? 30}';
      _fee.text = '${profile['fee_amount'] ?? 0}';
      _location.text = profile['chamber']?.toString() ?? '';
      _contact.text = profile['contact_no']?.toString() ?? '';
      _qualifications.text = profile['qualifications']?.toString() ?? '';
      _specialty.text = profile['specialty']?.toString() ?? '';
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword.text.length < 6) {
      _message('Password must be at least 6 characters.');
      return;
    }
    try {
      await _api.practitionerChangePassword(
          currentPassword: _password.text, newPassword: _newPassword.text);
      _password.text = _newPassword.text;
      _mustChangePassword = false;
      _message('Password updated.');
      setState(() {});
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _saveSetup() async {
    try {
      await _api.updatePractitionerProfile(
          consultationMinutes: int.tryParse(_minutes.text) ?? 30,
          feeAmount: double.tryParse(_fee.text) ?? 0,
          chamber: _location.text.trim(),
          contactNo: _contact.text.trim(),
          qualifications: _qualifications.text.trim(),
          specialty: _specialty.text.trim());
      _message('Profile settings saved.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _addSlot() async {
    final starts = DateTime.tryParse(_start.text.trim());
    final ends = DateTime.tryParse(_end.text.trim());
    if (starts == null || ends == null) {
      _message('Use date-time format YYYY-MM-DD HH:MM.');
      return;
    }
    try {
      await _api.addPractitionerSlot(startsAt: starts, endsAt: ends);
      await _loadBookings();
      _message('Slot added.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _action(String id, String action) async {
    try {
      await _api.practitionerBookingAction(id, action);
      await _loadBookings();
      _message(action == 'accept_cash'
          ? 'Appointment accepted with cash payment.'
          : 'Appointment updated.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return _loginView();
    return Scaffold(
      appBar: AppBar(title: const Text('Practitioner Dashboard'), actions: [
        IconButton(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'),
        IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out'),
      ]),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        if (_mustChangePassword) _setupPasswordCard(),
        _profileCard(),
        const SizedBox(height: 20),
        Text('My slots',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_slots.isEmpty)
          const Card(child: ListTile(title: Text('No slots added yet.'))),
        ..._slots.map(_slotCard),
        const SizedBox(height: 20),
        Text('Pending appointments',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_bookings.isEmpty)
          const Card(child: ListTile(title: Text('No appointments yet.'))),
        ..._bookings.map(_bookingCard),
      ]),
    );
  }

  Widget _loginView() => Scaffold(
      appBar: AppBar(title: const Text('Practitioner Login')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'OTP or password')),
        const SizedBox(height: 12),
        TextField(
            controller: _license,
            decoration: const InputDecoration(labelText: 'License number')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _busy ? null : _login,
            child: Text(_busy ? 'Signing in...' : 'Sign in')),
      ]));

  Widget _setupPasswordCard() => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Update your temporary password',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
                controller: _newPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password')),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: _changePassword,
                child: const Text('Update password')),
          ])));

  Widget _profileCard() => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Availability and consultation settings',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Consultation minutes')),
            TextField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (BDT)')),
            TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location')),
            TextField(
                controller: _contact,
                decoration: const InputDecoration(labelText: 'Contact number')),
            TextField(
                controller: _qualifications,
                decoration: const InputDecoration(labelText: 'Qualifications')),
            TextField(
                controller: _specialty,
                decoration: const InputDecoration(labelText: 'Specialty')),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: _saveSetup, child: const Text('Save settings')),
            const Divider(height: 24),
            const Text('Add a slot',
                style: TextStyle(fontWeight: FontWeight.w600)),
            TextField(
                controller: _start,
                decoration: const InputDecoration(
                    labelText: 'Start: YYYY-MM-DD HH:MM')),
            TextField(
                controller: _end,
                decoration:
                    const InputDecoration(labelText: 'End: YYYY-MM-DD HH:MM')),
            OutlinedButton(onPressed: _addSlot, child: const Text('Add slot')),
          ])));

  Widget _slotCard(Map<String, dynamic> slot) {
    final booked = slot['status'] == 'booked' || slot['booking_id'] != null;
    return Card(
      child: ListTile(
        leading: Icon(booked ? Icons.event_available : Icons.schedule),
        title: Text('${slot['starts_at']} - ${slot['ends_at']}'),
        subtitle: Text(booked ? 'Booked appointment' : 'Available'),
        trailing: Text(slot['status'].toString()),
      ),
    );
  }

  Future<void> _logout() async {
    _api.setToken(null);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = booking['status'].toString();
    final pending = status == 'pending_payment';
    final accepted = status == 'confirmed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${booking['user_name']} · ${booking['user_email']}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
              '${booking['starts_at']}\n${booking['currency']} ${booking['fee_amount']} · ${booking['payment_status']}'),
          const SizedBox(height: 10),
          if (pending)
            Wrap(spacing: 8, children: [
              FilledButton(
                  onPressed: () => _action(booking['id'] as String, 'accept'),
                  child: const Text('Accept')),
              OutlinedButton(
                  onPressed: () =>
                      _action(booking['id'] as String, 'accept_cash'),
                  child: const Text('Take cash')),
              TextButton(
                  onPressed: () => _action(booking['id'] as String, 'decline'),
                  child: const Text('Decline')),
            ])
          else if (accepted)
            Wrap(spacing: 8, children: [
              FilledButton(
                  onPressed: () =>
                      _action(booking['id'] as String, 'completed'),
                  child: const Text('Appointment completed')),
              if (booking['payment_status'] != 'paid')
                OutlinedButton(
                    onPressed: () =>
                        _action(booking['id'] as String, 'accept_cash'),
                    child: const Text('Cash accepted')),
            ])
          else
            Text(status == 'completed' ? 'Appointment completed' : status),
        ]),
      ),
    );
  }
}
