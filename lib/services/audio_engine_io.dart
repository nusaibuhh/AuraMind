import 'audio_engine_stub.dart';

class IOAudioEngine implements AudioEngine {
  @override
  void startAmbient(String soundId, double volume) {}

  @override
  void stopAmbient() {}

  @override
  void setVolume(double volume) {}

  @override
  void playChime({double frequency = 528.0}) {}

  @override
  void playCompletionChord() {}

  @override
  void dispose() {}
}

AudioEngine createAudioEngine() => IOAudioEngine();
