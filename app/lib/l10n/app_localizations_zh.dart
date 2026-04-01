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
  String get trendingTopics => '推荐话题';

  @override
  String get language => '语言';

  @override
  String get contentLanguageLabel => '搜索语言';

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
  String get statusPartial => '部分完成';

  @override
  String get taskQualityDegraded => '部分源降级';

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
  String get deleteSubscriptionConfirmTitle => '删除订阅';

  @override
  String get deleteSubscriptionConfirmMessage => '确定要删除此订阅吗？';

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
  String get settingsLanguageLabel => '应用 / 报告语言';

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
  String get settingsInAppNotifyHint => '关闭后也不会隐藏订阅低分预警。';

  @override
  String get settingsSubscriptionNotify => '订阅低分预警';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsLicense => '许可协议';

  @override
  String get settingsTitle => '偏好设置';

  @override
  String get settingsServerUrlSaved => '服务器地址已保存';

  @override
  String get settingsServerUrlUseDefault => '恢复默认';

  @override
  String get settingsServerUrlResetToDefault => '已恢复默认服务器地址';

  @override
  String get settingsServerUrlSyncFailed => '报告语言同步失败，服务器地址未生效。';

  @override
  String get settingsLanguageSyncFailed => '语言已切换，但报告语言同步失败。';

  @override
  String get settingsServerUrlInvalid => '请输入完整的 http:// 或 https:// 服务器地址。';

  @override
  String get settingsServerUrlAndroidHttpUnsupported =>
      'Android 正式版仅允许 HTTP 访问 localhost、127.0.0.1、10.0.2.2；调试/分析构建还可使用私网 IP（如 192.168.x.x），其它地址请使用 HTTPS。';

  @override
  String settingsAboutMeta(String version, String license) {
    return '版本 $version • 许可协议：$license';
  }

  @override
  String get settingsAboutDescription =>
      '聚合 Reddit、YouTube 与 X 的内容，生成 AI 舆情分析结果。';

  @override
  String get sources => '来源';

  @override
  String get emptyAnalysis => '输入主题开始分析';

  @override
  String get noContentTitle => '暂无内容';

  @override
  String get errorGeneric => '出了点问题';

  @override
  String get errorNotFound => '数据不存在';

  @override
  String get errorInvalidRequest => '请求参数错误';

  @override
  String get errorServiceUnavailable => '服务暂时不可用，请稍后重试';

  @override
  String get errorNetwork => '网络连接失败，请检查网络';

  @override
  String get errorSourceAvailabilityTitle => '数据源检查失败';

  @override
  String get errorSourceAvailabilityMessage => '无法获取数据源状态，点击重试。';

  @override
  String get systemErrorTitle => '系统错误';

  @override
  String get filterAll => '全部';

  @override
  String get engagement => '互动量';

  @override
  String get openOriginal => '查看原文';

  @override
  String get openLinkFailed => '无法打开链接';

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

  @override
  String postCountLabel(int count) {
    return '$count 条内容';
  }

  @override
  String get analysisMastheadTop => '今日';

  @override
  String get analysisMastheadSubtitle => '舆情情报与情感分析';

  @override
  String get analysisIntro => '输入一个主题或关键词，快速生成一份聚合主流平台舆情、观点与情绪走向的编辑式报告。';

  @override
  String get analysisSearchHintEditorial => '输入要追踪的话题...';

  @override
  String get analysisParametersTitle => '参数';

  @override
  String get analysisStarterTopicsTitle => '推荐话题';

  @override
  String get analysisStarterTopicsDescription => '以下是一些推荐话题，点击即可开始分析。';

  @override
  String get analysisStarterTopicAi => '人工智能';

  @override
  String get analysisStarterTopicCrypto => '加密货币';

  @override
  String get analysisStarterTopicEv => '电动车';

  @override
  String get analysisStarterTopicMarkets => '全球市场';

  @override
  String get analysisStarterTopicLayoffs => '科技裁员';

  @override
  String get analysisDataSourcesTitle => '数据来源';

  @override
  String get analysisDataSourcesList => 'Reddit • YouTube • X';

  @override
  String get analysisSourceStatusHint => '源状态反映最近一次配置检查或采集运行结果。';

  @override
  String get analysisSourceUnavailableLabel => '不可用';

  @override
  String get analysisSourceDegradedLabel => '可重试';

  @override
  String get analysisMaxItemsPerSource => '每个数据源最大条数';

  @override
  String get analysisPerSourceLimitHint => '该上限会分别应用到每个已选数据源。';

  @override
  String get analysisKeywordRequiredMessage => '请先输入一个要分析的话题。';

  @override
  String get analysisCreateTaskError => '暂时无法发起这次分析，请稍后再试。';

  @override
  String get analysisNoAvailableSourcesMessage => '当前没有可用的数据源，请检查源配置或稍后再试。';

  @override
  String get reportOn => '报告主题';

  @override
  String get liveStatus => '实时状态';

  @override
  String get executiveSummary => '核心摘要';

  @override
  String get reportMindmap => '思维导图';

  @override
  String get sentimentIndex => '情绪指数';

  @override
  String get heatShort => '热度';

  @override
  String get volumeShort => '样本量';

  @override
  String insightLabel(String number) {
    return '洞察 $number';
  }

  @override
  String get reportAnalysisFailedTitle => '分析失败';

  @override
  String get reportAnalysisFailedMessage => '分析过程中出现错误，请重试或更换关键词。';

  @override
  String get reportMindmapFallbackTitle => '当前导图暂不可视化';

  @override
  String get reportMindmapFallbackBody =>
      '目前仅支持后端生成的 Mermaid mindmap 子集，以下保留原始文本，方便继续核对。';

  @override
  String get allSources => '全部来源';

  @override
  String get noRecordsFoundTitle => '暂无记录';

  @override
  String get noRecordsFoundMessage => '这里暂时还没有可展示的内容。';

  @override
  String get noFilteredRecordsTitle => '当前筛选下暂无结果';

  @override
  String get noFilteredRecordsMessage => '换一个来源试试，也许会看到更多内容。';

  @override
  String get filterScrollHint => '左右滑动可查看其他来源';

  @override
  String get sourceUnavailable => '原文暂不可用';

  @override
  String get searchArchivesHint => '搜索归档...';

  @override
  String get archiveTitle => '归档';

  @override
  String get archiveEmptyTitle => '归档为空';

  @override
  String get archiveSearchEmptyTitle => '没有找到匹配记录';

  @override
  String get archiveSearchEmptyMessage => '试试更短的关键词，或清空搜索。';

  @override
  String get newAnalysis => '新建分析';

  @override
  String get historyDeleteDialogTitle => '删除这条记录？';

  @override
  String get historyDeleteDialogMessage => '确定要删除这条记录吗？';

  @override
  String get historyDeleteError => '暂时无法删除这条记录。';

  @override
  String get catalogTitle => '目录';

  @override
  String get newEntry => '新建条目';

  @override
  String get createEntry => '创建条目';

  @override
  String get editEntry => '编辑条目';

  @override
  String get catalogEmptyTitle => '目录为空';

  @override
  String get subscriptionDeleteDialogTitle => '删除这条订阅？';

  @override
  String get subscriptionDeleteError => '暂时无法删除这条订阅。';

  @override
  String get subscriptionToggleError => '暂时无法更新这条订阅。';

  @override
  String get subscriptionLoadError => '暂时无法加载这条订阅。';

  @override
  String get subscriptionRunNowError => '暂时无法启动这次执行。';

  @override
  String get subscriptionSaveError => '暂时无法保存这条订阅。';

  @override
  String get subscriptionNegativeAlertTitle => '检测到负面情绪';

  @override
  String subscriptionNegativeAlertMessage(String score) {
    return '最近一次未读执行评分为 $score，请及时查看执行历史。';
  }

  @override
  String get subscriptionSubjectLabel => '关注主题';

  @override
  String get subscriptionKeywordHint => '输入关键词...';

  @override
  String get requiredField => '必填项';

  @override
  String get subscriptionEnableAlerts => '开启低分预警';

  @override
  String get subscriptionSaveAction => '保存订阅';

  @override
  String relativeMinutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String relativeHoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String relativeDaysAgo(int count) {
    return '$count天前';
  }
}
