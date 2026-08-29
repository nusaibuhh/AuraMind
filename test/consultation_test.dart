import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:auramind/models/consultation.dart';
import 'package:auramind/providers/consultation_provider.dart';
import 'package:auramind/screens/consultations/psychiatrist_list_screen.dart';
import 'package:auramind/services/api_service.dart';

Map<String, dynamic> _psychiatristPayload() => {
      'id': 'psych_demo',
      'name': 'Dr. Demo Psychiatrist',
      'qualifications': 'MBBS, FCPS (Psychiatry)',
      'specialty': 'Mood and anxiety care',
      'consultation_minutes': 30,
      'contact_no': '+880 1711-100000',
      'chamber': 'Demo Chamber, Dhaka',
      'fee_amount': 1800,
      'currency': 'BDT',
      'is_demo': true,
      'slots': [
        {
          'id': 'slot_free',
          'starts_at': '2026-09-01T10:00:00+06:00',
          'ends_at': '2026-09-01T10:30:00+06:00',
          'status': 'free',
          'is_available': true,
          'booked_by_me': false,
        },
        {
          'id': 'slot_booked',
          'starts_at': '2026-09-01T11:00:00+06:00',
          'ends_at': '2026-09-01T11:30:00+06:00',
          'status': 'booked',
          'is_available': false,
          'booked_by_me': false,
        },
      ],
    };

Map<String, dynamic> _bookingPayload() => {
      'id': 'booking_123',
      'user_id': 'user_123',
      'practitioner_id': 'psych_demo',
      'slot_id': 'slot_free',
      'status': 'confirmed',
      'payment_timing': 'before',
      'payment_status': 'paid',
      'fee_amount': 1800,
      'currency': 'BDT',
      'practitioner': {
        'id': 'psych_demo',
        'name': 'Dr. Demo Psychiatrist',
        'qualifications': 'MBBS, FCPS (Psychiatry)',
        'specialty': 'Mood and anxiety care',
        'consultation_minutes': 30,
        'contact_no': '+880 1711-100000',
        'chamber': 'Demo Chamber, Dhaka',
      },
      'slot': {
        'id': 'slot_free',
        'starts_at': '2026-09-01T10:00:00+06:00',
        'ends_at': '2026-09-01T10:30:00+06:00',
        'status': 'booked',
      },
      'payment': {
        'id': 'payment_123',
        'provider': 'sslcommerz',
        'method': 'bkash',
        'status': 'paid',
        'transaction_id': 'AM123',
        'card_type': 'BKASH',
        'paid_at': '2026-09-01T09:45:00',
      },
    };

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

void main() {
  test('psychiatrist model preserves free and booked slot states', () {
    final psychiatrist = Psychiatrist.fromJson(_psychiatristPayload());

    expect(psychiatrist.name, 'Dr. Demo Psychiatrist');
    expect(psychiatrist.isDemo, isTrue);
    expect(psychiatrist.slots.first.isAvailable, isTrue);
    expect(psychiatrist.slots.last.isAvailable, isFalse);
  });

  test('paid consultation booking exposes verified payment state', () {
    final booking = ConsultationBooking.fromJson(_bookingPayload());

    expect(booking.isConfirmed, isTrue);
    expect(booking.isPaid, isTrue);
    expect(booking.canPay, isFalse);
    expect(booking.payment?.provider, 'sslcommerz');
  });

  test('API sends booking timing and parses the reserved booking', () async {
    late Map<String, dynamic> requestBody;
    late Map<String, String> requestHeaders;
    final api = ApiService(
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        requestHeaders = request.headers;
        return _jsonResponse(_bookingPayload());
      }),
    );

    final booking = await api.createConsultationBooking(
      practitionerId: 'psych_demo',
      slotId: 'slot_free',
      paymentTiming: 'before',
    );

    expect(requestBody['payment_timing'], 'before');
    expect(requestBody['slot_id'], 'slot_free');
    expect(requestHeaders['ngrok-skip-browser-warning'], 'true');
    expect(booking.isPaid, isTrue);
  });

  testWidgets('psychiatrist screen clearly labels free and booked slots',
      (tester) async {
    final api = ApiService(
      client: MockClient((request) async {
        return _jsonResponse([_psychiatristPayload()]);
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ConsultationProvider(api),
        child: const MaterialApp(home: PsychiatristListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dr. Demo Psychiatrist'), findsOneWidget);
    expect(find.textContaining('Free'), findsOneWidget);
    expect(find.textContaining('Booked'), findsOneWidget);
  });
}
