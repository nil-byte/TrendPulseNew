import 'package:trendpulse/core/models/task_runtime.dart';

class HistoryItem {
  final String id;
  final String keyword;
  final String status;
  final String quality;
  final String? qualitySummary;
  final List<TaskSourceOutcome> sourceOutcomes;
  final String contentLanguage;
  final String reportLanguage;
  final List<String> sources;
  final String createdAt;
  final double? sentimentScore;
  final int? postCount;
  final String? errorMessage;

  const HistoryItem({
    required this.id,
    required this.keyword,
    required this.status,
    this.quality = 'clean',
    this.qualitySummary,
    this.sourceOutcomes = const [],
    required this.contentLanguage,
    required this.reportLanguage,
    required this.sources,
    required this.createdAt,
    this.sentimentScore,
    this.postCount,
    this.errorMessage,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;
    final errorMessage = json['error_message'] as String?;
    return HistoryItem(
      id: json['id'] as String,
      keyword: json['keyword'] as String,
      status: normalizeTaskStatus(rawStatus),
      quality: normalizeTaskQuality(json, rawStatus),
      qualitySummary: normalizeTaskQualitySummary(
        json,
        rawStatus,
        errorMessage,
      ),
      sourceOutcomes: parseTaskSourceOutcomes(json),
      contentLanguage: _requireHistoryString(
        json,
        'content_language',
        context: 'HistoryItem',
      ),
      reportLanguage: _requireHistoryString(
        json,
        'report_language',
        context: 'HistoryItem',
      ),
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['created_at'] as String? ?? '',
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble(),
      postCount: (json['post_count'] as num?)?.toInt(),
      errorMessage: errorMessage,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isDegraded => quality == 'degraded';
  bool get isPartial => isCompleted && isDegraded;
  bool get isPending => status == 'pending';
  bool get isCollecting => status == 'collecting';
  bool get isAnalyzing => status == 'analyzing';
  bool get isFailed => status == 'failed';
  bool get isInProgress => isPending || isCollecting || isAnalyzing;
  bool get isRunning => isInProgress;
  bool get canViewReport => isCompleted;
  List<TaskSourceOutcome> get issueSourceOutcomes =>
      sourceOutcomes.where((item) => item.isIssue).toList(growable: false);
}

String _requireHistoryString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Missing or invalid "$key" in $context JSON.');
}
