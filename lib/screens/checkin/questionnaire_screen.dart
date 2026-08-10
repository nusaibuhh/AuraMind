import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/question.dart';
import '../../providers/questionnaire_provider.dart';
import '../../providers/auth_provider.dart';
import 'analyzing_screen.dart';

class QuestionnaireScreen extends StatelessWidget {
  const QuestionnaireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _QuestionnaireView();
  }
}

class _QuestionnaireView extends StatelessWidget {
  const _QuestionnaireView();

  Future<void> _finish(BuildContext context) async {
    final provider = context.read<QuestionnaireProvider>();
    final api = context.read<AuthProvider>().api;

    final result = await provider.completeQuestionnaire(api);
    if (!context.mounted) return;

    if (result == null) {
      final message = provider.submitError ?? 'Could not submit check-in';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AnalyzingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuestionnaireProvider>();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final question = provider.currentQuestion;
    final isLast = provider.currentIndex == provider.totalQuestions - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: provider.progress,
                        backgroundColor: const Color(0xFFE8F1E8),
                        color: const Color(0xFF4AA564),
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${provider.currentIndex + 1}/${provider.totalQuestions}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'During the past week...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.text,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...AnswerOption.values.map(
                      (option) => _ChoiceTile(
                        label: option.label,
                        isSelected: provider.currentAnswer == option,
                        onTap: () => provider.selectAnswer(option),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (provider.currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: provider.previousQuestion,
                        child: const Text('Previous'),
                      ),
                    ),
                  if (provider.currentIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: provider.hasAnswer
                          ? () {
                              if (isLast) {
                                _finish(context);
                              } else {
                                provider.nextQuestion();
                              }
                            }
                          : null,
                      child: Text(isLast ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = const Color(0xFF4AA564);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? primary : const Color(0xFFD8E1D8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? primary : const Color(0xFFB7C5B7),
                      width: 2,
                    ),
                    color: isSelected ? primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.circle,
                          size: 8,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
