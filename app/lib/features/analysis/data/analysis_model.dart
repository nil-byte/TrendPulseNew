class AnalysisTask {
  final String id;
  final String keyword;
  final String language;
  final int maxItems;
  final String status;
  final List<String> sources;
  final String createdAt;
  final String updatedAt;
  final String? errorMessage;
  final double? sentimentScore;
  final int? postCount;

  const AnalysisTask({
    required this.id,
    required this.keyword,
    required this.language,
    required this.maxItems,
    required this.status,
    required this.sources,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
    this.sentimentScore,
    this.postCount,
  });

  bool get isPending => status == 'pending';
  bool get isCollecting => status == 'collecting';
  bool get isAnalyzing => status == 'analyzing';
  bool get isPartial => status == 'partial';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isInProgress => isPending || isCollecting || isAnalyzing;
  bool get canViewReport => isCompleted || isPartial;

  factory AnalysisTask.fromJson(Map<String, dynamic> json) {
    return AnalysisTask(
      id: json['id'] as String,
      keyword: json['keyword'] as String,
      language: (json['language'] as String?) ?? 'en',
      maxItems: (json['max_items'] as num?)?.toInt() ?? 50,
      status: json['status'] as String,
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      errorMessage: json['error_message'] as String?,
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble(),
      postCount: (json['post_count'] as num?)?.toInt(),
    );
  }
}

class AnalysisSourceAvailability {
  final String source;
  final String status;
  final bool isAvailable;
  final String? reason;
  final String? reasonCode;
  final String? checkedAt;

  const AnalysisSourceAvailability({
    required this.source,
    required this.status,
    required this.isAvailable,
    this.reason,
    this.reasonCode,
    this.checkedAt,
  });

  bool get isDegraded => status == 'degraded';
  bool get isUnconfigured => status == 'unconfigured';

  factory AnalysisSourceAvailability.fromJson(Map<String, dynamic> json) {
    return AnalysisSourceAvailability(
      source: json['source'] as String,
      status: (json['status'] as String?) ?? 'available',
      isAvailable: json['is_available'] as bool? ?? false,
      reason: json['reason'] as String?,
      reasonCode: json['reason_code'] as String?,
      checkedAt: json['checked_at'] as String?,
    );
  }
}

class KeyInsight {
  final String text;
  final String sentiment;
  final int sourceCount;

  const KeyInsight({
    required this.text,
    required this.sentiment,
    required this.sourceCount,
  });

  factory KeyInsight.fromJson(Map<String, dynamic> json) {
    return KeyInsight(
      text: json['text'] as String,
      sentiment: (json['sentiment'] as String?) ?? 'neutral',
      sourceCount: (json['source_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AnalysisReport {
  final String id;
  final String taskId;
  final double sentimentScore;
  final double positiveRatio;
  final double negativeRatio;
  final double neutralRatio;
  final double heatIndex;
  final List<KeyInsight> keyInsights;
  final String summary;
  final String? mermaidMindmap;
  final String createdAt;

  const AnalysisReport({
    required this.id,
    required this.taskId,
    required this.sentimentScore,
    required this.positiveRatio,
    required this.negativeRatio,
    required this.neutralRatio,
    required this.heatIndex,
    required this.keyInsights,
    required this.summary,
    this.mermaidMindmap,
    required this.createdAt,
  });

  int get totalPosts {
    final total = keyInsights.fold<int>(0, (sum, i) => sum + i.sourceCount);
    return total > 0 ? total : 0;
  }

  factory AnalysisReport.fromJson(Map<String, dynamic> json) {
    return AnalysisReport(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      sentimentScore: (json['sentiment_score'] as num).toDouble(),
      positiveRatio: (json['positive_ratio'] as num).toDouble(),
      negativeRatio: (json['negative_ratio'] as num).toDouble(),
      neutralRatio: (json['neutral_ratio'] as num).toDouble(),
      heatIndex: (json['heat_index'] as num).toDouble(),
      keyInsights:
          (json['key_insights'] as List<dynamic>?)
              ?.map((e) => KeyInsight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      summary: (json['summary'] as String?) ?? '',
      mermaidMindmap: json['mermaid_mindmap'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}
