import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TrendPulse'**
  String get appTitle;

  /// No description provided for @analysisTab.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysisTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @subscriptionTab.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a topic to analyze...'**
  String get searchHint;

  /// No description provided for @searchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// No description provided for @configureSearch.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configureSearch;

  /// No description provided for @trendingTopics.
  ///
  /// In en, this message translates to:
  /// **'Trending Topics'**
  String get trendingTopics;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'Data Sources'**
  String get dataSources;

  /// No description provided for @maxItems.
  ///
  /// In en, this message translates to:
  /// **'Max Items'**
  String get maxItems;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @rawData.
  ///
  /// In en, this message translates to:
  /// **'Raw Data'**
  String get rawData;

  /// No description provided for @sentimentScore.
  ///
  /// In en, this message translates to:
  /// **'Sentiment Score'**
  String get sentimentScore;

  /// No description provided for @heatIndex.
  ///
  /// In en, this message translates to:
  /// **'Heat Index'**
  String get heatIndex;

  /// No description provided for @dataVolume.
  ///
  /// In en, this message translates to:
  /// **'Data Volume'**
  String get dataVolume;

  /// No description provided for @keyInsights.
  ///
  /// In en, this message translates to:
  /// **'Key Insights'**
  String get keyInsights;

  /// No description provided for @sentimentDistribution.
  ///
  /// In en, this message translates to:
  /// **'Sentiment Distribution'**
  String get sentimentDistribution;

  /// No description provided for @positive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get positive;

  /// No description provided for @negative.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get negative;

  /// No description provided for @neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get neutral;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusCollecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting data...'**
  String get statusCollecting;

  /// No description provided for @statusAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing sentiment...'**
  String get statusAnalyzing;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this task?'**
  String get deleteConfirmMessage;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No analysis history yet'**
  String get noHistory;

  /// No description provided for @startFirstAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start your first analysis'**
  String get startFirstAnalysis;

  /// No description provided for @noSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet'**
  String get noSubscriptions;

  /// No description provided for @addFirstSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add your first monitoring topic'**
  String get addFirstSubscription;

  /// No description provided for @subscriptionKeyword.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get subscriptionKeyword;

  /// No description provided for @subscriptionInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get subscriptionInterval;

  /// No description provided for @intervalHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get intervalHourly;

  /// No description provided for @intervalSixHours.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get intervalSixHours;

  /// No description provided for @intervalDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get intervalDaily;

  /// No description provided for @intervalWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get intervalWeekly;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @lastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run'**
  String get lastRun;

  /// No description provided for @nextRun.
  ///
  /// In en, this message translates to:
  /// **'Next run'**
  String get nextRun;

  /// No description provided for @notify.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get notify;

  /// No description provided for @runNow.
  ///
  /// In en, this message translates to:
  /// **'Run Now'**
  String get runNow;

  /// No description provided for @executionHistory.
  ///
  /// In en, this message translates to:
  /// **'Execution History'**
  String get executionHistory;

  /// No description provided for @noExecutions.
  ///
  /// In en, this message translates to:
  /// **'No executions yet'**
  String get noExecutions;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get settingsService;

  /// No description provided for @settingsServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsServerUrl;

  /// No description provided for @settingsDefaultItems.
  ///
  /// In en, this message translates to:
  /// **'Default Max Items'**
  String get settingsDefaultItems;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsInAppNotify.
  ///
  /// In en, this message translates to:
  /// **'In-app notifications'**
  String get settingsInAppNotify;

  /// No description provided for @settingsSubscriptionNotify.
  ///
  /// In en, this message translates to:
  /// **'Subscription completion alerts'**
  String get settingsSubscriptionNotify;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get settingsLicense;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'sources'**
  String get sources;

  /// No description provided for @emptyAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Enter a topic to start analysis'**
  String get emptyAnalysis;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @engagement.
  ///
  /// In en, this message translates to:
  /// **'engagement'**
  String get engagement;

  /// No description provided for @openOriginal.
  ///
  /// In en, this message translates to:
  /// **'Open original'**
  String get openOriginal;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @platformReddit.
  ///
  /// In en, this message translates to:
  /// **'Reddit'**
  String get platformReddit;

  /// No description provided for @platformYouTube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get platformYouTube;

  /// No description provided for @platformX.
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get platformX;

  /// No description provided for @poweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by'**
  String get poweredBy;

  /// No description provided for @sourceCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} sources'**
  String sourceCountLabel(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
