import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/consultation.dart';
import '../../providers/consultation_provider.dart';
import 'consultation_payment_sheet.dart';

class MyConsultationsScreen extends StatefulWidget {
  const MyConsultationsScreen({super.key});

  @override
  State<MyConsultationsScreen> createState() => _MyConsultationsScreenState();
}

class _MyConsultationsScreenState extends State<MyConsultationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsultationProvider>().loadBookings();
    });
  }

  Future<void> _pay(ConsultationBooking booking) async {
    final choice = await showConsultationPaymentSheet(
      context,
      amount: booking.feeAmount,
      currency: booking.currency,
    );
    if (!mounted || choice == null) return;

    final provider = context.read<ConsultationProvider>();
    final checkout = await provider.startPayment(
      bookingId: booking.id,
      method: choice.method,
      customerPhone: choice.phone,
    );
    if (!mounted) return;
    if (checkout == null) {
      _message(provider.error ?? 'Could not start payment.');
      return;
    }
    final launched = await launchUrl(
      checkout.checkoutUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    _message(
      launched
          ? 'Complete checkout, then return and tap Check payment.'
          : 'Could not open the secure payment page.',
    );
  }

  Future<void> _checkPayment(ConsultationBooking booking) async {
    final provider = context.read<ConsultationProvider>();
    final refreshed = await provider.refreshPayment(booking.id);
    if (!mounted) return;
    _message(
      refreshed?.isPaid == true
          ? 'Payment verified. Your consultation is confirmed.'
          : provider.error ?? 'Payment has not been verified yet.',
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConsultationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Consultations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh bookings',
            onPressed: provider.isProcessing ? null : provider.loadBookings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadBookings,
        child: provider.bookings.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.event_busy_outlined, size: 56),
                  SizedBox(height: 16),
                  Center(child: Text('No consultation bookings yet')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.bookings.length,
                itemBuilder: (context, index) {
                  final booking = provider.bookings[index];
                  return _BookingCard(
                    booking: booking,
                    isProcessing: provider.isProcessing,
                    onPay: () => _pay(booking),
                    onCheckPayment: () => _checkPayment(booking),
                  );
                },
              ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.isProcessing,
    required this.onPay,
    required this.onCheckPayment,
  });

  final ConsultationBooking booking;
  final bool isProcessing;
  final VoidCallback onPay;
  final VoidCallback onCheckPayment;

  @override
  Widget build(BuildContext context) {
    final paid = booking.isPaid;
    final statusColor = paid
        ? Colors.green
        : booking.status == 'confirmed'
            ? Colors.orange
            : Colors.blueGrey;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.practitionerName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Chip(
                  label: Text(paid ? 'Paid' : _statusLabel(booking)),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                ),
              ],
            ),
            Text(booking.qualifications),
            const SizedBox(height: 12),
            Text('Date: ${_bookingDate(booking.slot.startsAt)}'),
            Text('Chamber: ${booking.chamber}'),
            Text(
              'Fee: ${booking.currency} ${booking.feeAmount.toStringAsFixed(0)}',
            ),
            Text(
              booking.paymentTiming == 'after'
                  ? 'Payment timing: after consultation'
                  : 'Payment timing: before consultation',
            ),
            if (booking.payment?.cardType != null)
              Text('Paid with: ${booking.payment!.cardType}'),
            if (booking.canPay || booking.paymentStatus == 'pending') ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  if (booking.canPay)
                    FilledButton.icon(
                      onPressed: isProcessing ? null : onPay,
                      icon: const Icon(Icons.payment_rounded),
                      label: Text(
                        booking.paymentTiming == 'after'
                            ? 'Pay consultation fee'
                            : 'Pay now',
                      ),
                    ),
                  if (booking.paymentStatus == 'pending')
                    OutlinedButton.icon(
                      onPressed: isProcessing ? null : onCheckPayment,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Check payment'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLabel(ConsultationBooking booking) {
  if (booking.status == 'pending_payment') return 'Awaiting payment';
  if (booking.status == 'expired') return 'Expired';
  if (booking.status == 'cancelled') return 'Cancelled';
  if (booking.paymentStatus == 'review') return 'Under review';
  return 'Payment due';
}

String _bookingDate(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} at '
      '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}
