import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class PractitionerDashboardScreen extends StatefulWidget {
  const PractitionerDashboardScreen({
    super.key,
    this.initialEmail,
    this.initialPassword,
    this.initialLicense,
  });

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
    if (widget.initialEmail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _login());
    }
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
    ]) {
      controller.dispose();
    }
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
        licenseNumber: _license.text.trim(),
      );
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
    _bookings = results[0];
    _slots = results[1];
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
        currentPassword: _password.text,
        newPassword: _newPassword.text,
      );
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
        specialty: _specialty.text.trim(),
      );
      _message('Profile settings saved.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _saveNewSlot(DateTime starts, DateTime ends) async {
    try {
      await _api.addPractitionerSlot(startsAt: starts, endsAt: ends);
      await _loadBookings();
      _message('Slot added successfully.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _updateExistingSlot(
      String slotId, DateTime starts, DateTime ends) async {
    try {
      await _api.editPractitionerSlot(
        slotId: slotId,
        startsAt: starts,
        endsAt: ends,
      );
      await _loadBookings();
      _message('Slot updated successfully.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteSlot(String slotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text(
            'Are you sure you want to remove this available consultation slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deletePractitionerSlot(slotId);
        await _loadBookings();
        _message('Slot removed successfully.');
      } catch (error) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _showSlotDialog({Map<String, dynamic>? existingSlot}) async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    final durationMinutes = int.tryParse(_minutes.text) ?? 30;

    if (existingSlot != null) {
      final s = DateTime.tryParse(existingSlot['starts_at'].toString());
      if (s != null) {
        selectedDate = s;
        startTime = TimeOfDay(hour: s.hour, minute: s.minute);
      }
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final startDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            startTime.hour,
            startTime.minute,
          );
          final endDateTime =
              startDateTime.add(Duration(minutes: durationMinutes));

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(
                  existingSlot == null
                      ? Icons.add_circle_outline_rounded
                      : Icons.edit_calendar_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(existingSlot == null
                    ? 'Add Available Slot'
                    : 'Edit Available Slot'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 120)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _formatDate(selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Text('Change',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.blueGrey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Start Time',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (picked != null) {
                        setModalState(() => startTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            startTime.format(context),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Text('Change',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.blueGrey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Slot Preview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTime(startDateTime)} – ${_formatTime(endDateTime)} ($durationMinutes min)',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatDate(startDateTime),
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  if (existingSlot == null) {
                    await _saveNewSlot(startDateTime, endDateTime);
                  } else {
                    await _updateExistingSlot(
                      existingSlot['id'].toString(),
                      startDateTime,
                      endDateTime,
                    );
                  }
                },
                child: Text(existingSlot == null ? 'Add Slot' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _action(String id, String action) async {
    try {
      await _api.practitionerBookingAction(id, action);
      await _loadBookings();
      _message(action == 'accept_cash'
          ? 'Appointment accepted with cash payment.'
          : (action == 'accept'
              ? 'Appointment accepted.'
              : (action == 'decline'
                  ? 'Appointment declined.'
                  : 'Appointment updated.')));
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String _formatDate(DateTime dt) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    return '$weekday, $month ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _logout() async {
    _api.setToken(null);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return _loginView();

    final pendingCount = _bookings
        .where((b) =>
            b['status'] == 'pending' || b['status'] == 'pending_payment')
        .length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Practitioner Dashboard',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Log out',
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.calendar_month_rounded),
                ),
                text: 'Appointments',
              ),
              Tab(
                icon: const Icon(Icons.schedule_rounded),
                text: 'Schedule (${_slots.length})',
              ),
              const Tab(
                icon: Icon(Icons.settings_outlined),
                text: 'Profile',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _appointmentsTab(),
            _scheduleTab(),
            _profileTab(),
          ],
        ),
      ),
    );
  }

  Widget _appointmentsTab() {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'No appointments yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _bookings.length,
      itemBuilder: (context, index) => _bookingCard(_bookings[index]),
    );
  }

  Widget _scheduleTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSlotDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Slot'),
      ),
      body: _slots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  Text(
                    'No consultation slots scheduled',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap "Add Slot" below to create available times.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
              itemCount: _slots.length,
              itemBuilder: (context, index) => _slotCard(_slots[index]),
            ),
    );
  }

  Widget _profileTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (_mustChangePassword) _setupPasswordCard(),
        _profileCard(),
      ],
    );
  }

  Widget _slotCard(Map<String, dynamic> slot) {
    final status = slot['status'].toString();
    final booked = status == 'booked' || slot['booking_id'] != null;

    final startsAt = DateTime.tryParse(slot['starts_at'].toString());
    final endsAt = DateTime.tryParse(slot['ends_at'].toString());

    final dateText = startsAt != null ? _formatDate(startsAt) : slot['starts_at'];
    final timeRangeText = startsAt != null && endsAt != null
        ? '${_formatTime(startsAt)} – ${_formatTime(endsAt)}'
        : '${slot['starts_at']} - ${slot['ends_at']}';

    final statusColor = booked ? Colors.indigo : Colors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    booked
                        ? Icons.event_busy_rounded
                        : Icons.event_available_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeRangeText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(booked ? 'Booked' : 'Available'),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (!booked) ...[
              const Divider(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showSlotDialog(existingSlot: slot),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _deleteSlot(slot['id'].toString()),
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red.shade700),
                    label: Text(
                      'Remove',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = booking['status'].toString();
    final paymentStatus = booking['payment_status'].toString();
    final pending = status == 'pending' || status == 'pending_payment';
    final accepted = status == 'confirmed';
    final isPaid = paymentStatus == 'paid';

    final startsAt = DateTime.tryParse(booking['starts_at'].toString());
    final dateText = startsAt != null ? _formatDate(startsAt) : booking['starts_at'];
    final timeText = startsAt != null ? _formatTime(startsAt) : '';

    Color statusColor;
    String statusTitle;
    if (status == 'completed') {
      statusColor = Colors.blueGrey;
      statusTitle = 'Completed';
    } else if (status == 'confirmed') {
      statusColor = Colors.teal;
      statusTitle = 'Accepted';
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
      statusTitle = 'Declined';
    } else {
      statusColor = Colors.orange;
      statusTitle = 'Pending Acceptance';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['user_name'] ?? 'Patient',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        booking['user_email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusTitle),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_note_rounded, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$dateText${timeText.isNotEmpty ? ' at $timeText' : ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Fee: ${booking['currency']} ${booking['fee_amount']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'Payment: Paid' : 'Payment: Unpaid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _action(booking['id'] as String, 'accept'),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _action(booking['id'] as String, 'accept_cash'),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Accept Cash'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _action(booking['id'] as String, 'decline'),
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: Colors.red.shade700),
                    label: Text(
                      'Decline',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              )
            else if (accepted)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _action(booking['id'] as String, 'completed'),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Appointment Completed'),
                  ),
                  if (!isPaid)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _action(booking['id'] as String, 'accept_cash'),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Cash Accepted'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _setupPasswordCard() => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update your temporary password',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _newPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _changePassword,
                child: const Text('Update password'),
              ),
            ],
          ),
        ),
      );

  Widget _profileCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Consultation & Chamber Settings',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 14),
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Consultation minutes'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (BDT)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Chamber Location'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contact,
                decoration: const InputDecoration(labelText: 'Contact number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _qualifications,
                decoration: const InputDecoration(labelText: 'Qualifications'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _specialty,
                decoration: const InputDecoration(labelText: 'Specialty'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saveSetup,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      );

  Widget _loginView() => Scaffold(
        appBar: AppBar(title: const Text('Practitioner Login')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'OTP or password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _license,
              decoration: const InputDecoration(labelText: 'License number'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _login,
              child: Text(_busy ? 'Signing in...' : 'Sign in'),
            ),
          ],
        ),
      );
}
