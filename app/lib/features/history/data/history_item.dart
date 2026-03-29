class HistoryItem {
  final String id;
  final String keyword;
  final String status;
  final String language;
  final List<String> sources;
  final String createdAt;
  final double? sentimentScore;
  final int? postCount;
  final String? errorMessage;

  const HistoryItem({
    required this.id,
    required this.keyword,
    required this.status,
    required this.language,
    required this.sources,
    required this.createdAt,
    this.sentimentScore,
    this.postCount,
    this.errorMessage,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      keyword: json['keyword'] as String,
      status: json['status'] as String? ?? 'pending',
      language: json['language'] as String? ?? 'en',
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['created_at'] as String? ?? '',
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble(),
      postCount: (json['post_count'] as num?)?.toInt(),
      errorMessage: json['error_message'] as String?,
    );
  }

  bool get isPartial => status == 'partial';
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isCollecting => status == 'collecting';
  bool get isAnalyzing => status == 'analyzing';
  bool get isFailed => status == 'failed';
  bool get isInProgress => isPending || isCollecting || isAnalyzing;
  bool get isRunning => isInProgress;
  bool get canViewReport => isCompleted || isPartial;
}
