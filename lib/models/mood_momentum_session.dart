class GroundingCue {
  const GroundingCue({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

class MoodMomentumSessionConfig {
  const MoodMomentumSessionConfig({
    required this.minutes,
    required this.stepGoal,
  });

  final int minutes;
  final int stepGoal;

  int get totalSeconds => minutes * 60;

  static const fiveMinutes = MoodMomentumSessionConfig(
    minutes: 5,
    stepGoal: 500,
  );

  static const tenMinutes = MoodMomentumSessionConfig(
    minutes: 10,
    stepGoal: 1000,
  );
}
