import 'dart:async';
import 'package:flutter/services.dart';
import '../models/breathing_session.dart';
import 'audio_engine.dart';

/// Sound and haptic feedback service for breathing exercises
class SoundService {
  final AudioEngine _engine = createAudioEngine();

  BackgroundSound _currentSound = BackgroundSound.ocean;
  double _volume = 0.7;
  bool _isPlaying = false;
  bool _hapticEnabled = true;

  BackgroundSound get currentSound => _currentSound;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;
  bool get hapticEnabled => _hapticEnabled;

  void setSound(BackgroundSound sound) {
    _currentSound = sound;
    if (_isPlaying) {
      _engine.startAmbient(_currentSound.id, _volume);
    }
  }

  void setVolume(double val) {
    _volume = val.clamp(0.0, 1.0);
    _engine.setVolume(_volume);
  }

  void setHapticEnabled(bool enabled) {
    _hapticEnabled = enabled;
  }

  void play() {
    _isPlaying = true;
    _engine.startAmbient(_currentSound.id, _volume);
  }

  void pause() {
    _isPlaying = false;
    _engine.stopAmbient();
  }

  void stop() {
    pause();
  }

  /// Trigger haptic and bell chime feedback when a breath phase changes
  Future<void> onPhaseChange(BreathPhase phase) async {
    // Play gentle soothing chime tone on phase transition
    if (_currentSound.id != 'silent') {
      switch (phase) {
        case BreathPhase.inhale:
          _engine.playChime(frequency: 528.0); // Calming Solfeggio frequency
          break;
        case BreathPhase.holdIn:
          _engine.playChime(frequency: 660.0); // Gentle higher bell
          break;
        case BreathPhase.exhale:
          _engine.playChime(frequency: 440.0); // Deep releasing tone
          break;
        case BreathPhase.holdOut:
          _engine.playChime(frequency: 396.0); // Grounding tone
          break;
      }
    }

    if (_hapticEnabled) {
      try {
        switch (phase) {
          case BreathPhase.inhale:
            await HapticFeedback.selectionClick();
            await Future.delayed(const Duration(milliseconds: 120));
            await HapticFeedback.lightImpact();
            break;
          case BreathPhase.holdIn:
            await HapticFeedback.mediumImpact();
            break;
          case BreathPhase.exhale:
            await HapticFeedback.lightImpact();
            break;
          case BreathPhase.holdOut:
            await HapticFeedback.selectionClick();
            break;
        }
      } catch (_) {
        // Haptics might not be supported on desktop/web, ignore safely
      }
    }
  }

  /// Play completion chord sound / haptic
  Future<void> onSessionComplete() async {
    stop();
    _engine.playCompletionChord();

    if (_hapticEnabled) {
      try {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  void dispose() {
    _engine.dispose();
  }
}
