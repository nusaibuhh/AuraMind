import 'package:flutter/material.dart';

import '../behavioral_activation/behavioral_activation_screen.dart';
import '../best_self/best_self_canvas_screen.dart';
import '../breathing/breathing_screen.dart';
import '../grounding/grounding_screen.dart';
import '../kindness/kindness_wheel_screen.dart';
import '../momentum/mood_momentum_walk_screen.dart';
import '../relaxation/muscle_relaxation_screen.dart';
import '../savoring/savoring_log_screen.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exercises = [
      (
        "Today's Tiny Step",
        'Pick one small, manageable action for your day.',
        Icons.wb_sunny_outlined,
        const Color(0xFF52875C),
        const Color(0xFFE8F1E9),
        const BehavioralActivationScreen(),
      ),
      (
        'Three Good Things',
        'Notice and reflect on three positive moments from today.',
        Icons.auto_awesome_rounded,
        const Color(0xFFC88722),
        const Color(0xFFFFF3E0),
        const SavoringLogScreen(),
      ),
      (
        'Breathing Exercise',
        'Slow down with a guided breathing practice.',
        Icons.air_rounded,
        const Color(0xFF507C67),
        const Color(0xFFE7F1E8),
        const BreathingScreen(),
      ),
      (
        'Grounding 5-4-3-2-1',
        'Reconnect with the present through your senses.',
        Icons.visibility_outlined,
        const Color(0xFF8A74B8),
        const Color(0xFFF3EEFA),
        const GroundingScreen(),
      ),
      (
        'Mood Momentum Walk',
        'Build gentle momentum with a mindful walk.',
        Icons.directions_walk_rounded,
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
        const MoodMomentumWalkScreen(),
      ),
      (
        'Best Possible Self',
        'Imagine the future you want to grow toward.',
        Icons.auto_awesome_rounded,
        const Color(0xFFD39B42),
        const Color(0xFFFFF8E7),
        const BestSelfCanvasScreen(),
      ),
      (
        'Muscle Relaxation',
        'Release tension with a guided body scan.',
        Icons.self_improvement_rounded,
        const Color(0xFF694A70),
        const Color(0xFFF3EAF5),
        const MuscleRelaxationScreen(),
      ),
      (
        'Kindness Wheel',
        'Choose one small act of kindness.',
        Icons.favorite_rounded,
        const Color(0xFFD16A7A),
        const Color(0xFFFCECEF),
        const KindnessWheelScreen(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: exercises.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = exercises[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                backgroundColor: item.$5,
                child: Icon(item.$3, color: item.$4),
              ),
              title: Text(
                item.$1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(item.$2),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item.$6),
              ),
            ),
          );
        },
      ),
    );
  }
}
