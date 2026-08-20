import 'package:flutter/material.dart';

/// Phases of a breath cycle
enum BreathPhase {
  inhale,
  holdIn,
  exhale,
  holdOut;

  String get label {
    switch (this) {
      case BreathPhase.inhale:
        return 'Inhale';
      case BreathPhase.holdIn:
        return 'Hold';
      case BreathPhase.exhale:
        return 'Exhale';
      case BreathPhase.holdOut:
        return 'Hold';
    }
  }

  String get instruction {
    switch (this) {
      case BreathPhase.inhale:
        return 'Breathe in slowly through your nose';
      case BreathPhase.holdIn:
        return 'Hold your breath gently';
      case BreathPhase.exhale:
        return 'Release your breath smoothly';
      case BreathPhase.holdOut:
        return 'Rest and stay empty';
    }
  }
}

/// Breathing technique configuration
class BreathingTechnique {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final int inhaleSeconds;
  final int holdInSeconds;
  final int exhaleSeconds;
  final int holdOutSeconds;
  final int defaultCycles;

  const BreathingTechnique({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.inhaleSeconds,
    required this.holdInSeconds,
    required this.exhaleSeconds,
    required this.holdOutSeconds,
    this.defaultCycles = 4,
  });

  int get cycleDurationSeconds =>
      inhaleSeconds + holdInSeconds + exhaleSeconds + holdOutSeconds;

  String get rhythmSummary =>
      '$inhaleSeconds-$holdInSeconds-$exhaleSeconds-$holdOutSeconds';

  static const boxBreathing = BreathingTechnique(
    id: 'box_breathing',
    name: 'Box Breathing',
    subtitle: '4-4-4-4 Rhythm',
    description:
        'Equalized 4-second phases for rapid calming and autonomic nervous system balance.',
    inhaleSeconds: 4,
    holdInSeconds: 4,
    exhaleSeconds: 4,
    holdOutSeconds: 4,
    defaultCycles: 4,
  );

  static const relaxing478 = BreathingTechnique(
    id: 'relaxing_478',
    name: '4-7-8 Relaxing Breath',
    subtitle: '4-7-8 Rhythm',
    description:
        'Deep relaxation technique scientifically designed to ease anxiety and promote sleep.',
    inhaleSeconds: 4,
    holdInSeconds: 7,
    exhaleSeconds: 8,
    holdOutSeconds: 0,
    defaultCycles: 4,
  );

  static const deepCalm = BreathingTechnique(
    id: 'deep_calm',
    name: 'Deep Calm',
    subtitle: '4-2-6-2 Rhythm',
    description:
        'Extended exhalation activates the parasympathetic rest-and-digest response.',
    inhaleSeconds: 4,
    holdInSeconds: 2,
    exhaleSeconds: 6,
    holdOutSeconds: 2,
    defaultCycles: 5,
  );

  static const energizing = BreathingTechnique(
    id: 'energizing',
    name: 'Awake & Energize',
    subtitle: '4-2-4-0 Rhythm',
    description:
        'Invigorating breath to boost oxygen circulation, alertness, and focus.',
    inhaleSeconds: 4,
    holdInSeconds: 2,
    exhaleSeconds: 4,
    holdOutSeconds: 0,
    defaultCycles: 6,
  );

  static const List<BreathingTechnique> all = [
    boxBreathing,
    relaxing478,
    deepCalm,
    energizing,
  ];

  static BreathingTechnique fromId(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => boxBreathing);
  }
}

/// Ambient background sounds
class BackgroundSound {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String emoji;

  const BackgroundSound({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emoji,
  });

  static const ocean = BackgroundSound(
    id: 'ocean',
    title: 'Ocean Waves',
    subtitle: 'Rhythmic tides and coastal breeze',
    icon: Icons.waves_rounded,
    emoji: '🌊',
  );

  static const rain = BackgroundSound(
    id: 'rain',
    title: 'Calming Rain',
    subtitle: 'Gentle raindrops falling on leaves',
    icon: Icons.water_drop_outlined,
    emoji: '🌧️',
  );

  static const forest = BackgroundSound(
    id: 'forest',
    title: 'Forest Stream',
    subtitle: 'Soothing water & peaceful birds',
    icon: Icons.forest_outlined,
    emoji: '🍃',
  );

  static const bowl = BackgroundSound(
    id: 'bowl',
    title: 'Singing Bowl',
    subtitle: 'Harmonic resonant zen meditation tone',
    icon: Icons.self_improvement_rounded,
    emoji: '🧘',
  );

  static const wind = BackgroundSound(
    id: 'wind',
    title: 'Gentle Breeze',
    subtitle: 'Soft ambient wind and stillness',
    icon: Icons.air_rounded,
    emoji: '💨',
  );

  static const silent = BackgroundSound(
    id: 'silent',
    title: 'Silent Mode',
    subtitle: 'Pure silence for undisturbed focus',
    icon: Icons.volume_off_rounded,
    emoji: '🔇',
  );

  static const List<BackgroundSound> all = [
    ocean,
    rain,
    forest,
    bowl,
    wind,
    silent,
  ];

  static BackgroundSound fromId(String id) {
    return all.firstWhere((s) => s.id == id, orElse: () => ocean);
  }
}

/// A logged breathing session
class BreathingSession {
  final String id;
  final String userId;
  final String technique;
  final int durationSeconds;
  final int cyclesCompleted;
  final String? backgroundSound;
  final String? moodAfter;
  final DateTime createdAt;

  BreathingSession({
    required this.id,
    required this.userId,
    required this.technique,
    required this.durationSeconds,
    required this.cyclesCompleted,
    this.backgroundSound,
    this.moodAfter,
    required this.createdAt,
  });

  int get durationMinutes => (durationSeconds / 60).ceil();

  factory BreathingSession.fromJson(Map<String, dynamic> json) {
    return BreathingSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      technique: json['technique'] as String,
      durationSeconds: json['duration_seconds'] as int,
      cyclesCompleted: json['cycles_completed'] as int,
      backgroundSound: json['background_sound'] as String?,
      moodAfter: json['mood_after'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'technique': technique,
        'duration_seconds': durationSeconds,
        'cycles_completed': cyclesCompleted,
        'background_sound': backgroundSound,
        'mood_after': moodAfter,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Aggregated breathing metrics
class BreathingMetrics {
  final int totalSessions;
  final int totalSeconds;
  final double totalMinutes;
  final int totalCycles;
  final double todayMinutes;
  final String favoriteTechnique;
  final String favoriteSound;

  BreathingMetrics({
    required this.totalSessions,
    required this.totalSeconds,
    required this.totalMinutes,
    required this.totalCycles,
    required this.todayMinutes,
    required this.favoriteTechnique,
    required this.favoriteSound,
  });

  factory BreathingMetrics.fromJson(Map<String, dynamic> json) {
    return BreathingMetrics(
      totalSessions: json['total_sessions'] as int? ?? 0,
      totalSeconds: json['total_seconds'] as int? ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toDouble() ?? 0.0,
      totalCycles: json['total_cycles'] as int? ?? 0,
      todayMinutes: (json['today_minutes'] as num?)?.toDouble() ?? 0.0,
      favoriteTechnique:
          json['favorite_technique'] as String? ?? 'Box Breathing',
      favoriteSound: json['favorite_sound'] as String? ?? 'Ocean Waves',
    );
  }
}
