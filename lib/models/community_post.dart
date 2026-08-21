class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorAlias,
    required this.content,
    required this.createdAt,
    required this.reportCount,
  });

  final String id;
  final String authorAlias;
  final String content;
  final DateTime createdAt;
  final int reportCount;

  static DateTime _parseCreatedAt(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return DateTime.now();

    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    final hasTimezone = normalized.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(normalized);

    final parsed = DateTime.tryParse(
      hasTimezone ? normalized : '${normalized}Z',
    );

    return parsed?.toLocal() ?? DateTime.now();
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      authorAlias: json['author_alias'] as String? ?? 'Anonymous',
      content: json['content'] as String? ?? '',
      createdAt: _parseCreatedAt(json['created_at']),
      reportCount: json['report_count'] as int? ?? 0,
    );
  }
}
