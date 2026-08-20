import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/breathing_session.dart';
import '../services/api_service.dart';
import '../services/sound_service.dart';

enum BreathingStatus {
  idle,
  running,
  paused,
  completed,
}

class BreathingProvider extends ChangeNotifier {
  final ApiService _apiService;
  final SoundService _soundService = SoundService();

  BreathingProvider(this._apiService);

  // Configuration
  BreathingTechnique _technique = BreathingTechnique.boxBreathing;
  int _targetCycles = 4;
  BackgroundSound _selectedSound = BackgroundSound.ocean;
  double _soundVolume = 0.7;
  bool _hapticsEnabled = true;

  // Live Exercise State
  BreathingStatus _status = BreathingStatus.idle;
  BreathPhase _currentPhase = BreathPhase.inhale;
  int _currentCycle = 1;
  int _phaseRemainingSeconds = 4;
  int _phaseElapsedMs = 0;
  double _phaseProgress = 0.0; // 0.0 to 1.0 for smooth visualizer scale
  int _elapsedSeconds = 0;
  Timer? _ticker;

  // History & Metrics State
  List<BreathingSession> _history = [];
  BreathingMetrics? _metrics;
  bool _isLoading = false;
  String? _error;

  // Getters
  BreathingTechnique get technique => _technique;
  int get targetCycles => _targetCycles;
  BackgroundSound get selectedSound => _selectedSound;
  double get soundVolume => _soundVolume;
  bool get hapticsEnabled => _hapticsEnabled;
  BreathingStatus get status => _status;
  BreathPhase get currentPhase => _currentPhase;
  int get currentCycle => _currentCycle;
  int get phaseRemainingSeconds => _phaseRemainingSeconds;
  double get phaseProgress => _phaseProgress;
  int get elapsedSeconds => _elapsedSeconds;
  List<BreathingSession> get history => List.unmodifiable(_history);
  BreathingMetrics? get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isIdle => _status == BreathingStatus.idle;
  bool get isRunning => _status == BreathingStatus.running;
  bool get isPaused => _status == BreathingStatus.paused;
  bool get isCompleted => _status == BreathingStatus.completed;

  int get totalEstimatedSeconds => _technique.cycleDurationSeconds * _targetCycles;

  int get _currentPhaseDurationSeconds {
    switch (_currentPhase) {
      case BreathPhase.inhale:
        return _technique.inhaleSeconds;
      case BreathPhase.holdIn:
        return _technique.holdInSeconds;
      case BreathPhase.exhale:
        return _technique.exhaleSeconds;
      case BreathPhase.holdOut:
        return _technique.holdOutSeconds;
    }
  }

  // Configuration Mutators
  void setTechnique(BreathingTechnique tech) {
    if (_status == BreathingStatus.running) return;
    _technique = tech;
    _targetCycles = tech.defaultCycles;
    _resetPhaseState();
    notifyListeners();
  }

  void setTargetCycles(int cycles) {
    if (_status == BreathingStatus.running) return;
    _targetCycles = cycles.clamp(1, 20);
    notifyListeners();
  }

  void setSound(BackgroundSound sound) {
    _selectedSound = sound;
    _soundService.setSound(sound);
    notifyListeners();
  }

