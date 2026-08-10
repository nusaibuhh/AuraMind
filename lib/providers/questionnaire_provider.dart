import 'package:flutter/foundation.dart';

import '../models/question.dart';
import '../models/theme_palette.dart';
import '../services/api_service.dart';
import '../utils/scoring.dart';

class QuestionnaireProvider extends ChangeNotifier {
  final Map<int, AnswerOption> _answers = {};
  int _currentIndex = 0;
  ScoringResult? _result;
  List<ThemePalette>? _recommendedThemes;
  bool _isSubmitting = false;
  String? _submitError;

  Map<int, AnswerOption> get answers => Map.unmodifiable(_answers);
  int get currentIndex => _currentIndex;
  int get totalQuestions => checkInQuestions.length;
  Question get currentQuestion => checkInQuestions[_currentIndex];
  bool get hasAnswer => _answers.containsKey(currentQuestion.id);
  AnswerOption? get currentAnswer => _answers[currentQuestion.id];
  ScoringResult? get result => _result;
  List<ThemePalette>? get recommendedThemes => _recommendedThemes;
  bool get isSubmitting => _isSubmitting;
  String? get submitError => _submitError;

  double get progress => (_currentIndex + 1) / totalQuestions;

  void selectAnswer(AnswerOption option) {
    _answers[currentQuestion.id] = option;
    notifyListeners();
  }

  bool nextQuestion() {
    if (!hasAnswer) return false;
    if (_currentIndex < totalQuestions - 1) {
      _currentIndex++;
      notifyListeners();
      return true;
    }
    return false;
  }

  void previousQuestion() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  Future<ScoringResult?> completeQuestionnaire(ApiService api) async {
    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    try {
      final response = await api.submitCheckin(_answers);
      _result = response.result;
      _recommendedThemes = response.palettes;
      notifyListeners();
      return _result;
    } on ApiException catch (e) {
      _submitError = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _submitError = 'Could not connect to server. Is the backend running?';
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void reset() {
    _answers.clear();
    _currentIndex = 0;
    _result = null;
    _recommendedThemes = null;
    _submitError = null;
    notifyListeners();
  }
}
