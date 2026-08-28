import 'package:flutter/foundation.dart';
import '../models/behavioral_activation.dart';
import '../services/api_service.dart';

class BehavioralActivationProvider extends ChangeNotifier {
  final ApiService _apiService;

  BehavioralDailyTask? _todayTask;
  List<BehavioralDailyTask> _history = [];
  BehavioralStats? _stats;
  bool _isTodayLoading = false;
  bool _isHistoryLoading = false;
  bool _isActionLoading = false;
  bool _hasNoAvailableActivities = false;
  String? _error;
  int _generation = 0;

  BehavioralActivationProvider(this._apiService);

  BehavioralDailyTask? get todayTask => _todayTask;
  List<BehavioralDailyTask> get history => List.unmodifiable(_history);
  BehavioralStats? get stats => _stats;
  bool get isLoading => _isTodayLoading || _isHistoryLoading;
  bool get isTodayLoading => _isTodayLoading;
  bool get isHistoryLoading => _isHistoryLoading;
  bool get isActionLoading => _isActionLoading;
  bool get hasNoAvailableActivities => _hasNoAvailableActivities;
  String? get error => _error;

  void reset() {
    _generation++;
    _todayTask = null;
    _history = [];
    _stats = null;
    _isTodayLoading = false;
    _isHistoryLoading = false;
    _isActionLoading = false;
    _hasNoAvailableActivities = false;
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
    return 'Could not reach the planner. Please try again when you are ready.';
  }

  Future<void> loadToday() async {
    final generation = _generation;
    _isTodayLoading = true;
    _hasNoAvailableActivities = false;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getTodayBehavioralTask();
      if (generation != _generation) return;
      _todayTask = data.isEmpty ? null : BehavioralDailyTask.fromJson(data);
    } catch (e) {
      if (generation != _generation) return;
      if (e is ApiException && e.statusCode == 404) {
        _todayTask = null;
        _hasNoAvailableActivities = true;
      } else {
        _error = _messageFor(e);
      }
    } finally {
      if (generation == _generation) {
        _isTodayLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> completeTask() async {
    if (_todayTask == null || !_todayTask!.isPending || _isActionLoading) {
      return false;
    }
    _isActionLoading = true;
    _error = null;
    final generation = _generation;
    notifyListeners();

    try {
      final data = await _apiService.completeBehavioralTask(_todayTask!.id);
      if (generation != _generation) return false;
      _todayTask = BehavioralDailyTask.fromJson(data);
      await loadStats();
      return generation == _generation;
    } catch (e) {
      if (generation != _generation) return false;
      _error = _messageFor(e);
      return false;
    } finally {
      if (generation == _generation) {
        _isActionLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> skipTask() async {
    if (_todayTask == null || !_todayTask!.isPending || _isActionLoading) {
      return false;
    }
    _isActionLoading = true;
    _error = null;
    final generation = _generation;
    notifyListeners();

    try {
      final data = await _apiService.skipBehavioralTask(_todayTask!.id);
      if (generation != _generation) return false;
      _todayTask = BehavioralDailyTask.fromJson(data);
      await loadStats();
      return generation == _generation;
    } catch (e) {
      if (generation != _generation) return false;
      _error = _messageFor(e);
      return false;
    } finally {
      if (generation == _generation) {
        _isActionLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> submitMood({int? moodBefore, int? moodAfter}) async {
    if (_todayTask == null || _isActionLoading) return false;
    if (moodBefore == null && moodAfter == null) return false;
    _isActionLoading = true;
    _error = null;
    final generation = _generation;
    notifyListeners();

    try {
      final data = await _apiService.submitBehavioralMood(
        _todayTask!.id,
        moodBefore: moodBefore,
        moodAfter: moodAfter,
      );
      if (generation != _generation) return false;
      _todayTask = BehavioralDailyTask.fromJson(data);
      return true;
    } catch (e) {
      if (generation != _generation) return false;
      _error = _messageFor(e);
      return false;
    } finally {
      if (generation == _generation) {
        _isActionLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> changeTask() async {
    if (_todayTask == null || !_todayTask!.isPending || _isActionLoading) {
      return false;
    }
    _isActionLoading = true;
    _error = null;
    final generation = _generation;
    notifyListeners();

    try {
      final data = await _apiService.changeBehavioralTask(_todayTask!.id);
      if (generation != _generation) return false;
      _todayTask = BehavioralDailyTask.fromJson(data);
      return true;
    } catch (e) {
      if (generation != _generation) return false;
      _error = _messageFor(e);
      return false;
    } finally {
      if (generation == _generation) {
        _isActionLoading = false;
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
      final data =
          await _apiService.getBehavioralHistory(days: days, limit: limit);
      if (generation != _generation) return;
      _history = data
          .map((item) =>
              BehavioralDailyTask.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (generation != _generation) return;
      _error = _messageFor(e);
    } finally {
      if (generation == _generation) {
        _isHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadStats({int days = 7}) async {
    final generation = _generation;
    try {
      final data = await _apiService.getBehavioralStats(days: days);
      if (generation != _generation) return;
      _stats = BehavioralStats.fromJson(data);
      notifyListeners();
    } catch (_) {
      // Non-blocking for stats
    }
  }

  Future<void> refresh() async {
    await Future.wait([loadToday(), loadStats()]);
  }
}
