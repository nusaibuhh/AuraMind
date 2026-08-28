class MoodPoint {
  const MoodPoint({
    required this.timestamp,
    required this.score,
    required this.category,
    this.behavioralStatus,
  });

  final DateTime timestamp;
  final double score;
  final String category;
  final String? behavioralStatus;

  factory MoodPoint.fromJson(Map<String, dynamic> json) {
    return MoodPoint(
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      score: (json['mood_score'] as num).toDouble(),
      category: (json['category'] as String?) ?? 'normal',
      behavioralStatus: json['behavioral_status'] as String?,
    );
  }
}

class BehavioralWellbeingSummary {
  const BehavioralWellbeingSummary({
    required this.periodDays,
    required this.completedCount,
    required this.skippedCount,
    required this.pendingCount,
    required this.activeDays,
    required this.daysWithRecordedMoodAndCompletion,
    this.patternMessage,
  });

  final int periodDays;
  final int completedCount;
  final int skippedCount;
  final int pendingCount;
  final int activeDays;
  final int daysWithRecordedMoodAndCompletion;
  final String? patternMessage;

  bool get hasTaskData => completedCount + skippedCount + pendingCount > 0;

  factory BehavioralWellbeingSummary.fromJson(Map<String, dynamic> json) {
    return BehavioralWellbeingSummary(
      periodDays: (json['period_days'] as num?)?.toInt() ?? 7,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skipped_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      activeDays: (json['active_days'] as num?)?.toInt() ?? 0,
      daysWithRecordedMoodAndCompletion:
          (json['days_with_recorded_mood_and_completion'] as num?)?.toInt() ??
              0,
      patternMessage: json['pattern_message'] as String?,
    );
  }
}

class InterventionExercise {
  const InterventionExercise({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final String icon;

  factory InterventionExercise.fromJson(Map<String, dynamic> json) {
    return InterventionExercise(
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String? ?? 'self_improvement',
    );
  }
}

class Intervention {
  const Intervention({
    required this.baselineTier,
    required this.tier,
    required this.label,
    required this.message,
    required this.exercise,
  });

  final int baselineTier;
  final int tier;
  final String label;
  final String message;
  final InterventionExercise exercise;

  factory Intervention.fromJson(Map<String, dynamic> json) {
    return Intervention(
      baselineTier: (json['baseline_tier'] as num?)?.toInt() ?? 1,
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      label: json['label'] as String,
      message: json['message'] as String,
      exercise: InterventionExercise.fromJson(
        json['exercise'] as Map<String, dynamic>,
      ),
    );
  }
}

class MoodAnalytics {
  const MoodAnalytics({
    required this.periodDays,
    required this.points,
    required this.trend,
    required this.trendLabel,
    required this.isDeclining,
    required this.consecutiveDeclines,
    required this.overallChange,
    required this.slope,
    required this.intervention,
    this.behavioralSummary,
  });

  final int periodDays;
  final List<MoodPoint> points;
  final double trend;
  final String trendLabel;
  final bool isDeclining;
  final int consecutiveDeclines;
  final double overallChange;
  final double slope;
  final Intervention intervention;
  final BehavioralWellbeingSummary? behavioralSummary;

  bool get hasData => points.isNotEmpty;

  double get latestScore => points.isEmpty ? 0 : points.last.score;

  factory MoodAnalytics.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return MoodAnalytics(
      periodDays: (json['period_days'] as num?)?.toInt() ?? 7,
      points: rawPoints
          .map((item) => MoodPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      trend: (json['trend'] as num?)?.toDouble() ?? 0,
      trendLabel: json['trend_label'] as String? ?? 'Stable',
      isDeclining: json['is_declining'] as bool? ?? false,
      consecutiveDeclines: (json['consecutive_declines'] as num?)?.toInt() ?? 0,
      overallChange: (json['overall_change'] as num?)?.toDouble() ?? 0,
      slope: (json['slope'] as num?)?.toDouble() ?? 0,
      intervention: Intervention.fromJson(
        json['intervention'] as Map<String, dynamic>,
      ),
      behavioralSummary: json['behavioral_summary'] is Map
          ? BehavioralWellbeingSummary.fromJson(
              Map<String, dynamic>.from(json['behavioral_summary'] as Map),
            )
          : null,
    );
  }
}
