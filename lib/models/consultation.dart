class ConsultationSlot {
  const ConsultationSlot({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.isAvailable,
    required this.bookedByMe,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final bool isAvailable;
  final bool bookedByMe;

  factory ConsultationSlot.fromJson(Map<String, dynamic> json) {
    return ConsultationSlot(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: json['status'] as String? ?? 'free',
      isAvailable: json['is_available'] as bool? ?? false,
      bookedByMe: json['booked_by_me'] as bool? ?? false,
    );
  }
}

class Psychiatrist {
  const Psychiatrist({
    required this.id,
    required this.name,
    required this.qualifications,
    required this.specialty,
    required this.consultationMinutes,
    required this.contactNo,
    required this.chamber,
    required this.feeAmount,
    required this.currency,
    required this.isDemo,
    required this.slots,
  });

  final String id;
  final String name;
  final String qualifications;
  final String specialty;
  final int consultationMinutes;
  final String contactNo;
  final String chamber;
  final double feeAmount;
  final String currency;
  final bool isDemo;
  final List<ConsultationSlot> slots;

  factory Psychiatrist.fromJson(Map<String, dynamic> json) {
    return Psychiatrist(
      id: json['id'] as String,
      name: json['name'] as String,
      qualifications: json['qualifications'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      consultationMinutes: json['consultation_minutes'] as int? ?? 30,
      contactNo: json['contact_no'] as String? ?? '',
      chamber: json['chamber'] as String? ?? '',
      feeAmount: (json['fee_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'BDT',
      isDemo: json['is_demo'] as bool? ?? false,
      slots: (json['slots'] as List? ?? const [])
          .map((slot) => ConsultationSlot.fromJson(
                Map<String, dynamic>.from(slot as Map),
              ))
          .toList(),
    );
  }
}

class ConsultationPayment {
  const ConsultationPayment({
    required this.id,
    required this.provider,
    required this.method,
    required this.status,
    required this.transactionId,
    this.cardType,
    this.paidAt,
  });

  final String id;
  final String provider;
  final String method;
  final String status;
  final String transactionId;
  final String? cardType;
  final DateTime? paidAt;

  factory ConsultationPayment.fromJson(Map<String, dynamic> json) {
    return ConsultationPayment(
      id: json['id'] as String,
      provider: json['provider'] as String? ?? 'sslcommerz',
      method: json['method'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      transactionId: json['transaction_id'] as String? ?? '',
      cardType: json['card_type'] as String?,
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.tryParse(json['paid_at'].toString()),
    );
  }
}

class ConsultationBooking {
  const ConsultationBooking({
    required this.id,
    required this.status,
    required this.paymentTiming,
    required this.paymentStatus,
    required this.feeAmount,
    required this.currency,
    required this.practitionerId,
    required this.practitionerName,
    required this.qualifications,
    required this.specialty,
    required this.contactNo,
    required this.chamber,
    required this.slot,
    this.payment,
  });

  final String id;
  final String status;
  final String paymentTiming;
  final String paymentStatus;
  final double feeAmount;
  final String currency;
  final String practitionerId;
  final String practitionerName;
  final String qualifications;
  final String specialty;
  final String contactNo;
  final String chamber;
  final ConsultationSlot slot;
  final ConsultationPayment? payment;

  bool get isPaid => paymentStatus == 'paid';
  bool get canPay =>
      paymentStatus == 'unpaid' &&
      !{'cancelled', 'expired', 'slot_conflict'}.contains(status);
  bool get isConfirmed => status == 'confirmed';

  factory ConsultationBooking.fromJson(Map<String, dynamic> json) {
    final practitioner = Map<String, dynamic>.from(json['practitioner'] as Map);
    final slotJson = Map<String, dynamic>.from(json['slot'] as Map);
    final paymentJson = json['payment'];
    return ConsultationBooking(
      id: json['id'] as String,
      status: json['status'] as String,
      paymentTiming: json['payment_timing'] as String,
      paymentStatus: json['payment_status'] as String,
      feeAmount: (json['fee_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'BDT',
      practitionerId: json['practitioner_id'] as String,
      practitionerName: practitioner['name'] as String,
      qualifications: practitioner['qualifications'] as String? ?? '',
      specialty: practitioner['specialty'] as String? ?? '',
      contactNo: practitioner['contact_no'] as String? ?? '',
      chamber: practitioner['chamber'] as String? ?? '',
      slot: ConsultationSlot.fromJson({
        ...slotJson,
        'is_available': slotJson['status'] == 'free',
        'booked_by_me': true,
      }),
      payment: paymentJson is Map
          ? ConsultationPayment.fromJson(
              Map<String, dynamic>.from(paymentJson),
            )
          : null,
    );
  }
}

class ConsultationCheckout {
  const ConsultationCheckout({
    required this.bookingId,
    required this.transactionId,
    required this.checkoutUrl,
    required this.status,
  });

  final String bookingId;
  final String transactionId;
  final Uri checkoutUrl;
  final String status;

  factory ConsultationCheckout.fromJson(Map<String, dynamic> json) {
    return ConsultationCheckout(
      bookingId: json['booking_id'] as String,
      transactionId: json['transaction_id'] as String,
      checkoutUrl: Uri.parse(json['checkout_url'] as String),
      status: json['status'] as String? ?? 'pending',
    );
  }
}
