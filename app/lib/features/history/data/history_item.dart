class HistoryItem {
  final String id;
  final String keyword;
  final String status;
  final String language;
  final List<String> sources;
  final String createdAt;
  final double? sentimentScore;

  const HistoryItem({
    required this.id,
    required this.keyword,
    required this.status,
    required this.language,
    required this.sources,
    required this.createdAt,
    this.sentimentScore,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      keyword: json['keyword'] as String,
      status: json['status'] as String? ?? 'pending',
      language: json['language'] as String? ?? 'en',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['created_at'] as String? ?? '',
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble(),
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running';
}
