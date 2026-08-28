import 'package:flutter/foundation.dart';

import '../models/savoring_log.dart';
import '../services/api_service.dart';

class SavoringProvider extends ChangeNotifier {
  SavoringProvider(this._apiService);

  final ApiService _apiService;
  SavoringLog? _todayLog;
  List<SavoringLog> _history = [];
  bool _isTodayLoading = false;
  bool _isSaving = false;
  bool _isHistoryLoading = false;
  String? _error;
  int _generation = 0;

  SavoringLog? get todayLog => _todayLog;
  List<SavoringLog> get history => List.unmodifiable(_history);
  bool get isTodayLoading => _isTodayLoading;
  bool get isSaving => _isSaving;
  bool get isHistoryLoading => _isHistoryLoading;
  String? get error => _error;

  void reset() {
    _generation++;
    _todayLog = null;
    _history = [];
    _isTodayLoading = false;
    _isSaving = false;
    _isHistoryLoading = false;
    _error = null;
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return 'Your session has expired. Please sign in again.';
      }
      return error.message;
    }
    return 'Could not reach your journal. Please try again.';
  }

  Future<void> loadToday() async {
    final generation = _generation;
    _isTodayLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _apiService.getTodaySavoringLog();
      if (generation != _generation) return;
      _todayLog = SavoringLog.fromJson(data);
    } catch (error) {
      if (generation != _generation) return;
      _error = _messageFor(error);
    } finally {
      if (generation == _generation) {
        _isTodayLoading = false;
        notifyListeners();
      }
    }
  }

  void updateEntry(
    int position, {
    String? positiveEvent,
    String? whyHappened,
  }) {
    final log = _todayLog;
    if (log == null || log.isCompleted) return;
    final entries = log.entries
        .map((entry) => entry.position == position
            ? entry.copyWith(
                positiveEvent: positiveEvent,
                whyHappened: whyHappened,
              )
            : entry)
        .toList();
    _todayLog = log.copyWith(entries: entries);
    _error = null;
    notifyListeners();
  }

  Future<bool> saveDraft() => _save(complete: false);

  Future<bool> complete() => _save(complete: true);

  Future<bool> _save({required bool complete}) async {
    final log = _todayLog;
    if (log == null || log.isCompleted || _isSaving) return false;
    if (complete && !log.canComplete) {
      _error = 'Add both a good thing and why it happened on all three cards.';
      notifyListeners();
      return false;
    }

    final generation = _generation;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final data = complete
          ? await _apiService.completeSavoringLog(log.id, log.entries)
          : await _apiService.saveSavoringLog(log.id, log.entries);
      if (generation != _generation) return false;
      _todayLog = SavoringLog.fromJson(data);
      return true;
    } catch (error) {
      if (generation != _generation) return false;
      _error = _messageFor(error);
      return false;
    } finally {
      if (generation == _generation) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadHistory({int? days, int limit = 30}) async {
    final generation = _generation;
    _isHistoryLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _apiService.getSavoringHistory(
        days: days,
        limit: limit,
      );
      if (generation != _generation) return;
      _history = data
          .map((item) => SavoringLog.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (error) {
      if (generation != _generation) return;
      _error = _messageFor(error);
    } finally {
      if (generation == _generation) {
        _isHistoryLoading = false;
        notifyListeners();
      }
    }
  }
}
