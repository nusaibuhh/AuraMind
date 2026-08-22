import 'package:flutter_tts/flutter_tts.dart';

/// Small wrapper around text-to-speech used by the Mood Momentum Walk.
/// If speech is unavailable on a platform/device, errors are swallowed so the
/// visual grounding instructions still keep the exercise usable.
class GroundingVoiceService {
  GroundingVoiceService() {
    _tts.setSpeechRate(0.46);
    _tts.setPitch(1.0);
  }

  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Visual cues remain available when platform speech is unavailable.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    stop();
  }
}
