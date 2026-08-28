class BestSelfVision {
  const BestSelfVision({
    required this.id,
    required this.timeline,
    required this.vision,
    required this.createdAt,
  });

  final String id;
  final int timeline;
  final String vision;
  final DateTime createdAt;

  factory BestSelfVision.fromJson(Map<String, dynamic> json) => BestSelfVision(
        id: json['id'] as String,
        timeline: (json['timeline'] as num?)?.toInt() ?? 3,
        vision: json['vision'] as String? ?? '',
        createdAt: DateTime.tryParse(
              (json['createdAt'] ?? json['created_at']) as String? ?? '',
            ) ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timeline': timeline,
        'vision': vision,
        'createdAt': createdAt.toIso8601String(),
      };
}
