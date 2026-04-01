import 'package:trendpulse/core/models/task_runtime.dart';

class Subscription {
  final String id;
  final String keyword;
  final String contentLanguage;
  final String interval;
  final int maxItems;
  final List<String> sources;
  final bool isActive;
  final bool notify;
  final String createdAt;
  final String updatedAt;
  final String? lastRunAt;
  final String? nextRunAt;
  final int unreadAlertCount;
  final String? latestUnreadAlertTaskId;
  final double? latestUnreadAlertScore;

  const Subscription({
    required this.id,
    required this.keyword,
    required this.contentLanguage,
    required this.interval,
    required this.maxItems,
    required this.sources,
    required this.isActive,
    required this.notify,
    required this.createdAt,
    required this.updatedAt,
    this.lastRunAt,
    this.nextRunAt,
    this.unreadAlertCount = 0,
    this.latestUnreadAlertTaskId,
    this.latestUnreadAlertScore,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      keyword: json['keyword'] as String,
      contentLanguage: _requireSubscriptionString(
        json,
        'content_language',
        context: 'Subscription',
      ),
      interval: json['interval'] as String? ?? 'daily',
      maxItems: (json['max_items'] as num?)?.toInt() ?? 50,
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isActive: json['is_active'] as bool? ?? true,
      notify: json['notify'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      lastRunAt: json['last_run_at'] as String?,
      nextRunAt: json['next_run_at'] as String?,
      unreadAlertCount: (json['unread_alert_count'] as num?)?.toInt() ?? 0,
      latestUnreadAlertTaskId: json['latest_unread_alert_task_id'] as String?,
      latestUnreadAlertScore:
          (json['latest_unread_alert_score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'content_language': contentLanguage,
    'interval': interval,
    'max_items': maxItems,
    'sources': sources,
    'is_active': isActive,
    'notify': notify,
  };

  String get intervalDisplayKey => switch (interval) {
    'hourly' => 'intervalHourly',
    '6hours' => 'intervalSixHours',
    'daily' => 'intervalDaily',
    'weekly' => 'intervalWeekly',
    _ => 'intervalDaily',
  };

  bool get hasUnreadAlertSummary =>
      unreadAlertCount > 0 &&
      latestUnreadAlertTaskId != null &&
      latestUnreadAlertScore != null;
}

class SubscriptionTask {
  final String id;
  final String keyword;
  final String contentLanguage;
  final String reportLanguage;
  final String status;
  final String quality;
  final String? qualitySummary;
  final List<TaskSourceOutcome> sourceOutcomes;
  final String createdAt;
  final double? sentimentScore;
  final int? postCount;
  final String? errorMessage;

  const SubscriptionTask({
    required this.id,
    required this.keyword,
    this.contentLanguage = 'en',
    this.reportLanguage = 'en',
    required this.status,
    this.quality = 'clean',
    this.qualitySummary,
    this.sourceOutcomes = const [],
    required this.createdAt,
    this.sentimentScore,
    this.postCount,
    this.errorMessage,
  });

  factory SubscriptionTask.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;
    final errorMessage = json['error_message'] as String?;
    return SubscriptionTask(
      id: json['id'] as String,
      keyword: json['keyword'] as String? ?? '',
      contentLanguage: _requireSubscriptionString(
        json,
        'content_language',
        context: 'SubscriptionTask',
      ),
      reportLanguage: _requireSubscriptionString(
        json,
        'report_language',
        context: 'SubscriptionTask',
      ),
      status: normalizeTaskStatus(rawStatus),
      quality: normalizeTaskQuality(json, rawStatus),
      qualitySummary: normalizeTaskQualitySummary(
        json,
        rawStatus,
        errorMessage,
      ),
      sourceOutcomes: parseTaskSourceOutcomes(json),
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

String _requireSubscriptionString(
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
