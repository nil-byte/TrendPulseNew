class SourcePost {
  final String id;
  final String taskId;
  final String source;
  final String? sourceId;
  final String? author;
  final String content;
  final String? url;
  final int engagement;
  final String? publishedAt;
  final String collectedAt;

  const SourcePost({
    required this.id,
    required this.taskId,
    required this.source,
    this.sourceId,
    this.author,
    required this.content,
    this.url,
    required this.engagement,
    this.publishedAt,
    required this.collectedAt,
  });

  factory SourcePost.fromJson(Map<String, dynamic> json) => SourcePost(
    id: json['id'] as String,
    taskId: json['task_id'] as String,
    source: json['source'] as String,
    sourceId: json['source_id'] as String?,
    author: json['author'] as String?,
    content: json['content'] as String,
    url: json['url'] as String?,
    engagement: json['engagement'] as int? ?? 0,
    publishedAt: json['published_at'] as String?,
    collectedAt: json['collected_at'] as String,
  );
}
