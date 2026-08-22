import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/mood_momentum_session.dart';
import '../services/grounding_voice_service.dart';

enum MoodMomentumStatus { idle, running, paused, completed, unavailable }

class MoodMomentumProvider extends ChangeNotifier {
  MoodMomentumSessionConfig _config = MoodMomentumSessionConfig.fiveMinutes;
  MoodMomentumStatus _status = MoodMomentumStatus.idle;
  int _remainingSeconds = MoodMomentumSessionConfig.fiveMinutes.totalSeconds;
  int _steps = 0;
  int? _baselineSensorSteps;
  int _lastCueIndex = -1;
  String? _sensorMessage;

  Timer? _ticker;
  StreamSubscription<StepCount>? _stepSubscription;
  final GroundingVoiceService _voice = GroundingVoiceService();

  static const List<GroundingCue> _cues = [
    GroundingCue(
      title: 'Start with your feet',
      message: 'Notice each foot meeting the ground. You only need to take the next step.',
    ),
    GroundingCue(
      title: 'Look around',
      message: 'Notice three colours or shapes around you as you keep a comfortable pace.',
    ),
    GroundingCue(
      title: 'Listen',
      message: 'Notice two sounds. Let them remind you that you are here, moving through this moment.',
    ),
    GroundingCue(
      title: 'Keep the momentum',
      message: 'Take one slow breath. You have already started, and every step counts.',
    ),
  ];

  MoodMomentumSessionConfig get config => _config;
  MoodMomentumStatus get status => _status;
  int get remainingSeconds => _remainingSeconds;
  int get steps => _steps;
  String? get sensorMessage => _sensorMessage;
  List<GroundingCue> get cues => List.unmodifiable(_cues);

  bool get isIdle => _status == MoodMomentumStatus.idle;
  bool get isRunning => _status == MoodMomentumStatus.running;
  bool get isPaused => _status == MoodMomentumStatus.paused;
  bool get isCompleted => _status == MoodMomentumStatus.completed;
  bool get isUnavailable => _status == MoodMomentumStatus.unavailable;

  double get stepProgress => (_steps / _config.stepGoal).clamp(0.0, 1.0);
  double get timeProgress => 1 - (_remainingSeconds / _config.totalSeconds);
  int get elapsedSeconds => _config.totalSeconds - _remainingSeconds;
  int get percentComplete => (stepProgress * 100).round();

  String get formattedRemaining {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  GroundingCue get currentCue {
    final quarter = (_config.totalSeconds / _cues.length).ceil();
    final index = (elapsedSeconds ~/ quarter).clamp(0, _cues.length - 1);
    return _cues[index];
  }

  void setDuration(int minutes) {
    if (isRunning || isPaused) return;
    _config = minutes == 10
        ? MoodMomentumSessionConfig.tenMinutes
        : MoodMomentumSessionConfig.fiveMinutes;
    _remainingSeconds = _config.totalSeconds;
    _steps = 0;
    _baselineSensorSteps = null;
    _lastCueIndex = -1;
    _sensorMessage = null;
    _status = MoodMomentumStatus.idle;
    notifyListeners();
  }

  Future<void> start() async {
    if (isRunning) return;

    if (isPaused) {
      _status = MoodMomentumStatus.running;
      _startTicker();
      _speakCurrentCue(force: false);
      notifyListeners();
      return;
    }

    _remainingSeconds = _config.totalSeconds;
    _steps = 0;
    _baselineSensorSteps = null;
    _lastCueIndex = -1;
    _sensorMessage = null;
    _status = MoodMomentumStatus.running;

    await _startStepTracking();
    _startTicker();
    await _speakCurrentCue(force: true);
    notifyListeners();
  }

  Future<void> _startStepTracking() async {
    await _stepSubscription?.cancel();
    _stepSubscription = null;

    if (kIsWeb) {
      _sensorMessage = 'Step counting needs the native Android app. The timer and grounding walk still work here.';
      return;
    }

    try {
      final permission = await Permission.activityRecognition.request();
      if (!permission.isGranted) {
        _sensorMessage = 'Activity recognition permission was not granted, so step counting is unavailable.';
        return;
      }

      _stepSubscription = Pedometer.stepCountStream.listen(
        (event) {
          _baselineSensorSteps ??= event.steps;
          final nextSteps = event.steps - _baselineSensorSteps!;
          _steps = nextSteps < 0 ? 0 : nextSteps;
          _sensorMessage = null;
          notifyListeners();
        },
        onError: (_) {
          _sensorMessage = 'This device does not currently provide a usable step counter.';
          notifyListeners();
        },
      );
    } catch (_) {
      _sensorMessage = 'Step sensor setup was unavailable. You can still complete the timed grounding walk.';
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_status != MoodMomentumStatus.running) return;

      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        await _speakCurrentCue(force: false);
      }

      if (_remainingSeconds <= 0) {
        await _complete();
      }
      notifyListeners();
    });
  }

  Future<void> _speakCurrentCue({required bool force}) async {
    final quarter = (_config.totalSeconds / _cues.length).ceil();
    final index = (elapsedSeconds ~/ quarter).clamp(0, _cues.length - 1);
    if (!force && index == _lastCueIndex) return;
    _lastCueIndex = index;
    await _voice.speak(_cues[index].message);
  }

  void pause() {
    if (!isRunning) return;
    _ticker?.cancel();
    _ticker = null;
    _status = MoodMomentumStatus.paused;
    _voice.stop();
    notifyListeners();
  }

  Future<void> _complete() async {
    _ticker?.cancel();
    _ticker = null;
    await _stepSubscription?.cancel();
    _stepSubscription = null;
    _status = MoodMomentumStatus.completed;
    await _voice.speak('Walk complete. Well done for making time to move. Every bit of momentum counts.');
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _voice.stop();
    _status = MoodMomentumStatus.idle;
    _remainingSeconds = _config.totalSeconds;
    _steps = 0;
    _baselineSensorSteps = null;
    _lastCueIndex = -1;
    _sensorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stepSubscription?.cancel();
    _voice.dispose();
    super.dispose();
  }
}
