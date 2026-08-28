enum BehavioralDifficulty {
  tiny,
  easy,
  moderate,
}

enum BehavioralTaskStatus {
  pending,
  completed,
  skipped,
}

class BehavioralActivity {
  final String id;
  final String title;
  final String description;
  final String category;
  final BehavioralDifficulty difficulty;
  final int durationMinutes;

  const BehavioralActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
  });

  factory BehavioralActivity.fromJson(Map<String, dynamic> json) {
    BehavioralDifficulty diff = BehavioralDifficulty.tiny;
    final diffStr = (json['difficulty'] as String?)?.toLowerCase();
    if (diffStr == 'easy') {
      diff = BehavioralDifficulty.easy;
    } else if (diffStr == 'moderate') {
      diff = BehavioralDifficulty.moderate;
    }

    return BehavioralActivity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Self-care',
      difficulty: diff,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'difficulty': difficulty.name,
        'duration_minutes': durationMinutes,
      };
}

class BehavioralDailyTask {
  final String id;
  final String userId;
  final String activityId;
  final String taskDate;
  final BehavioralTaskStatus status;
  final DateTime? completedAt;
  final int? moodBefore;
  final int? moodAfter;
  final DateTime createdAt;
  final BehavioralActivity activity;

  const BehavioralDailyTask({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.taskDate,
    required this.status,
    this.completedAt,
    this.moodBefore,
    this.moodAfter,
    required this.createdAt,
    required this.activity,
  });

  bool get isCompleted => status == BehavioralTaskStatus.completed;
  bool get isSkipped => status == BehavioralTaskStatus.skipped;
  bool get isPending => status == BehavioralTaskStatus.pending;

  factory BehavioralDailyTask.fromJson(Map<String, dynamic> json) {
    BehavioralTaskStatus stat = BehavioralTaskStatus.pending;
    final statusStr = (json['status'] as String?)?.toLowerCase();
    if (statusStr == 'completed') {
      stat = BehavioralTaskStatus.completed;
    } else if (statusStr == 'skipped') {
      stat = BehavioralTaskStatus.skipped;
    }

    final completedAtStr = json['completed_at'] as String?;
    final createdAtStr = json['created_at'] as String?;

    return BehavioralDailyTask(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      activityId: json['activity_id'] as String? ?? '',
      taskDate: json['task_date'] as String? ?? '',
      status: stat,
      completedAt:
          completedAtStr != null ? DateTime.tryParse(completedAtStr) : null,
      moodBefore: (json['mood_before'] as num?)?.toInt(),
      moodAfter: (json['mood_after'] as num?)?.toInt(),
      createdAt: createdAtStr != null
          ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
          : DateTime.now(),
      activity: json['activity'] is Map<String, dynamic>
          ? BehavioralActivity.fromJson(
              json['activity'] as Map<String, dynamic>)
          : BehavioralActivity(
              id: json['activity_id'] as String? ?? '',
              title: 'Daily Tiny Action',
              description: 'A gentle step to brighten your day.',
              category: 'Self-care',
              difficulty: BehavioralDifficulty.tiny,
              durationMinutes: 5,
            ),
    );
  }
}

class BehavioralStats {
  final int periodDays;
  final int completedCount;
  final int skippedCount;
  final int pendingCount;
  final int totalTasks;
  final double completionRate;
  final int numberOfActiveDays;
  final int daysInPeriod;

  const BehavioralStats({
    required this.periodDays,
    required this.completedCount,
    required this.skippedCount,
    required this.pendingCount,
    required this.totalTasks,
    required this.completionRate,
    required this.numberOfActiveDays,
    required this.daysInPeriod,
  });

  factory BehavioralStats.fromJson(Map<String, dynamic> json) {
    return BehavioralStats(
      periodDays: (json['period_days'] as num?)?.toInt() ?? 7,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skipped_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      totalTasks: (json['total_tasks'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      numberOfActiveDays: (json['number_of_active_days'] as num?)?.toInt() ?? 0,
      daysInPeriod: (json['days_in_period'] as num?)?.toInt() ?? 7,
    );
  }
}
