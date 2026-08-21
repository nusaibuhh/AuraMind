import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MuscleRelaxationScreen extends StatefulWidget {
  const MuscleRelaxationScreen({super.key});

  @override
  State<MuscleRelaxationScreen> createState() => _MuscleRelaxationScreenState();
}

class _MuscleRelaxationScreenState extends State<MuscleRelaxationScreen> {
  final FlutterTts _tts = FlutterTts();

  static const _steps = <_RelaxationStep>[
    _RelaxationStep(
      label: 'Face',
      title: 'Relax your forehead',
      icon: Icons.sentiment_satisfied_alt_rounded,
      seconds: 35,
      instruction:
          'Gently raise your eyebrows and tighten the muscles in your forehead. '
          'Hold for five seconds without straining. Now release completely and '
          'notice the difference between tension and relaxation.',
    ),
    _RelaxationStep(
      label: 'Jaw',
      title: 'Soften your jaw',
      icon: Icons.face_rounded,
      seconds: 35,
      instruction:
          'Gently tighten your jaw without clenching your teeth. Hold for five '
          'seconds. Release slowly, let your lips part slightly, and allow your '
          'face to feel loose and comfortable.',
    ),
    _RelaxationStep(
      label: 'Shoulders',
      title: 'Drop your shoulders',
      icon: Icons.accessibility_new_rounded,
      seconds: 40,
      instruction:
          'Lift your shoulders gently toward your ears. Hold the tension for '
          'five seconds. Now let them drop. Feel the heaviness leave your neck '
          'and shoulders as you breathe out.',
    ),
    _RelaxationStep(
      label: 'Arms',
      title: 'Release your arms and hands',
      icon: Icons.back_hand_rounded,
      seconds: 40,
      instruction:
          'Make a gentle fist and tighten your arms. Hold for five seconds. '
          'Release your fingers, open your hands, and let your arms rest. '
          'Notice the warmth and softness returning.',
    ),
    _RelaxationStep(
      label: 'Core',
      title: 'Relax your chest and abdomen',
      icon: Icons.favorite_outline_rounded,
      seconds: 40,
      instruction:
          'Take a slow breath in and gently tighten your abdominal muscles. '
          'Hold briefly without holding your breath. Breathe out and release, '
          'allowing your chest and abdomen to become soft.',
    ),
    _RelaxationStep(
      label: 'Legs',
      title: 'Let your legs become heavy',
      icon: Icons.directions_walk_rounded,
      seconds: 40,
      instruction:
          'Gently tighten your thighs and calves. Hold for five seconds. '
          'Release the tension slowly and feel your legs become heavier and '
          'more relaxed.',
    ),
    _RelaxationStep(
      label: 'Feet',
      title: 'Finish with your feet',
      icon: Icons.spa_rounded,
      seconds: 35,
      instruction:
          'Curl your toes gently and tense the muscles in your feet. Hold for '
          'five seconds. Release completely. Take one slow breath and notice '
          'how your whole body feels from head to toe.',
    ),
  ];

  Timer? _timer;
  int _stepIndex = 0;
  int _stepElapsed = 0;
  int _totalElapsed = 0;
  bool _playing = false;
  bool _completed = false;

  int get _totalDuration => _steps.fold(0, (sum, step) => sum + step.seconds);

  _RelaxationStep get _currentStep => _steps[_stepIndex];

  double get _overallProgress {
    if (_totalDuration == 0) return 0;
    return (_totalElapsed / _totalDuration).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.43);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speakCurrentStep() async {
    await _tts.stop();
    await _tts.speak(
      '${_currentStep.title}. ${_currentStep.instruction}',
    );
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      _timer?.cancel();
      await _tts.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }

    if (_completed) {
      setState(() {
        _completed = false;
        _stepIndex = 0;
        _stepElapsed = 0;
        _totalElapsed = 0;
      });
    }

    setState(() => _playing = true);
    await _speakCurrentStep();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_playing) return;

      setState(() {
        _stepElapsed += 1;
        _totalElapsed = (_totalElapsed + 1).clamp(0, _totalDuration);
      });

      if (_stepElapsed >= _currentStep.seconds) {
        _advanceAutomatically();
      }
    });
  }

  Future<void> _advanceAutomatically() async {
    if (_stepIndex >= _steps.length - 1) {
      _timer?.cancel();
      await _tts.stop();

      if (!mounted) return;
      setState(() {
        _playing = false;
        _completed = true;
        _totalElapsed = _totalDuration;
      });

      await _tts.speak(
        'Your progressive muscle relaxation session is complete. '
        'Take one slow breath and notice how your body feels.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relaxation session complete.')),
      );
      return;
    }

    setState(() {
      _stepIndex += 1;
      _stepElapsed = 0;
    });
    await _speakCurrentStep();
  }

  Future<void> _selectStep(int index) async {
    if (index < 0 || index >= _steps.length) return;

    final elapsedBefore =
        _steps.take(index).fold<int>(0, (sum, step) => sum + step.seconds);

    setState(() {
      _stepIndex = index;
      _stepElapsed = 0;
      _totalElapsed = elapsedBefore;
      _completed = false;
    });

    if (_playing) {
      await _speakCurrentStep();
    }
  }

  Future<void> _previousStep() async {
    if (_stepIndex == 0) return;
    await _selectStep(_stepIndex - 1);
  }

  Future<void> _nextStep() async {
    if (_stepIndex >= _steps.length - 1) {
      await _advanceAutomatically();
      return;
    }
    await _selectStep(_stepIndex + 1);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF3B273E);
    const panel = Color(0xFF4A3150);
    const accent = Color(0xFFDAB7E2);
    const muted = Color(0xFFBDAFC1);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Muscle relaxation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _formatTime(_totalElapsed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(_totalDuration),
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: _overallProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.13),
                      valueColor: const AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _steps.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final selected = index == _stepIndex;
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (_) => _selectStep(index),
                          label: Text(_steps[index].label),
                          labelStyle: TextStyle(
                            color: selected
                                ? const Color(0xFF3B273E)
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          selectedColor: accent,
                          backgroundColor: panel,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                child: Column(
                  children: [
                    Container(
                      width: 226,
                      height: 226,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.36),
                            panel,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 35,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(
                        _currentStep.icon,
                        size: 102,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _currentStep.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _currentStep.instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundControl(
                          icon: Icons.skip_previous_rounded,
                          onTap: _stepIndex == 0 ? null : _previousStep,
                        ),
                        const SizedBox(width: 22),
                        Material(
                          color: accent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _togglePlayback,
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                              width: 78,
                              height: 78,
                              child: Icon(
                                _playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 42,
                                color: background,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 22),
                        _RoundControl(
                          icon: Icons.skip_next_rounded,
                          onTap: _nextStep,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.health_and_safety_outlined,
                            color: accent,
                            size: 21,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Keep every contraction gentle. Stop the exercise '
                              'if you feel pain, dizziness, numbness, or unusual '
                              'discomfort.',
                              style: TextStyle(
                                color: muted,
                                height: 1.4,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? 0.05 : 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: onTap == null ? 0.28 : 0.85),
          ),
        ),
      ),
    );
  }
}

class _RelaxationStep {
  const _RelaxationStep({
    required this.label,
    required this.title,
    required this.icon,
    required this.seconds,
    required this.instruction,
  });

  final String label;
  final String title;
  final IconData icon;
  final int seconds;
  final String instruction;
}
