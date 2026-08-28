import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/consultation.dart';
import '../../providers/consultation_provider.dart';
import 'consultation_payment_sheet.dart';
import 'my_consultations_screen.dart';

class PsychiatristListScreen extends StatefulWidget {
  const PsychiatristListScreen({super.key});

  @override
  State<PsychiatristListScreen> createState() => _PsychiatristListScreenState();
}

class _PsychiatristListScreenState extends State<PsychiatristListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsultationProvider>().loadPractitioners();
    });
  }

  Future<String?> _choosePaymentTiming() {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When would you like to pay?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Pay now'),
              subtitle: const Text(
                'The slot is confirmed after SSLCommerz verifies payment.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(sheetContext, 'before'),
            ),
            ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Pay after consultation'),
              subtitle: const Text(
                'Book now and keep the consultation fee due in your profile.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(sheetContext, 'after'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookSlot(
    Psychiatrist psychiatrist,
    ConsultationSlot slot,
  ) async {
    final paymentTiming = await _choosePaymentTiming();
    if (!mounted || paymentTiming == null) return;

    ConsultationPaymentChoice? paymentChoice;
    if (paymentTiming == 'before') {
      paymentChoice = await showConsultationPaymentSheet(
        context,
        amount: psychiatrist.feeAmount,
        currency: psychiatrist.currency,
      );
      if (!mounted || paymentChoice == null) return;
    }

    final provider = context.read<ConsultationProvider>();
    final booking = await provider.createBooking(
      practitionerId: psychiatrist.id,
      slotId: slot.id,
      paymentTiming: paymentTiming,
    );
    if (!mounted) return;
    if (booking == null) {
      _showMessage(provider.error ?? 'Could not reserve this slot.');
      return;
    }

    if (paymentTiming == 'after') {
      _showMessage(
        'Consultation booked. The payment remains due in your profile.',
      );
      return;
    }

    final checkout = await provider.startPayment(
      bookingId: booking.id,
      method: paymentChoice!.method,
      customerPhone: paymentChoice.phone,
    );
    if (!mounted) return;
    if (checkout == null) {
      _showMessage(provider.error ?? 'Could not start payment.');
      return;
    }
    final launched = await launchUrl(
      checkout.checkoutUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    _showMessage(
      launched
          ? 'Complete payment, return to AuraMind, then check payment status.'
          : 'Could not open the secure payment page.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConsultationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Psychiatrists'),
        actions: [
          IconButton(
            tooltip: 'My consultations',
            icon: const Icon(Icons.event_note_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyConsultationsScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh slots',
            icon: const Icon(Icons.refresh),
            onPressed:
                provider.isLoading ? null : () => provider.loadPractitioners(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadPractitioners,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo practitioner profiles are shown for development. '
                        'A green slot is free; grey means held or booked.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (provider.isLoading && provider.practitioners.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.practitioners.isEmpty)
              _ErrorCard(
                message: provider.error!,
                onRetry: provider.loadPractitioners,
              )
            else
              ...provider.practitioners.map(
                (psychiatrist) => _PsychiatristCard(
                  psychiatrist: psychiatrist,
                  isProcessing: provider.isProcessing,
                  onSlotSelected: (slot) => _bookSlot(psychiatrist, slot),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PsychiatristCard extends StatelessWidget {
  const _PsychiatristCard({
    required this.psychiatrist,
    required this.isProcessing,
    required this.onSlotSelected,
  });

  final Psychiatrist psychiatrist;
  final bool isProcessing;
  final ValueChanged<ConsultationSlot> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Text(
                    psychiatrist.name
                        .split(' ')
                        .where((part) => part.isNotEmpty && part != 'Dr.')
                        .take(2)
                        .map((part) => part[0])
                        .join(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        psychiatrist.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(psychiatrist.qualifications),
                      Text(
                        psychiatrist.specialty,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${psychiatrist.currency} ${psychiatrist.feeAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(height: 28),
            _DetailLine(
              icon: Icons.schedule_rounded,
              text: '${psychiatrist.consultationMinutes}-minute consultation',
            ),
            _DetailLine(
              icon: Icons.phone_outlined,
              text: psychiatrist.contactNo,
            ),
            _DetailLine(
              icon: Icons.location_on_outlined,
              text: psychiatrist.chamber,
            ),
            const SizedBox(height: 14),
            const Text(
              'Booking slots',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (psychiatrist.slots.isEmpty)
              const Text('No upcoming slots available.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: psychiatrist.slots.take(12).map((slot) {
                  final color = slot.isAvailable
                      ? Colors.green
                      : slot.bookedByMe
                          ? Colors.blue
                          : Colors.grey;
                  return OutlinedButton(
                    onPressed: slot.isAvailable && !isProcessing
                        ? () => onSlotSelected(slot)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color.shade700,
                      side: BorderSide(color: color.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      '${_shortDate(slot.startsAt)}\n'
                      '${_shortTime(slot.startsAt)} · '
                      '${slot.isAvailable ? 'Free' : slot.bookedByMe ? 'Yours' : 'Booked'}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _shortDate(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}';
}

String _shortTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}
