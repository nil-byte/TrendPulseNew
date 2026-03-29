class NotificationSettings {
  final bool subscriptionNotifyDefault;

  const NotificationSettings({required this.subscriptionNotifyDefault});

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      subscriptionNotifyDefault: json['subscription_notify_default'] as bool,
    );
  }
}
