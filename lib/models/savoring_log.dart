enum SavoringLogStatus { draft, completed }

class SavoringEntry {
  const SavoringEntry({
    required this.position,
    required this.positiveEvent,
    required this.whyHappened,
  });

  final int position;
  final String positiveEvent;
  final String whyHappened;

  bool get isComplete =>
      positiveEvent.trim().isNotEmpty && whyHappened.trim().isNotEmpty;

  SavoringEntry copyWith({String? positiveEvent, String? whyHappened}) {
    return SavoringEntry(
      position: position,
      positiveEvent: positiveEvent ?? this.positiveEvent,
      whyHappened: whyHappened ?? this.whyHappened,
    );
  }

  factory SavoringEntry.fromJson(Map<String, dynamic> json) {
    return SavoringEntry(
      position: (json['position'] as num?)?.toInt() ?? 1,
      positiveEvent: json['positive_event'] as String? ?? '',
      whyHappened: json['why_happened'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        'positive_event': positiveEvent.trim(),
        'why_happened': whyHappened.trim(),
      };
}

class SavoringLog {
  const SavoringLog({
    required this.id,
    required this.userId,
    required this.logDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.entries,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String logDate;
  final SavoringLogStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SavoringEntry> entries;

  bool get isCompleted => status == SavoringLogStatus.completed;
  bool get canComplete =>
      entries.length == 3 && entries.every((e) => e.isComplete);

  SavoringLog copyWith({
    SavoringLogStatus? status,
    DateTime? completedAt,
    DateTime? updatedAt,
    List<SavoringEntry>? entries,
  }) {
    return SavoringLog(
      id: id,
      userId: userId,
      logDate: logDate,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entries: entries ?? this.entries,
    );
  }

  factory SavoringLog.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List? ?? const [];
    final entries = rawEntries
        .map((item) => SavoringEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updated_at'] as String? ?? '');
    final completedAt =
        DateTime.tryParse(json['completed_at'] as String? ?? '');

    return SavoringLog(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      logDate: json['log_date'] as String? ?? '',
      status: json['status'] == 'completed'
          ? SavoringLogStatus.completed
          : SavoringLogStatus.draft,
      completedAt: completedAt,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? createdAt ?? DateTime.now(),
      entries: entries,
    );
  }
}
