class SubscriptionUpsertRequest {
  final String keyword;
  final String language;
  final List<String> sources;
  final String interval;
  final int maxItems;
  final bool notify;

  const SubscriptionUpsertRequest({
    required this.keyword,
    required this.language,
    required this.sources,
    required this.interval,
    required this.maxItems,
    required this.notify,
  });

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'language': language,
    'sources': sources,
    'interval': interval,
    'max_items': maxItems,
    'notify': notify,
  };
}
