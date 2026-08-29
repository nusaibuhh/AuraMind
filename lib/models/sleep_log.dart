enum SleepQuality { poor, fair, okay, good, excellent }

// Keep new values at the end so records already stored as 0, 1, and 2 retain
// their original tired, normal, and refreshed meanings.
enum PostWakeFeeling { tired, normal, refreshed, annoyed }

class SleepLog {
  final String id;
  final String userId;
  final DateTime date;
  final int sleepHours;
  final int sleepMinutes;
  final SleepQuality quality;
  final PostWakeFeeling postWakeFeeling;
  final String? notes;
  final DateTime createdAt;

  SleepLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.sleepHours,
    required this.sleepMinutes,
    required this.quality,
    required this.postWakeFeeling,
    this.notes,
    required this.createdAt,
  });

  /// Total sleep in minutes
  int get totalMinutes => sleepHours * 60 + sleepMinutes;

  /// Total sleep in hours (as decimal)
  double get totalHours => totalMinutes / 60;

  /// Quality as numeric score (0-4, maps to enum values)
  int get qualityScore => quality.index;

  factory SleepLog.fromJson(Map<String, dynamic> json) {
    return SleepLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      sleepHours: json['sleep_hours'] as int,
      sleepMinutes: json['sleep_minutes'] as int,
      quality: SleepQuality.values[json['quality'] as int],
      postWakeFeeling: PostWakeFeeling.values[json['post_wake_feeling'] as int],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'date': date.toIso8601String(),
        'sleep_hours': sleepHours,
        'sleep_minutes': sleepMinutes,
        'quality': quality.index,
        'post_wake_feeling': postWakeFeeling.index,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Aggregated sleep metrics for a given period
class SleepMetrics {
  final double averageSleep; // hours
  final double averageQuality; // 0-4 scale
  final int totalEntries;
  final List<SleepLog> entries;

  SleepMetrics({
    required this.averageSleep,
    required this.averageQuality,
    required this.totalEntries,
    required this.entries,
  });

  /// Calculate trend (positive means improving)
  double getTrend() {
    if (entries.length < 2) return 0.0;
    final recentHalf = (entries.length / 2).ceil();
    final olderAvg =
        entries.sublist(0, entries.length - recentHalf).fold<double>(
                  0,
                  (sum, log) => sum + log.totalHours,
                ) /
            (entries.length - recentHalf);
    final recentAvg = entries.sublist(entries.length - recentHalf).fold<double>(
              0,
              (sum, log) => sum + log.totalHours,
            ) /
        recentHalf;
    return recentAvg - olderAvg;
  }
}

/// Correlation data between sleep and mood
class SleepMoodCorrelation {
  final DateTime date;
  final double sleepHours;
  final double moodScore; // 0-10 scale
  final String? behavioralStatus;
  final String? behavioralActivityTitle;

  SleepMoodCorrelation({
    required this.date,
    required this.sleepHours,
    required this.moodScore,
    this.behavioralStatus,
    this.behavioralActivityTitle,
  });

  bool get hasBehavioralActivity => behavioralStatus != null;
  bool get behavioralActivityCompleted => behavioralStatus == 'completed';

  factory SleepMoodCorrelation.fromJson(Map<String, dynamic> json) {
    return SleepMoodCorrelation(
      date: DateTime.parse(json['date'] as String),
      sleepHours: (json['sleep_hours'] as num).toDouble(),
      moodScore: (json['mood_score'] as num).toDouble(),
      behavioralStatus: json['behavioral_status'] as String?,
      behavioralActivityTitle: json['behavioral_activity_title'] as String?,
    );
  }
}

/// Wellbeing warning triggered by sleep-mood correlation
class WellbeingWarning {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isDismissed;

  WellbeingWarning({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isDismissed = false,
  });

  factory WellbeingWarning.fromJson(Map<String, dynamic> json) {
    return WellbeingWarning(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isDismissed: json['is_dismissed'] as bool? ?? false,
    );
  }
}
