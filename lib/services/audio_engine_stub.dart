// Audio engine stub for platform independence
abstract class AudioEngine {
  void startAmbient(String soundId, double volume);
  void stopAmbient();
  void setVolume(double volume);
  void playChime({double frequency = 528.0});
  void playCompletionChord();
  void dispose();
}
