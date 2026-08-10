enum MentalHealthCategory { depression, anxiety, stress, normal }

enum AnswerOption {
  never(0, 'Never'),
  almostNever(1, 'Almost never'),
  sometimes(2, 'Sometimes'),
  fairlyOften(3, 'Fairly often'),
  veryOften(4, 'Very often');

  const AnswerOption(this.value, this.label);
  final int value;
  final String label;
}

class Question {
  const Question({
    required this.id,
    required this.text,
    required this.category,
  });

  final int id;
  final String text;
  final MentalHealthCategory category;
}

const List<Question> checkInQuestions = [
  Question(
    id: 1,
    text: 'Little interest or pleasure in doing things',
    category: MentalHealthCategory.depression,
  ),
  Question(
    id: 2,
    text: 'Trouble falling or staying asleep, or sleeping too much',
    category: MentalHealthCategory.depression,
  ),
  Question(
    id: 3,
    text: 'Poor appetite or overeating',
    category: MentalHealthCategory.depression,
  ),
  Question(
    id: 4,
    text:
        'Trouble concentrating on things, such as reading or watching TV',
    category: MentalHealthCategory.depression,
  ),
  Question(
    id: 5,
    text: 'Feeling nervous, anxious, or on edge',
    category: MentalHealthCategory.anxiety,
  ),
  Question(
    id: 6,
    text: 'Not being able to stop or control worrying',
    category: MentalHealthCategory.anxiety,
  ),
  Question(
    id: 7,
    text: 'Trouble relaxing',
    category: MentalHealthCategory.anxiety,
  ),
  Question(
    id: 8,
    text: 'Becoming easily annoyed or irritable',
    category: MentalHealthCategory.anxiety,
  ),
  Question(
    id: 9,
    text:
        'Felt that you were unable to control the important things in your life',
    category: MentalHealthCategory.stress,
  ),
  Question(
    id: 10,
    text:
        'Felt not confident about your ability to handle your personal problems',
    category: MentalHealthCategory.stress,
  ),
  Question(
    id: 11,
    text: 'Felt that things were not going your way',
    category: MentalHealthCategory.stress,
  ),
  Question(
    id: 12,
    text:
        'Felt difficulties were piling up so high that you could not overcome them',
    category: MentalHealthCategory.stress,
  ),
];
