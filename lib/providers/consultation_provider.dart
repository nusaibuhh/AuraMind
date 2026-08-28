import 'package:flutter/foundation.dart';

import '../models/consultation.dart';
import '../services/api_service.dart';

class ConsultationProvider extends ChangeNotifier {
  ConsultationProvider(this._api);

  final ApiService _api;

  List<Psychiatrist> _practitioners = [];
  List<ConsultationBooking> _bookings = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;

  List<Psychiatrist> get practitioners => List.unmodifiable(_practitioners);
  List<ConsultationBooking> get bookings => List.unmodifiable(_bookings);
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  void reset() {
    _practitioners = [];
    _bookings = [];
    _isLoading = false;
    _isProcessing = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadPractitioners({int days = 14}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _practitioners = await _api.getConsultationPractitioners(days: days);
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBookings() async {
    _error = null;
    try {
      _bookings = await _api.getMyConsultationBookings();
    } catch (error) {
      _error = error.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<ConsultationBooking?> createBooking({
    required String practitionerId,
    required String slotId,
    required String paymentTiming,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();
    try {
      final booking = await _api.createConsultationBooking(
        practitionerId: practitionerId,
        slotId: slotId,
        paymentTiming: paymentTiming,
      );
      _bookings.insert(0, booking);
      await loadPractitioners();
      return booking;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<ConsultationCheckout?> startPayment({
    required String bookingId,
    required String method,
    required String customerPhone,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();
    try {
      final checkout = await _api.startConsultationPayment(
        bookingId: bookingId,
        method: method,
        customerPhone: customerPhone,
      );
      await loadBookings();
      return checkout;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<ConsultationBooking?> refreshPayment(String bookingId) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();
    try {
      final refreshed = await _api.refreshConsultationPayment(bookingId);
      final index = _bookings.indexWhere((booking) => booking.id == bookingId);
      if (index == -1) {
        _bookings.insert(0, refreshed);
      } else {
        _bookings[index] = refreshed;
      }
      await loadPractitioners();
      return refreshed;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
