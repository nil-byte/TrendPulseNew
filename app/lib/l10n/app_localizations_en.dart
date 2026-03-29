// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TrendPulse';

  @override
  String get analysisTab => 'Analysis';

  @override
  String get historyTab => 'History';

  @override
  String get subscriptionTab => 'Subscription';

  @override
  String get settingsTab => 'Settings';

  @override
  String get searchHint => 'Search a topic to analyze...';

  @override
  String get searchButton => 'Search';

  @override
  String get configureSearch => 'Configure';

  @override
  String get trendingTopics => 'Trending Topics';

  @override
  String get language => 'Language';

  @override
  String get dataSources => 'Data Sources';

  @override
  String get maxItems => 'Max Items';

  @override
  String get report => 'Report';

  @override
  String get rawData => 'Raw Data';

  @override
  String get sentimentScore => 'Sentiment Score';

  @override
  String get heatIndex => 'Heat Index';

  @override
  String get dataVolume => 'Data Volume';

  @override
  String get keyInsights => 'Key Insights';

  @override
  String get sentimentDistribution => 'Sentiment Distribution';

  @override
  String get positive => 'Positive';

  @override
  String get negative => 'Negative';

  @override
  String get neutral => 'Neutral';

  @override
  String get summary => 'Summary';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusCollecting => 'Collecting data...';

  @override
  String get statusAnalyzing => 'Analyzing sentiment...';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusPartial => 'Partial';

  @override
  String get statusFailed => 'Failed';

  @override
  String get retry => 'Retry';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get deleteConfirmTitle => 'Delete Task';

  @override
  String get deleteConfirmMessage =>
      'Are you sure you want to delete this task?';

  @override
  String get deleteSubscriptionConfirmTitle => 'Delete Subscription';

  @override
  String get deleteSubscriptionConfirmMessage =>
      'Are you sure you want to delete this subscription?';

  @override
  String get noHistory => 'No analysis history yet';

  @override
  String get startFirstAnalysis => 'Start your first analysis';

  @override
  String get noSubscriptions => 'No subscriptions yet';

  @override
  String get addFirstSubscription => 'Add your first monitoring topic';

  @override
  String get subscriptionKeyword => 'Keyword';

  @override
  String get subscriptionInterval => 'Interval';

  @override
  String get intervalHourly => 'Hourly';

  @override
  String get intervalSixHours => 'Every 6 hours';

  @override
  String get intervalDaily => 'Daily';

  @override
  String get intervalWeekly => 'Weekly';

  @override
  String get active => 'Active';

  @override
  String get paused => 'Paused';

  @override
  String get lastRun => 'Last run';

  @override
  String get nextRun => 'Next run';

  @override
  String get notify => 'Notify';

  @override
  String get runNow => 'Run Now';

  @override
  String get executionHistory => 'Execution History';

  @override
  String get noExecutions => 'No executions yet';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsService => 'Service';

  @override
  String get settingsServerUrl => 'Server URL';

  @override
  String get settingsDefaultItems => 'Default Max Items';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsInAppNotify => 'In-app notifications';

  @override
  String get settingsInAppNotifyHint =>
      'Turning this off does not hide subscription low-score alerts.';

  @override
  String get settingsSubscriptionNotify => 'Subscription low-score alerts';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLicense => 'License';

  @override
  String get settingsTitle => 'Preferences';

  @override
  String get settingsServerUrlSaved => 'Server URL saved';

  @override
  String get settingsServerUrlUseDefault => 'Use Default';

  @override
  String get settingsServerUrlResetToDefault => 'Using default server URL';

  @override
  String get settingsServerUrlInvalid =>
      'Enter a full http:// or https:// server URL.';

  @override
  String get settingsServerUrlAndroidHttpUnsupported =>
      'On Android, HTTP only works with localhost, 127.0.0.1, or 10.0.2.2. Use HTTPS for other hosts.';

  @override
  String settingsAboutMeta(String version, String license) {
    return 'Version $version • License: $license';
  }

  @override
  String get settingsAboutDescription =>
      'AI-powered social media trend analysis across Reddit, YouTube, and X.';

  @override
  String get sources => 'sources';

  @override
  String get emptyAnalysis => 'Enter a topic to start analysis';

  @override
  String get noContentTitle => 'No Content';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get systemErrorTitle => 'System Error';

  @override
  String get filterAll => 'All';

  @override
  String get engagement => 'engagement';

  @override
  String get openOriginal => 'Open original';

  @override
  String get newLabel => 'New';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get platformReddit => 'Reddit';

  @override
  String get platformYouTube => 'YouTube';

  @override
  String get platformX => 'X';

  @override
  String get poweredBy => 'Powered by';

  @override
  String sourceCountLabel(int count) {
    return '$count sources';
  }

  @override
  String postCountLabel(int count) {
    return '$count posts';
  }

  @override
  String get analysisMastheadTop => 'THE';

  @override
  String get analysisMastheadSubtitle =>
      'Daily Intelligence & Sentiment Analysis';

  @override
  String get analysisIntro =>
      'Enter a topic or keyword to generate an editorial report that distills live public sentiment across major digital platforms.';

  @override
  String get analysisSearchHintEditorial => 'Subject of inquiry...';

  @override
  String get analysisParametersTitle => 'Parameters';

  @override
  String get analysisStarterTopicsTitle => 'Starter Topics';

  @override
  String get analysisStarterTopicsDescription =>
      'Try one of these sample topics to begin faster.';

  @override
  String get analysisStarterTopicAi => 'Artificial Intelligence';

  @override
  String get analysisStarterTopicCrypto => 'Cryptocurrency';

  @override
  String get analysisStarterTopicEv => 'Electric Vehicles';

  @override
  String get analysisStarterTopicMarkets => 'Global Markets';

  @override
  String get analysisStarterTopicLayoffs => 'Tech Layoffs';

  @override
  String get analysisDataSourcesTitle => 'Data Sources';

  @override
  String get analysisDataSourcesList => 'Reddit • YouTube • X';

  @override
  String get analysisKeywordRequiredMessage =>
      'Enter a topic before starting analysis.';

  @override
  String get analysisCreateTaskError =>
      'Unable to start this analysis right now. Please try again.';

  @override
  String get reportOn => 'Report On';

  @override
  String get liveStatus => 'Live Status';

  @override
  String get executiveSummary => 'Executive Summary';

  @override
  String get reportMindmap => 'Mind map';

  @override
  String get sentimentIndex => 'Sentiment Index';

  @override
  String get heatShort => 'Heat';

  @override
  String get volumeShort => 'Volume';

  @override
  String insightLabel(String number) {
    return 'Insight $number';
  }

  @override
  String get reportAnalysisFailedTitle => 'Analysis Failed';

  @override
  String get reportMindmapFallbackTitle => 'Mind map preview unavailable';

  @override
  String get reportMindmapFallbackBody =>
      'Only the backend-generated Mermaid mindmap subset is supported right now. The raw Mermaid text is shown below.';

  @override
  String get allSources => 'All Sources';

  @override
  String get noRecordsFoundTitle => 'No Records Found';

  @override
  String get noRecordsFoundMessage => 'Nothing is available yet.';

  @override
  String get noFilteredRecordsTitle => 'No Matches For This Filter';

  @override
  String get noFilteredRecordsMessage =>
      'Try another source to see more posts.';

  @override
  String get filterScrollHint => 'Scroll to view more sources';

  @override
  String get sourceUnavailable => 'Source Unavailable';

  @override
  String get searchArchivesHint => 'Search archive...';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveEmptyTitle => 'Archive Empty';

  @override
  String get archiveSearchEmptyTitle => 'No Matching Records';

  @override
  String get archiveSearchEmptyMessage =>
      'Try a shorter keyword or clear the search.';

  @override
  String get newAnalysis => 'New Analysis';

  @override
  String get historyDeleteDialogTitle => 'Delete Record?';

  @override
  String get historyDeleteDialogMessage =>
      'Are you sure you want to delete this record?';

  @override
  String get historyDeleteError => 'Unable to delete this record right now.';

  @override
  String get catalogTitle => 'Catalog';

  @override
  String get newEntry => 'New Entry';

  @override
  String get createEntry => 'Create Entry';

  @override
  String get editEntry => 'Edit Entry';

  @override
  String get catalogEmptyTitle => 'Catalog Empty';

  @override
  String get subscriptionDeleteDialogTitle => 'Delete Entry?';

  @override
  String get subscriptionDeleteError =>
      'Unable to delete this entry right now.';

  @override
  String get subscriptionToggleError =>
      'Unable to update this subscription right now.';

  @override
  String get subscriptionLoadError => 'Unable to load this entry right now.';

  @override
  String get subscriptionRunNowError => 'Unable to start this run right now.';

  @override
  String get subscriptionSaveError => 'Unable to save this entry right now.';

  @override
  String get subscriptionNegativeAlertTitle => 'Negative sentiment detected';

  @override
  String subscriptionNegativeAlertMessage(String score) {
    return 'Latest unread run scored $score. Review the execution history now.';
  }

  @override
  String get subscriptionSubjectLabel => 'Subject of Inquiry';

  @override
  String get subscriptionKeywordHint => 'Enter keyword...';

  @override
  String get requiredField => 'Required field';

  @override
  String get subscriptionEnableAlerts => 'Enable low-score alerts';

  @override
  String get subscriptionSaveAction => 'Save Subscription';

  @override
  String relativeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String relativeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String relativeDaysAgo(int count) {
    return '${count}d ago';
  }
}
