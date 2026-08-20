import 'package:flutter/foundation.dart';

import '../models/mood_analytics.dart';
import '../services/api_service.dart';

class MoodAnalyticsProvider extends ChangeNotifier {
  MoodAnalyticsProvider(this._api);

  final ApiService _api;

  MoodAnalytics? _analytics;
  bool _isLoading = false;
  String? _error;
  int _selectedDays = 7;

  MoodAnalytics? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get selectedDays => _selectedDays;

  Future<void> load({int? days}) async {
    if (days != null) _selectedDays = days;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _analytics = await _api.getMoodAnalytics(days: _selectedDays);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load your mood insights.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
