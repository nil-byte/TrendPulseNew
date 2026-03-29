class Subscription {
  final String id;
  final String keyword;
  final String language;
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
    required this.language,
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
      language: json['language'] as String? ?? 'en',
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
    'language': language,
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
  final String status;
  final String createdAt;
  final double? sentimentScore;
  final int? postCount;
  final String? errorMessage;

  const SubscriptionTask({
    required this.id,
    required this.keyword,
    required this.status,
    required this.createdAt,
    this.sentimentScore,
    this.postCount,
    this.errorMessage,
  });

  factory SubscriptionTask.fromJson(Map<String, dynamic> json) {
    return SubscriptionTask(
      id: json['id'] as String,
      keyword: json['keyword'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
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
