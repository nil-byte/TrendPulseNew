// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'TrendPulse';

  @override
  String get analysisTab => '分析';

  @override
  String get historyTab => '历史';

  @override
  String get subscriptionTab => '订阅';

  @override
  String get settingsTab => '设置';

  @override
  String get searchHint => '搜索主题进行分析...';

  @override
  String get searchButton => '搜索';

  @override
  String get configureSearch => '配置';

  @override
  String get trendingTopics => '热门话题';

  @override
  String get language => '语言';

  @override
  String get dataSources => '数据源';

  @override
  String get maxItems => '最大条数';

  @override
  String get report => '报告';

  @override
  String get rawData => '原始数据';

  @override
  String get sentimentScore => '情感评分';

  @override
  String get heatIndex => '热度指数';

  @override
  String get dataVolume => '数据量';

  @override
  String get keyInsights => '关键洞察';

  @override
  String get sentimentDistribution => '情感分布';

  @override
  String get positive => '正面';

  @override
  String get negative => '负面';

  @override
  String get neutral => '中立';

  @override
  String get summary => '摘要';

  @override
  String get statusPending => '等待中';

  @override
  String get statusCollecting => '正在采集数据...';

  @override
  String get statusAnalyzing => '正在分析情感...';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失败';

  @override
  String get retry => '重试';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get deleteConfirmTitle => '删除任务';

  @override
  String get deleteConfirmMessage => '确定要删除此任务吗？';

  @override
  String get noHistory => '暂无分析历史';

  @override
  String get startFirstAnalysis => '开始你的第一次分析';

  @override
  String get noSubscriptions => '暂无订阅';

  @override
  String get addFirstSubscription => '添加你的第一个监控主题';

  @override
  String get subscriptionKeyword => '关键词';

  @override
  String get subscriptionInterval => '频率';

  @override
  String get intervalHourly => '每小时';

  @override
  String get intervalSixHours => '每6小时';

  @override
  String get intervalDaily => '每天';

  @override
  String get intervalWeekly => '每周';

  @override
  String get active => '启用';

  @override
  String get paused => '暂停';

  @override
  String get lastRun => '上次运行';

  @override
  String get nextRun => '下次运行';

  @override
  String get notify => '通知';

  @override
  String get runNow => '立即运行';

  @override
  String get executionHistory => '执行历史';

  @override
  String get noExecutions => '暂无执行记录';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get settingsLanguageLabel => '语言';

  @override
  String get settingsService => '服务';

  @override
  String get settingsServerUrl => '服务器地址';

  @override
  String get settingsDefaultItems => '默认最大条数';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsInAppNotify => '应用内通知';

  @override
  String get settingsSubscriptionNotify => '订阅完成提醒';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsLicense => '许可协议';

  @override
  String get settingsAboutDescription =>
      '聚合 Reddit、YouTube 与 X 的内容，生成 AI 舆情分析结果。';

  @override
  String get sources => '来源';

  @override
  String get emptyAnalysis => '输入主题开始分析';

  @override
  String get errorGeneric => '出了点问题';

  @override
  String get filterAll => '全部';

  @override
  String get engagement => '互动量';

  @override
  String get openOriginal => '查看原文';

  @override
  String get newLabel => '新建';

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
  String get poweredBy => '数据来自';

  @override
  String sourceCountLabel(int count) {
    return '$count 条来源';
  }
}
