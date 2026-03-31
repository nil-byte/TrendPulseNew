class SubscriptionUpsertRequest {
  final String keyword;
  final String contentLanguage;
  final List<String> sources;
  final String interval;
  final int maxItems;
  final bool notify;

  const SubscriptionUpsertRequest({
    required this.keyword,
    required this.contentLanguage,
    required this.sources,
    required this.interval,
    required this.maxItems,
    required this.notify,
  });

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'content_language': contentLanguage,
    'sources': sources,
    'interval': interval,
    'max_items': maxItems,
    'notify': notify,
  };
}
