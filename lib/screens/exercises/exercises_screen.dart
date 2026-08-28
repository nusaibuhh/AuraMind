import 'package:flutter/material.dart';

import '../best_self/best_self_canvas_screen.dart';
import '../breathing/breathing_screen.dart';
import '../grounding/grounding_screen.dart';
import '../momentum/mood_momentum_walk_screen.dart';
import '../relaxation/muscle_relaxation_screen.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exercises = [
      ('Breathing Exercise', 'Slow down with a guided breathing practice.', Icons.air_rounded, const BreathingScreen()),
      ('Grounding 5-4-3-2-1', 'Reconnect with the present through your senses.', Icons.visibility_outlined, const GroundingScreen()),
      ('Mood Momentum Walk', 'Build gentle momentum with a mindful walk.', Icons.directions_walk_rounded, const MoodMomentumWalkScreen()),
      ('Best Possible Self', 'Imagine the future you want to grow toward.', Icons.auto_awesome_rounded, const BestSelfCanvasScreen()),
      ('Muscle Relaxation', 'Release tension with a guided body scan.', Icons.self_improvement_rounded, const MuscleRelaxationScreen()),
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
              leading: CircleAvatar(backgroundColor: const Color(0xFFE7F1E8), child: Icon(item.$3, color: const Color(0xFF507C67))),
              title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(item.$2)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.$4)),
            ),
          );
        },
      ),
    );
  }
}
