import '../models/question.dart';

class ScoringResult {
  const ScoringResult({
    required this.depressionScore,
    required this.anxietyScore,
    required this.stressScore,
    required this.dominantCategory,
  });

  final int depressionScore;
  final int anxietyScore;
  final int stressScore;
  final MentalHealthCategory dominantCategory;

  int scoreFor(MentalHealthCategory category) {
    switch (category) {
      case MentalHealthCategory.depression:
        return depressionScore;
      case MentalHealthCategory.anxiety:
        return anxietyScore;
      case MentalHealthCategory.stress:
        return stressScore;
      case MentalHealthCategory.normal:
        return 0;
    }
  }

  String get categoryLabel {
    switch (dominantCategory) {
      case MentalHealthCategory.depression:
        return 'Depression';
      case MentalHealthCategory.anxiety:
        return 'Anxiety';
      case MentalHealthCategory.stress:
        return 'Stress';
      case MentalHealthCategory.normal:
        return 'Balanced';
    }
  }
}

const int _scoreThreshold = 8;

ScoringResult calculateScores(Map<int, AnswerOption> answers) {
  var depression = 0;
  var anxiety = 0;
  var stress = 0;

  for (final question in checkInQuestions) {
    final answer = answers[question.id];
    if (answer == null) continue;

    switch (question.category) {
      case MentalHealthCategory.depression:
        depression += answer.value;
      case MentalHealthCategory.anxiety:
        anxiety += answer.value;
      case MentalHealthCategory.stress:
        stress += answer.value;
      case MentalHealthCategory.normal:
        break;
    }
  }

  final scores = {
    MentalHealthCategory.depression: depression,
    MentalHealthCategory.anxiety: anxiety,
    MentalHealthCategory.stress: stress,
  };

  final highestEntry = scores.entries.reduce(
    (a, b) => a.value >= b.value ? a : b,
  );

  final dominantCategory = highestEntry.value >= _scoreThreshold
      ? highestEntry.key
      : MentalHealthCategory.normal;

  return ScoringResult(
    depressionScore: depression,
    anxietyScore: anxiety,
    stressScore: stress,
    dominantCategory: dominantCategory,
  );
}