  void setSoundVolume(double vol) {
    _soundVolume = vol.clamp(0.0, 1.0);
    _soundService.setVolume(_soundVolume);
    notifyListeners();
  }

  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    _soundService.setHapticEnabled(enabled);
    notifyListeners();
  }

  // Exercise Lifecycle Controls
  void start() {
    _status = BreathingStatus.running;
    _elapsedSeconds = 0;
    _currentCycle = 1;
    _currentPhase = BreathPhase.inhale;
    _phaseElapsedMs = 0;
    _phaseRemainingSeconds = _technique.inhaleSeconds;
    _phaseProgress = 0.0;

    _soundService.setSound(_selectedSound);
    _soundService.setVolume(_soundVolume);
    _soundService.setHapticEnabled(_hapticsEnabled);
    _soundService.play();
    _soundService.onPhaseChange(_currentPhase);

    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (_status != BreathingStatus.running) return;
    _status = BreathingStatus.paused;
    _ticker?.cancel();
    _ticker = null;
    _soundService.pause();
    notifyListeners();
  }

  void resume() {
    if (_status != BreathingStatus.paused) return;
    _status = BreathingStatus.running;
    _soundService.play();
    _startTicker();
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _status = BreathingStatus.completed;
    _soundService.stop();
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _status = BreathingStatus.idle;
    _soundService.stop();
    _resetPhaseState();
    notifyListeners();
  }

  void _resetPhaseState() {
    _currentPhase = BreathPhase.inhale;
    _currentCycle = 1;
    _phaseElapsedMs = 0;
    _phaseRemainingSeconds = _technique.inhaleSeconds;
    _phaseProgress = 0.0;
    _elapsedSeconds = 0;
  }

  void _startTicker() {
    _ticker?.cancel();
    const tickIntervalMs = 50;

    _ticker = Timer.periodic(const Duration(milliseconds: tickIntervalMs), (timer) {
      if (_status != BreathingStatus.running) {
        timer.cancel();
        return;
      }

      _phaseElapsedMs += tickIntervalMs;
      final phaseDurationMs = _currentPhaseDurationSeconds * 1000;

      if (phaseDurationMs <= 0) {
        _advanceToNextPhase();
        return;
      }

      _phaseProgress = (_phaseElapsedMs / phaseDurationMs).clamp(0.0, 1.0);
      final remainingMs = (phaseDurationMs - _phaseElapsedMs).clamp(0, phaseDurationMs);
      _phaseRemainingSeconds = (remainingMs / 1000).ceil();
      if (_phaseRemainingSeconds <= 0 && remainingMs > 0) {
        _phaseRemainingSeconds = 1;
      }

      // Track total elapsed session seconds
      if (_phaseElapsedMs % 1000 == 0) {
        _elapsedSeconds++;
      }

      if (_phaseElapsedMs >= phaseDurationMs) {
        _advanceToNextPhase();
      }

      notifyListeners();
    });
  }

  void _advanceToNextPhase() {
    _phaseElapsedMs = 0;
    _phaseProgress = 0.0;

    switch (_currentPhase) {
      case BreathPhase.inhale:
        if (_technique.holdInSeconds > 0) {
          _currentPhase = BreathPhase.holdIn;
          _phaseRemainingSeconds = _technique.holdInSeconds;
        } else {
          _currentPhase = BreathPhase.exhale;
          _phaseRemainingSeconds = _technique.exhaleSeconds;
        }
        break;

      case BreathPhase.holdIn:
        _currentPhase = BreathPhase.exhale;
        _phaseRemainingSeconds = _technique.exhaleSeconds;
        break;

      case BreathPhase.exhale:
        if (_technique.holdOutSeconds > 0) {
          _currentPhase = BreathPhase.holdOut;
          _phaseRemainingSeconds = _technique.holdOutSeconds;
        } else {
          _finishCycleOrAdvance();
          return;
        }
        break;

      case BreathPhase.holdOut:
        _finishCycleOrAdvance();
        return;
    }

    _soundService.onPhaseChange(_currentPhase);
    notifyListeners();
  }

  void _finishCycleOrAdvance() {
    if (_currentCycle < _targetCycles) {
      _currentCycle++;
      _currentPhase = BreathPhase.inhale;
      _phaseRemainingSeconds = _technique.inhaleSeconds;
      _soundService.onPhaseChange(_currentPhase);
      notifyListeners();
    } else {
      // Completed all target cycles!
      _ticker?.cancel();
      _ticker = null;
      _status = BreathingStatus.completed;
      _soundService.onSessionComplete();
      notifyListeners();
    }
  }

  // API Interaction
  Future<void> saveSession({String? moodAfter}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = {
        'technique': _technique.name,
        'duration_seconds': _elapsedSeconds > 0 ? _elapsedSeconds : _currentCycle * _technique.cycleDurationSeconds,
        'cycles_completed': _status == BreathingStatus.completed && _currentCycle == _targetCycles
            ? _targetCycles
            : _currentCycle,
        'background_sound': _selectedSound.title,
        'mood_after': moodAfter,
      };

      final response = await _apiService.saveBreathingSession(payload);
      final newSession = BreathingSession.fromJson(response);
      _history.insert(0, newSession);

      // Refresh metrics after saving
      await fetchMetrics();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchHistory({int limit = 30}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getBreathingHistory(limit: limit);
      _history = (data)
          .map((item) => BreathingSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMetrics() async {
    try {
      final data = await _apiService.getBreathingMetrics();
      _metrics = BreathingMetrics.fromJson(data);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _apiService.deleteBreathingSession(sessionId);
      _history.removeWhere((s) => s.id == sessionId);
      await fetchMetrics();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _soundService.dispose();
    super.dispose();
  }
}
