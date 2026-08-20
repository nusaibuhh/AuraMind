import 'package:flutter/foundation.dart';

import '../models/sleep_log.dart';
import '../services/api_service.dart';

class SleepProvider extends ChangeNotifier {
  final ApiService _apiService;

  // State for current sleep log form
  int _hours = 7;
  int _minutes = 20;
  SleepQuality _quality = SleepQuality.good;
  PostWakeFeeling _postWakeFeeling = PostWakeFeeling.normal;
  String _notes = '';

  // State for data fetching
  List<SleepLog> _sleepLogs = [];
  SleepMetrics? _metrics;
  List<SleepMoodCorrelation>? _correlations;
  List<WellbeingWarning> _warnings = [];
  bool _isLoading = false;
  String? _error;

  SleepProvider(this._apiService);

  // Getters
  int get hours => _hours;
  int get minutes => _minutes;
  SleepQuality get quality => _quality;
  PostWakeFeeling get postWakeFeeling => _postWakeFeeling;
  String get notes => _notes;
  List<SleepLog> get sleepLogs => List.unmodifiable(_sleepLogs);
  SleepMetrics? get metrics => _metrics;
  List<SleepMoodCorrelation>? get correlations => _correlations;
  List<WellbeingWarning> get warnings => List.unmodifiable(_warnings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Form setters
  void setHours(int h) {
    _hours = h.clamp(0, 23);
    notifyListeners();
  }

  void setMinutes(int m) {
    _minutes = m.clamp(0, 59);
    notifyListeners();
  }

  void setQuality(SleepQuality q) {
    _quality = q;
    notifyListeners();
  }

  void setPostWakeFeeling(PostWakeFeeling f) {
    _postWakeFeeling = f;
    notifyListeners();
  }

  void setNotes(String n) {
    _notes = n;
    notifyListeners();
  }

  void resetForm() {
    _hours = 7;
    _minutes = 20;
    _quality = SleepQuality.good;
    _postWakeFeeling = PostWakeFeeling.normal;
    _notes = '';
    notifyListeners();
  }

  // API methods
  Future<void> fetchSleepLogs({int days = 30}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getSleepLogs(days: days);
      _sleepLogs = (data)
          .map((item) => SleepLog.fromJson(item as Map<String, dynamic>))
          .toList();
      _sleepLogs.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMetrics({int days = 7}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getSleepMetrics(days: days);
      final avgSleep = (data['average_sleep'] as num).toDouble();
      final avgQuality = (data['average_quality'] as num).toDouble();
      final entries = (data['entries'] as List)
          .map((item) => SleepLog.fromJson(item as Map<String, dynamic>))
          .toList();

      _metrics = SleepMetrics(
        averageSleep: avgSleep,
        averageQuality: avgQuality,
        totalEntries: entries.length,
        entries: entries,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCorrelations({int days = 7}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getSleepMoodCorrelation(days: days);
      _correlations = (data)
          .map((item) => SleepMoodCorrelation.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchWarnings() async {
    try {
      final data = await _apiService.getWellbeingWarnings();
      _warnings = (data)
          .map((item) => WellbeingWarning.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> saveSleepLog() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = {
        'date': DateTime.now().toIso8601String(),
        'sleep_hours': _hours,
        'sleep_minutes': _minutes,
        'quality': _quality.index,
        'post_wake_feeling': _postWakeFeeling.index,
        'notes': _notes.isEmpty ? null : _notes,
      };

      final response = await _apiService.saveSleepLog(payload);
      final newLog = SleepLog.fromJson(response);
      _sleepLogs.insert(0, newLog);
      
      // Refresh warnings after saving
      await fetchWarnings();
      resetForm();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> dismissWarning(String warningId) async {
    try {
      await _apiService.dismissWarning(warningId);
      _warnings.removeWhere((w) => w.id == warningId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> deleteSleepLog(String logId) async {
    try {
      await _apiService.deleteSleepLog(logId);
      _sleepLogs.removeWhere((log) => log.id == logId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }
}
