class TaskSourceOutcome {
  final String source;
  final String status;
  final int postCount;
  final String? reason;
  final String? reasonCode;

  const TaskSourceOutcome({
    required this.source,
    required this.status,
    this.postCount = 0,
    this.reason,
    this.reasonCode,
  });

  bool get isIssue =>
      status == 'degraded' || status == 'unavailable' || status == 'failed';

  factory TaskSourceOutcome.fromJson(Map<String, dynamic> json) {
    return TaskSourceOutcome(
      source: json['source'] as String,
      status: (json['status'] as String?) ?? 'success',
      postCount: (json['post_count'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      reasonCode: json['reason_code'] as String?,
    );
  }
}

String normalizeTaskStatus(String? rawStatus) {
  final status = rawStatus ?? 'pending';
  return status == 'partial' ? 'completed' : status;
}

String normalizeTaskQuality(Map<String, dynamic> json, String? rawStatus) {
  final quality = json['quality'] as String?;
  if (quality != null && quality.isNotEmpty) {
    return quality;
  }
  return rawStatus == 'partial' ? 'degraded' : 'clean';
}

String? normalizeTaskQualitySummary(
  Map<String, dynamic> json,
  String? rawStatus,
  String? errorMessage,
) {
  final summary = json['quality_summary'] as String?;
  if (summary != null && summary.isNotEmpty) {
    return summary;
  }
  return rawStatus == 'partial' ? errorMessage : null;
}

List<TaskSourceOutcome> parseTaskSourceOutcomes(Map<String, dynamic> json) {
  final raw = json['source_outcomes'];
  if (raw is! List<dynamic>) {
    return const [];
  }
  return raw
      .whereType<Map<String, dynamic>>()
      .map(TaskSourceOutcome.fromJson)
      .toList(growable: false);
}
