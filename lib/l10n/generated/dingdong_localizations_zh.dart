// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'dingdong_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class DingDongLocalizationsZh extends DingDongLocalizations {
  DingDongLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get languageEnglish => '英语';

  @override
  String get languageChinese => '中文';

  @override
  String get languageSpanish => '西班牙语';

  @override
  String get aNewVersionIsAvailable => '有新版本可用';

  @override
  String aSelectedLocalPathResourceCouldNotBeSharedError(Object error) {
    return '所选资源包含无法安全分享的本地路径：$error';
  }

  @override
  String
  get aSkillMeansItsFullInstructionsWereLoadedForThisTaskAnMCP_240facd9 =>
      'Skill 后的 * 表示本轮已加载完整说明；MCP 后的 * 表示本轮实际调用过工具，不表示调用成功；Prompt 不加 *。';

  @override
  String get aToolConnectionWhoseMCPToolsAreCalledOnlyWhenTheTask_08282426 =>
      '提供 MCP 工具连接，仅在任务需要时调用。';

  @override
  String actionCountTimes(Object action, Object count, Object times) {
    return '$action $count 次';
  }

  @override
  String get activated => '激活';

  @override
  String get activated2 => '激活';

  @override
  String get adapterVersionHistory => 'Adapter 版本历史';

  @override
  String get addALocalNoteAboutHowYouUseThisSkill => '记录你会在什么场景使用这个 Skill。';

  @override
  String get addAgentConfiguration => '添加 Agent 配置';

  @override
  String get addAtLeastOneCompleteRule => '请至少填写一条完整规则。';

  @override
  String get addOneOrMoreExistingAbsoluteProjectDirectories =>
      '添加一个或多个已存在的绝对项目目录。';

  @override
  String get addProject => '添加项目';

  @override
  String get addRule => '添加规则';

  @override
  String get addTitle => '添加标题';

  @override
  String get addToGroups => '加入分组';

  @override
  String get advancedAPIAndMCPDetails => '高级 API 与 MCP 信息';

  @override
  String get advancedCommandsAndTheInstallationPromptTheirPresence_b84b4903 =>
      '高级命令与安装提示词；显示这些内容不代表 Agent 已验证。';

  @override
  String get advancedMatching => '高级匹配';

  @override
  String get afterTheGlobalShortcutDingDongCanReturnFocusAndPasteThe_5ad1a82a =>
      '使用全局快捷键后，DingDong 可返回原应用并粘贴所选内容。';

  @override
  String
  get afterUpdatingYouWillNeedToGrantDingDongSMacOSPermissions_20660ff5 =>
      '更新完成后，需要在 macOS“系统设置”中重新授予 DingDong 相关权限。';

  @override
  String get agentActivity => 'Agent 活动';

  @override
  String get agentAlerts => 'Agent 提醒';

  @override
  String get agentAndClipboardItemsCreatedHereAreExplicitDEVTestData_f8625f9f =>
      '这里创建的 Agent 与剪贴板条目都是明确的 DEV 测试数据；“手机来源”样例为模拟数据，绝不会读取真实手机剪贴板。';

  @override
  String get agentCompletion => 'Agent 完成提醒';

  @override
  String get agentCompletionNotifications => 'Agent 完成提醒';

  @override
  String agentCompletionNotificationsForName(Object name) {
    return '$name 的 Agent 完成提醒';
  }

  @override
  String get agentCompletionSignal => 'Agent 完成回执';

  @override
  String get agentConfigurationFileIsInvalid => 'Agent 配置文件无效';

  @override
  String get agentConnectionCenter => 'Agent 连接中心';

  @override
  String get agentConnections => 'Agent 连接';

  @override
  String get agentDecides => 'Agent 判断';

  @override
  String get agentPluginProvidesTheSameSkill => 'Agent 插件提供了同名 Skill';

  @override
  String get agentReplyFooter => 'Agent 回复尾部';

  @override
  String get agentResourceSyncFailed => 'Agent 资源同步失败';

  @override
  String get agentSessionLoadingName => 'Agent 会话加载名称';

  @override
  String get agentSetupNeedsUpdate => 'Agent 接入需要更新';

  @override
  String get agentSetupPrompt => '给 Agent 的接入提示词';

  @override
  String get agentSetupPromptNeedsUpdating => 'Agent 接入提示词需要更新';

  @override
  String get agentSource => 'Agent 来源';

  @override
  String get all => '全部';

  @override
  String get allProjectsNoRestriction => '所有项目 · 不限制';

  @override
  String get allSources => '全部来源';

  @override
  String get allowAgentsToReadClipboardContent => '允许 Agent 读取剪贴板正文';

  @override
  String get allowedByTheExplicitSettingsSwitch => '已通过设置中的明确开关允许';

  @override
  String get always => '始终';

  @override
  String get anEnabledAgentPluginProvidesASkillWithTheSameNameBoth_c5e2f5ee =>
      '已启用的 Agent 插件提供了同名 Skill。两者仍可使用，请确认应该保留或调用哪一个。';

  @override
  String get anExistingUserManagedSkillWasPreservedDingDongDidNot_0f7d7c2a =>
      '已保留用户原有 Skill，DingDong 没有覆盖任何文件。';

  @override
  String get anonymousInstallAndUpdateStatistics => '匿名安装与更新统计';

  @override
  String get apiAgentConnections => 'API | Agent 连接';

  @override
  String apiListeningOnHostPort(Object host, Object port) {
    return 'API 正在监听 $host:$port';
  }

  @override
  String get apiStatusUnverified => 'API 状态待确认';

  @override
  String get appearance => '外观';

  @override
  String get applicationConfiguration => '应用配置';

  @override
  String get apply => '应用';

  @override
  String get archiveTo => '归档到…';

  @override
  String get archiveToGroups => '归档到分组';

  @override
  String get archivedCopiesRemainUnchanged => '已有归档副本不会受到影响。';

  @override
  String get argumentsOnePerLine => '参数 · 每行一个';

  @override
  String get autoSendClipboard => '自动发送剪贴板';

  @override
  String autoSendClipboardFromThisComputerToName(Object name) {
    return '自动将剪贴板从这台电脑发送到 $name';
  }

  @override
  String get availableToInstalledAgents => '对已安装的 Agent 可用';

  @override
  String get backToCategories => '返回分类列表';

  @override
  String get backToDynamic => '返回动态';

  @override
  String get backToResources => '返回资源列表';

  @override
  String get backToTop => '回到顶部';

  @override
  String get basicCompletion => '基础完成提醒';

  @override
  String get bearerTokenEnv => '令牌环境变量';

  @override
  String get blue => '蓝色';

  @override
  String get called => '调用';

  @override
  String get called2 => '调用';

  @override
  String get cancel => '取消';

  @override
  String get cancelDevicePairing => '取消设备连接';

  @override
  String get cancelPairing => '取消连接';

  @override
  String get candidate => '候选';

  @override
  String get captureCurrentClipboard => '捕获当前剪贴板';

  @override
  String get captureNow => '立即捕获';

  @override
  String get captureTextFilesAndImagesWhileDingDongIsRunning =>
      'DingDong 运行期间捕获文本、文件和图片。';

  @override
  String get caseSensitive => '区分大小写';

  @override
  String get category => '分类';

  @override
  String get categoryName => '分类名称';

  @override
  String get categoryNameIsRequired => '请输入分类名称。';

  @override
  String get categoryRule => '分类规则';

  @override
  String get check => '待确认';

  @override
  String get check2 => '检查更新';

  @override
  String get check3 => '检测';

  @override
  String get checkUnreadCountingOrderingAndRepeatedPhoneDelivery =>
      '检查未读数字、列表顺序和手机连续接收。';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get checking => '检查中';

  @override
  String get checkingForUpdates => '正在检查更新…';

  @override
  String get checkingLocalService => '正在检查本机服务';

  @override
  String get choose => '选择';

  @override
  String get chooseHowDingDongBehavesWhenYouSignIn => '选择登录系统后 DingDong 的运行方式。';

  @override
  String get chooseRules => '选择规则';

  @override
  String get chooseWhichAgentEventsShouldNotifyYouThenCustomizeThe_7d9141e4 =>
      '选择哪些 Agent 事件需要提醒，再自定义提示声音和颜色。';

  @override
  String get clean => '清理';

  @override
  String get clear => '清除';

  @override
  String get clearAll => '取消全选';

  @override
  String clearCategory(Object category) {
    return '清除$category？';
  }

  @override
  String get clearCustomSound => '清除自定义声音';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get clearSelection => '取消全选';

  @override
  String get clearSelection2 => '清除选择';

  @override
  String get clickAnywhereToCloseEsc => '点击任意处关闭大图 · Esc';

  @override
  String get clickToEnlargeQRCode => '点击放大二维码';

  @override
  String get clipboard => '剪贴板';

  @override
  String get clipboardAndDevices => '剪贴板与设备';

  @override
  String get clipboardBodyAccess => '剪贴板正文访问';

  @override
  String get clipboardCategories => '剪贴板分类';

  @override
  String get clipboardContent => '剪贴板内容';

  @override
  String
  get clipboardContentStaysMetadataOnlyUnlessExplicitlyEnabled_df1d930e =>
      '除非在设置中明确允许，否则剪贴板正文只返回元数据。';

  @override
  String get clipboardDatabase => '剪贴板数据库';

  @override
  String get clipboardDetailsAndCompleteContent => '剪贴板详情与完整内容';

  @override
  String get clipboardHistory => '剪贴板';

  @override
  String get clipboardHistory2 => '剪贴板历史';

  @override
  String get clipboardHistoryRemainsUnchanged => '剪贴板历史不会受到影响。';

  @override
  String get clipboardItem => '剪贴板条目。';

  @override
  String clipboardSortLabel(Object label) {
    return '剪贴板排序：$label';
  }

  @override
  String get clipboardWorkspace => '剪贴板工作区';

  @override
  String get clipboardWorkspaceShortcut => '剪贴板工作区快捷键';

  @override
  String get close => '关闭';

  @override
  String get closeEnlargedView => '关闭大图';

  @override
  String get code => '代码';

  @override
  String get codexSubagent => 'Codex 子代理';

  @override
  String get codexVoiceTaskNotifications => 'Codex 语音任务提醒';

  @override
  String get command => '启动命令';

  @override
  String get command2 => '命令';

  @override
  String get completionDetailsStayOnThisDeviceCountingMetadata_9920ce29 =>
      '完成详情仅保存在本机；用于统计的元数据只包含完成时间。';

  @override
  String get completionHistoryAndRecentCounts => '任务完成记录与近期计数';

  @override
  String get completionNotificationsAreOffForThisDevice => '此设备的完成提醒已关闭';

  @override
  String get configurationDetails => '配置详情';

  @override
  String get configurationSaved => '配置已保存';

  @override
  String get configureProjects => '配置项目';

  @override
  String
  get configureTheFinalDingDongResourceLineAndOptionallyAppend_e6f7cb62 =>
      '配置 DingDong 最终资源行，并可选择追加精确的本轮会话用量。';

  @override
  String get connectANewDevice => '连接新设备';

  @override
  String get connectedDevices => '连接设备';

  @override
  String get connecting => '连接中…';

  @override
  String get connection => '连接操作';

  @override
  String get connectionError => '连接异常';

  @override
  String get connectionManager => '连接管理窗口';

  @override
  String connectionTestFailedError(Object error) {
    return '连接测试失败：$error';
  }

  @override
  String get connectionType => '连接方式';

  @override
  String get contains => '包含';

  @override
  String get contains2 => '包含';

  @override
  String get content => '内容';

  @override
  String get contentQRCode => '内容二维码';

  @override
  String get contentRegex => '内容正则';

  @override
  String get contentRegularExpression => '内容正则';

  @override
  String get contentType => '内容类型';

  @override
  String get contentTypes => '内容类型';

  @override
  String get copied => '已复制';

  @override
  String copiedCountTimes(Object count) {
    return '已复制 $count 次';
  }

  @override
  String get copiedFileReferencesOriginalFilesAreNeverDeleted =>
      '复制过的文件引用；不会删除原文件';

  @override
  String get copy => '复制';

  @override
  String get copyContent => '复制内容';

  @override
  String get copyCount => '复制次数';

  @override
  String get copyCount2 => '按次数排序';

  @override
  String get coreEndpoints => '核心端点';

  @override
  String couldNotApplyThisSkillDeliveryPolicyDetail(Object detail) {
    return '无法应用此 Skill 交付策略。$detail';
  }

  @override
  String couldNotFetchThisUpdateError(Object error) {
    return '无法获取此更新：$error';
  }

  @override
  String couldNotImportThisResourceBundleError(Object error) {
    return '无法导入这个资源包：$error';
  }

  @override
  String get couldNotOpenThisAgentConversation => '无法打开这个 Agent 对话。';

  @override
  String get couldNotOpenThisSkillSource => '无法打开这个 Skill 来源。';

  @override
  String get couldNotReachTheSourceCheckYourNetworkAndLinkThenTry_1c1ff9ae =>
      '无法连接来源链接，请检查网络和链接后重试。';

  @override
  String get couldNotSaveThisConfigurationCheckTheContentAndTryAgain =>
      '保存失败，请检查内容后重试。';

  @override
  String couldNotSyncThisResourceToAnInstalledAgentDetail(Object detail) {
    return '无法把这个资源同步到已安装的 Agent。$detail';
  }

  @override
  String countIssuesNeedAttention(Object count) {
    return '$count 个问题需要处理';
  }

  @override
  String countItems(Object count) {
    return '$count 条';
  }

  @override
  String countItemsDescription(Object count, Object description) {
    return '$count 项 · $description';
  }

  @override
  String countPairedDevices(Object count) {
    return '已连接 $count 台设备';
  }

  @override
  String countSelected(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get countWindowHours => '计数时间范围（小时）';

  @override
  String get create => '创建样例';

  @override
  String
  get createAComputerRecordAndSendItOnlyToConnectedDevicesWith_41a63724 =>
      '创建电脑记录，只发送给已连接且开启自动同步的设备。';

  @override
  String get createAQRCodeThenScanItWithTheDeviceYouTrust =>
      '生成二维码，再用你信任的设备扫码。';

  @override
  String get createASampleAndOpenTheRealTargetDeviceChooser =>
      '创建样例并打开真实的目标设备选择弹框。';

  @override
  String get createAndSend => '创建并发送';

  @override
  String get createOneClearlyLabeledDEVCompletion => '生成一条明确标注为 DEV 的完成提醒。';

  @override
  String get createOneToStartOrganizingClipboardItems => '新建分类后即可开始自动整理剪贴板。';

  @override
  String get createResource => '创建资源';

  @override
  String get createdBasicAgentCompletion => '已创建：基础 Agent 完成提醒';

  @override
  String get createdComputerAutoSendSample => '已创建：电脑自动同步样例';

  @override
  String get createdRichMobileAgentDetail => '已创建：手机端长描述 Agent 提醒';

  @override
  String get createdSimulatedPhoneFileRow => '已创建：模拟手机文件记录';

  @override
  String get createdSimulatedPhoneTextRow => '已创建：模拟手机文字记录';

  @override
  String get createdThreeAgentCompletions => '已创建：连续三条 Agent 提醒';

  @override
  String get createsRemovableDEVSamplesOrOpensTheRealDeviceWorkflow =>
      '创建可删除的 DEV 样例，或打开真实设备流程。';

  @override
  String get curatedContentReusableByAgents => '整理后可被 Agent 复用的内容';

  @override
  String get current => '当前版本';

  @override
  String get currentAgentAccessClipboardRulesAndRuntimeState =>
      '当前 Agent 接入、剪贴板规则与运行状态';

  @override
  String get currentMemory => '当前内存';

  @override
  String get cursorCompatibleFormat => '兼容 Cursor 的单文件格式';

  @override
  String get customFile => '自定义文件';

  @override
  String get customSound => '自定义声音';

  @override
  String get dark => '深色';

  @override
  String get defaultOrder => '默认排序';

  @override
  String get defaultWorkspace => '默认页面';

  @override
  String get defineWhatContentBelongsInThisCategory => '设置进入这个分类的内容条件。';

  @override
  String get delete => '删除';

  @override
  String get deleteCategory => '删除分类';

  @override
  String get deleteGroup => '删除分组';

  @override
  String deleteGroup2(Object group) {
    return '删除“$group”？';
  }

  @override
  String deleteName(Object name) {
    return '删除「$name」？';
  }

  @override
  String get deleteSelectedItems => '删除所选条目？';

  @override
  String get deleteSelectedResources => '删除所选资源？';

  @override
  String get deleteThisArchivedCopy => '删除这个归档副本？';

  @override
  String get deleteThisCategory => '删除这个分类？';

  @override
  String get deleteThisClipboardItem => '删除此剪贴板条目？';

  @override
  String get deleteThisDevice => '删除这个设备？';

  @override
  String get deleteThisResource => '删除此资源？';

  @override
  String get deleteThisResource2 => '删除这个资源？';

  @override
  String get deletedHistoryCannotBeRestored => '被删除的历史记录无法恢复。';

  @override
  String get deliveryByAgent => '按 Agent 交付';

  @override
  String get describeTheBehaviorTheAgentShouldFollow => '直接写清楚 Agent 应遵循的行为。';

  @override
  String get desktopBehaviorHistoryPrivacyAndLocalAgentConnectivity =>
      '管理桌面行为、历史隐私与本地 Agent 连接。';

  @override
  String get desktopNotification => '桌面通知';

  @override
  String get details => '查看详情';

  @override
  String get dingdongBright => '清亮叮咚';

  @override
  String
  get dingdongChecksAutomaticallyWhenResourcesChangeUseCheckIn_ab07f57c =>
      '资源发生变化时 DingDong 会自动检查，也可以使用右上角的“检测”重新检查。';

  @override
  String get dingdongClassic => '经典叮咚';

  @override
  String get dingdongCopiesTheCompleteSkillPackageIntoEachSelected_de26f089 =>
      'DingDong 会把完整 Skill 包复制到每个所选项目的 Agent 原生目录；只有该 Agent 在这些项目中工作时才会发现它。';

  @override
  String get dingdongCrisp => '清脆叮咚';

  @override
  String dingdongCurrentAppVersionDesktop(Object currentAppVersion) {
    return 'DingDong $currentAppVersion · 桌面版';
  }

  @override
  String get dingdongDeep => '低沉叮咚';

  @override
  String get dingdongDeviceConnectionManager => 'DingDong 设备连接管理窗口';

  @override
  String dingdongHasRecordedTheseLocalStatisticsSinceDateEarlier_90d48aa0(
    Object date,
  ) {
    return 'DingDong 从 $date 开始在本机记录这些统计；更早的使用不会补记，因此 0 不一定代表从未使用。';
  }

  @override
  String get dingdongListensOnlyOnTheLocalLoopbackInterface =>
      'DingDong 仅监听本机回环地址。';

  @override
  String get dingdongOwnedImageCopiesAndRecords => 'DingDong 自有的图片副本与记录';

  @override
  String
  get dingdongPreservedTheExistingAgentFileBecauseItCouldNotBe_6c5484e5 =>
      'DingDong 无法安全解析该文件，因此保留了原有 Agent 配置。';

  @override
  String get dingdongResourceManagerWindow => 'DingDong 资源管理窗口';

  @override
  String get dingdongSettingsWindow => 'DingDong 设置窗口';

  @override
  String get dingdongSkillsUseTheSameName => 'DingDong Skill 名称重复';

  @override
  String get dingdongSoft => '轻柔叮咚';

  @override
  String get disable => '停用';

  @override
  String get disableCategory => '停用分类';

  @override
  String get disableResource => '停用资源';

  @override
  String get discardChanges => '放弃更改';

  @override
  String get discardUnsavedChanges => '放弃未保存的更改？';

  @override
  String get disconnect => '断开连接';

  @override
  String get downloadingUpdate => '正在下载更新…';

  @override
  String downloadingUpdatePercent(Object percent) {
    return '正在下载更新… $percent%';
  }

  @override
  String get dynamicLoadsOnDemandThroughDingDongNativeGlobalInstalls_ff4bd6e5 =>
      '动态通过 DingDong 按需加载；原生 · 全局安装到 Agent 用户目录；原生 · 项目只安装到所选项目。';

  @override
  String get dynamicMessage => '动态';

  @override
  String get dynamicWorkspace => '动态工作区';

  @override
  String get dynamicWorkspaceShortcut => '动态工作区快捷键';

  @override
  String get eGConciseReleaseNotes => '例如：简洁发布说明';

  @override
  String get eGDingDongProjects => '例如：DingDong 项目';

  @override
  String get eGFigma => '例如：Figma';

  @override
  String get eGProjectDrafts => '例如：项目草稿';

  @override
  String get eachProjectMustBeAnExistingAbsoluteDirectory =>
      '每个项目都必须是已存在的绝对目录。';

  @override
  String get edit => '编辑';

  @override
  String get editAndOrganize => '编辑与整理';

  @override
  String get editProjectGroup => '编辑项目组';

  @override
  String get editRules => '编辑规则';

  @override
  String get editText => '编辑文本';

  @override
  String get editTitle => '修改标题';

  @override
  String get editTriggerGroup => '编辑触发组';

  @override
  String get email => '邮箱';

  @override
  String get enable => '启用';

  @override
  String get enableCategory => '启用分类';

  @override
  String get enableResource => '启用资源';

  @override
  String get enableResourcesFromTheLibraryToSeeThemHere => '在资源库启用资源后会显示在这里。';

  @override
  String get enabled => '启用';

  @override
  String get enabled2 => '已启用';

  @override
  String get enabledPhoneVibrationIsOff => '已开启 · 手机端震动已关';

  @override
  String get enabledPhoneVibrationIsOn => '已开启 · 手机端震动已开';

  @override
  String get endpointsCommandsAndSetupPrompt => '端点、命令与接入提示词';

  @override
  String get enlargeQRCode => '放大二维码';

  @override
  String get enterATriggerGroupName => '请输入触发组名称。';

  @override
  String get enterAValidWebSourceBeforeOpeningIt => '请先填写有效的网页来源链接。';

  @override
  String get enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved =>
      '输入一个可见符号。星号和竖线为保留字符。';

  @override
  String get environment => '环境变量';

  @override
  String get equals => '等于';

  @override
  String get equals2 => '等于';

  @override
  String get executablePathNpxUvx => '可执行文件路径、npx、uvx…';

  @override
  String get exerciseRealDingDongIntegrationPathsFromOnePlace =>
      '从一个窗口直接验收 DingDong 的真实集成链路。';

  @override
  String get exportJSON => '导出 JSON';

  @override
  String exportedResourceLibraryToPath(Object path) {
    return '资源库已导出到 $path';
  }

  @override
  String get fetchAndReview => '请求并检查';

  @override
  String get fetchLatestContent => '获取最新内容';

  @override
  String get file => '文件';

  @override
  String get fileFromPhone => '来自手机的文件';

  @override
  String get fileHistory => '文件记录';

  @override
  String get files => '文件';

  @override
  String get findIcon => '找回图标';

  @override
  String get forExampleProjectLinks => '例如：项目链接';

  @override
  String get general => '通用';

  @override
  String get gotIt => '知道了';

  @override
  String get green => '绿色';

  @override
  String get group => '分组';

  @override
  String get groupName => '触发组名称';

  @override
  String get groupRepeatedSessions => '合并同会话提醒';

  @override
  String get groups => '分组';

  @override
  String get groups2 => '选择分组';

  @override
  String get headers => '请求头';

  @override
  String get healthCheckFailed => '健康检查失败';

  @override
  String get healthCheckPassed => '健康检查已通过';

  @override
  String get hideCategoriesAndGroups => '收起分类与分组';

  @override
  String get hideDockIcon => '隐藏 Dock 图标';

  @override
  String get hideInConversation => '会话中隐藏';

  @override
  String get hideMessage => '收起';

  @override
  String get historyStaysOnThisDeviceAgentAccessToClipboardContentIs_74a8f236 =>
      '历史仅保存在本机；是否允许 Agent 读取正文由下方开关控制。';

  @override
  String get horizontalNudge => '左右摇动';

  @override
  String hoursHCount(Object hours, Object count) {
    return '$hours 小时 · $count';
  }

  @override
  String get httpsExampleComDingdongResourcesJson =>
      'https://example.com/dingdong-resources.json';

  @override
  String get image => '图片';

  @override
  String get imageCache => '图片缓存';

  @override
  String get images => '图片';

  @override
  String
  get imagesTextAndFilesAreIndependentCleaningThemNeverRemoves_cb27e3f9 =>
      '图片、文字与文件彼此独立；这里的清理永远不会删除永久归档。';

  @override
  String get impeccableProjectHookApprovalRequiredInHooks =>
      'Impeccable 项目 Hook（需在 /hooks 中批准）';

  @override
  String get importFromLink => '从链接导入';

  @override
  String get importHistory => '导入历史';

  @override
  String get importJSONFile => '导入 JSON 文件';

  @override
  String importLengthResources(Object length) {
    return '导入 $length 项资源';
  }

  @override
  String importedImportedCountSkippedSkippedCount(
    Object importedCount,
    Object skippedCount,
  ) {
    return '导入 $importedCount 项；跳过 $skippedCount 项。';
  }

  @override
  String get importedKnowledgeAvailableToAgentContext =>
      '已导入、可供 Agent 使用的知识库内容。';

  @override
  String importedLengthSkippedSkippedCountSuffix(
    Object length,
    Object skippedCount,
    Object suffix,
  ) {
    return '已导入 $length 项；跳过 $skippedCount 项。$suffix';
  }

  @override
  String get includeAtLeastOneModifierKey => '请至少包含一个修饰键。';

  @override
  String get independentCopiesProtectedFromHistoryCleanup => '独立副本，不受历史清理影响';

  @override
  String get installInAnyOfTheseProjects => '安装到以下任一项目';

  @override
  String get installSkill => '安装 Skill';

  @override
  String get installedFromAnOnlineSource => '已从在线来源安装';

  @override
  String get installedSkillPackageSKILLMd => '已安装的 Skill 包 · SKILL.md';

  @override
  String get installingAndRestarting => '正在安装并重启…';

  @override
  String get instructions => '提示词内容';

  @override
  String issuecountIssueSNeedAttention(Object issueCount) {
    return '$issueCount 个问题需要处理';
  }

  @override
  String get issues => '问题';

  @override
  String get jsonTOMLOrYAMLConfiguration => 'JSON、TOML 或 YAML 配置';

  @override
  String get keepDingDongInTheMenuBarWithoutShowingItInTheDock =>
      '仅保留菜单栏入口，不在 Dock 中显示 DingDong。';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get keepTheSameConversationIDInOneItemShowNAndDoNotIncrease_925894bb =>
      '相同会话 ID 合并为一个动态项，显示 ×N，且不增加最近 Agent 数量。';

  @override
  String get keepTheWorkspaceComfortableInYourCurrentDesktop_41d3bc46 =>
      '根据当前桌面环境调整工作台显示。';

  @override
  String get keepThisItemEasyToFindAcrossMultipleGroups =>
      '一个条目可以同时归档到多个分组，方便之后查找。';

  @override
  String get keyboardShortcuts => '键盘快捷键';

  @override
  String get knowledge => '知识库';

  @override
  String
  get knowledgeIsCollectedFromImportsAndAgentContextItCannotBe_08bd7ed0 =>
      '知识库内容来自导入和 Agent 上下文，暂时不能在这里直接新建。';

  @override
  String get knownConfigurationIssues => '已知配置问题';

  @override
  String get language => '语言';

  @override
  String lastDateTime(Object date, Object time) {
    return '最近 $date $time';
  }

  @override
  String lastReceivedFromSourceAtCompletedAt(
    Object source,
    Object completedAt,
  ) {
    return '最近收到 $source 回执 · $completedAt';
  }

  @override
  String get latest => '最新版本';

  @override
  String get launchAtStartup => '开机启动';

  @override
  String get leaveEmptyToUseTheResourceTitle => '留空时使用资源标题。';

  @override
  String lengthDuplicates(Object length) {
    return '$length 项重复';
  }

  @override
  String lengthIDConflicts(Object length) {
    return '$length 项 ID 冲突';
  }

  @override
  String lengthOnlineSourcesChecked(Object length) {
    return '已检查 $length 个在线来源';
  }

  @override
  String get lengthRange => '长度范围';

  @override
  String lengthResults(Object length) {
    return '$length 个结果';
  }

  @override
  String lengthSelected(Object length) {
    return '已选 $length 个';
  }

  @override
  String lengthSources(Object length) {
    return '已选 $length 个来源';
  }

  @override
  String get libraryMessage => '资源库';

  @override
  String get libraryWorkspace => '资源库工作区';

  @override
  String get libraryWorkspaceShortcut => '资源库工作区快捷键';

  @override
  String get light => '浅色';

  @override
  String get link => '链接';

  @override
  String get links => '链接';

  @override
  String get loadThisResourceWithoutShowingItsNameInTheAgent_ec7e075b =>
      '加载这个资源，但不在 Agent 对话中展示它的名称。';

  @override
  String get loaded => '加载';

  @override
  String get loaded2 => '加载';

  @override
  String get local => '本地';

  @override
  String get localAPI => '本机 API';

  @override
  String get localAuthoring => '本地编写';

  @override
  String get localData => '本地数据';

  @override
  String get localPort => '本地端口';

  @override
  String get localServiceUnavailable => '本机服务不可用';

  @override
  String get localServiceVerified => '本机服务已验证';

  @override
  String get lowercaseHyphenName => '使用小写英文与连字符';

  @override
  String get maintenance => '维护数据';

  @override
  String get manage => '资源管理';

  @override
  String get manageAgents => '管理 Agent';

  @override
  String get manageCategories => '管理分类';

  @override
  String get manual => '手动';

  @override
  String get markAsUpdated => '标记为已更新';

  @override
  String get matchAProjectPathRepositoryOrAgentSource =>
      '按项目目录、仓库地址或 Agent 来源设置触发条件。';

  @override
  String get matchAnyOfTheseRules => '满足任一规则时触发';

  @override
  String get matchedByDescriptionThenLoadedAsACompleteSkillPackage_fa102bfe =>
      '先按 description 匹配，需要时才加载完整 Skill 包。';

  @override
  String get matchesEverything => '匹配全部内容';

  @override
  String get maximumCharacters => '最多字符数';

  @override
  String get maximumDetailedItems => '详细记录上限';

  @override
  String get maximumItems => '最大条目数';

  @override
  String get maximumLengthCannotBeNegative => '最多字符数不能为负数。';

  @override
  String get mcpAccess => 'MCP 接入';

  @override
  String get mcpConfigurationIsInvalid => 'MCP 配置无效';

  @override
  String get mcpFooterSymbol => 'MCP 尾部符号';

  @override
  String get mcpSymbol => 'MCP 符号';

  @override
  String get menuBarAlertColor => '菜单栏提示颜色';

  @override
  String get menuBarIconHiddenByTheCameraHousing => '菜单栏图标被刘海遮挡';

  @override
  String get menuBarMascot => '状态小人';

  @override
  String get metadataOnly => '仅允许元数据';

  @override
  String get minimumCharacters => '最少字符数';

  @override
  String get minimumLengthCannotBeNegative => '最少字符数不能为负数。';

  @override
  String get minimumLengthCannotExceedMaximumLength => '最少字符数不能大于最多字符数。';

  @override
  String get mockAddAPhoneOriginTextRowWithoutReadingAnyPhone_381a76fb =>
      'MOCK：添加一条手机来源文字；不会读取手机剪贴板。';

  @override
  String get mockCreateASmallLocalFileAndShowItsDeviceSource =>
      'MOCK：创建一个小型本地文件并展示设备来源。';

  @override
  String get monitorClipboardChanges => '监控剪贴板变化';

  @override
  String get more => '更多';

  @override
  String get moreActions => '更多操作';

  @override
  String get muted => '静音';

  @override
  String get myNote => '我的备注';

  @override
  String get name => '名称';

  @override
  String get nameMySkillDescriptionUseWhenInstructions =>
      '---\nname: my-skill\ndescription: 什么时候使用…\n---\n\n# 执行说明';

  @override
  String get nativeProject => '原生 · 项目';

  @override
  String get nativeUser => '原生 · 全局';

  @override
  String get needsYourInput => '等待你的确认';

  @override
  String get needsYourInput2 => '需要你处理';

  @override
  String get never => '尚无记录';

  @override
  String get newCategory => '新建分类';

  @override
  String get newConfiguration => '新建配置';

  @override
  String get newGroup => '新建分组';

  @override
  String get newProjectGroup => '新建项目组';

  @override
  String get newResource => '新建资源';

  @override
  String get newTriggerGroup => '新建触发组';

  @override
  String get newestFirstClickAResumableItemToReturnToItsConversation =>
      '按时间倒序排列；点击可恢复的记录可返回对应对话。';

  @override
  String get noAgentCompletionsYet => '暂无 Agent 完成记录';

  @override
  String get noCategoriesYet => '还没有分类';

  @override
  String get noConnectedDevicesYet => '还没有已连接设备';

  @override
  String get noDeviceIsOnlineConnectOneFirst => '当前没有在线设备，请先连接设备。';

  @override
  String get noIssuesFound => '没有发现问题';

  @override
  String get noKnownIssueThisIsNotAConnectionGuarantee => '未发现已知问题；不代表连接已验证';

  @override
  String get noMatchingGroups => '没有匹配的分组';

  @override
  String get noMatchingResources => '没有匹配的资源';

  @override
  String get noMatchingSources => '没有匹配的来源';

  @override
  String get noMatchingTriggerGroups => '没有匹配的触发组';

  @override
  String get noProjectGroupsYet => '还没有项目组';

  @override
  String get noProjectSelected => '尚未选择项目';

  @override
  String get noRealAgentCompletionHasBeenReceivedYet => '尚未收到真实 Agent 完成回执';

  @override
  String get noRecentAgentEvents => '暂无 Agent 事件';

  @override
  String get noResourceImportsYet => '还没有资源导入记录。';

  @override
  String get noSoundSelected => '尚未选择声音';

  @override
  String get noTriggerGroupsYet => '还没有触发组';

  @override
  String get noUpdateMetadataYet => '尚未获取更新信息';

  @override
  String get notInstalled => '未安装';

  @override
  String notInstalledAgentsLength(Object length) {
    return '未安装的 Agent（$length）';
  }

  @override
  String get notVerified => '尚未验证';

  @override
  String get notifications => '通知';

  @override
  String get notify => '发送提醒';

  @override
  String get notifyWhenAnAgentFinishesItsCurrentTaskTurn => 'Agent 完成本轮任务时提醒。';

  @override
  String get notifyWhenAnAgentIsWaitingForConfirmationAChoiceOrYour_825d0876 =>
      'Agent 等待确认、选择或需要你接管时提醒。';

  @override
  String get nudgeTheTrayMascotLikeAnOverdueReminder => '让菜单栏小人左右摇动，模拟超时提醒。';

  @override
  String get offByDefaultMetadataStaysAvailableSensitiveRecordsStill_fa1a5f8f =>
      '默认关闭。关闭时只返回元数据；开启后，敏感记录仍需调用方明确请求。';

  @override
  String get offline => '离线';

  @override
  String get onByDefaultSendsOneEventAfterInstallationOrAVersion_153fb4ab =>
      '默认开启。仅在安装或版本更新后发送一次统计，内容包括随机安装 ID、应用版本、操作系统和处理器架构；不发送活跃状态、功能使用、剪贴板内容、文件或 Agent 消息。实现代码开源，并可随时关闭。';

  @override
  String get oneWayAutoSend => '单向自动同步';

  @override
  String get online => '在线';

  @override
  String onlineOnlineTitles(Object onlineTitles) {
    return '在线来源：$onlineTitles';
  }

  @override
  String get onlineSkillUpdated => '在线 Skill 已更新';

  @override
  String get onlineSync => '在线同步';

  @override
  String
  get onlineSyncIsNotReadyInThisWindowReopenResourceManagerAnd_2ceb1f90 =>
      '当前窗口尚未启用在线同步，请重新打开资源管理后重试。';

  @override
  String get onlyActiveInItsConfiguredTriggerScope => '仅在已配置的触发范围内生效';

  @override
  String get onlyDingDongSLocalFileReferencesAreRemovedOriginalFiles_aea4cfa6 =>
      '只删除 DingDong 本机保存的文件引用；原始文件和文件夹不会被删除。';

  @override
  String get onlyExactExistingProjectDirectoriesCanReceiveANative_7c3d0f93 =>
      '只有精确且已存在的项目目录才能接收原生 Skill。';

  @override
  String get onlyImageCopiesInsideDingDongSCacheAreRemovedSource_28dfcaa2 =>
      '只删除 DingDong 缓存内的图片副本；其他位置的原始图片不会被删除。';

  @override
  String get onlyTextRecordsStoredByDingDongAreRemoved =>
      '只删除 DingDong 自己保存的文字记录。';

  @override
  String get onlyTheConfiguredPreferredPortIsKnown => '目前只知道设置中的首选端口。';

  @override
  String get open => '打开';

  @override
  String get openAgentConversation => '打开 Agent 对话';

  @override
  String openCategoryLocation(Object category) {
    return '打开$category所在位置';
  }

  @override
  String get openDingDongDataFolder => '打开 DingDong 数据文件夹';

  @override
  String get openDingDongImageCache => '打开 DingDong 图片缓存';

  @override
  String get openFileWithSystemApp => '使用系统应用打开文件';

  @override
  String get openForDetailsOrRetry => '可查看详情或重新检查。';

  @override
  String get openLinkWithSystemBrowser => '使用系统浏览器打开链接';

  @override
  String get openOrHideClipboard => '打开或隐藏剪贴板';

  @override
  String get openPathWithSystemApp => '使用系统应用打开路径';

  @override
  String get openPermissionHelper => '打开授权助手';

  @override
  String get openSettings => '前往开启';

  @override
  String get openSource => '打开来源';

  @override
  String get openTheStandaloneQRDeviceSwitchDisconnectAndDelete_441119af =>
      '打开独立二维码、设备、开关、断连和删除窗口。';

  @override
  String openTitle(Object title) {
    return '打开 $title';
  }

  @override
  String get openedConnectionManager => '已打开：连接管理窗口';

  @override
  String get openedSendToDeviceChooser => '已打开：发送到设备选择弹框';

  @override
  String get optional => '可多选';

  @override
  String get optional2 => '可选';

  @override
  String get orange => '橙黄';

  @override
  String get organizeClipboardItem => '整理剪贴板条目';

  @override
  String get otherLocalFiles => '其他本地文件';

  @override
  String get otherSettings => '其它设置';

  @override
  String get pairATrustedDeviceAndChooseWhatThisComputerSends =>
      '连接可信设备，并选择这台电脑可以发送的内容。';

  @override
  String get pairingDoesNotCopyContentByItself => '完成连接后也不会自动复制内容。';

  @override
  String pairingQRCodeForName(Object name) {
    return '$name 的连接二维码';
  }

  @override
  String get paste => '粘贴';

  @override
  String get pasteAGitHubSkillRepositoryFolderOrDirectSKILLMdLink_1ee790e1 =>
      '请粘贴 GitHub Skill 仓库、文件夹或 SKILL.md 直链。\n正确示例：\nhttps://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste\nhttps://github.com/mattpocock/skills/tree/main/skills/productivity/grilling';

  @override
  String get pasteAJSONBundleLinkDingDongWillFetchItResolveItsOnline_cb404168 =>
      '粘贴 JSON 资源包链接。DingDong 会先请求文件、解析其中的在线资源，并在导入前展示来源供你检查。';

  @override
  String get pasteAsPlainText => '粘贴为纯文本';

  @override
  String get pasteConfig => '粘贴配置';

  @override
  String get pasteAgentSetupInstructionDescription =>
      '把这段简短指令发给本机 Agent。它已经包含当前安装的准确 MCP 路径，会保留已有配置，并仅在支持时接入任务完成提醒。';

  @override
  String get path => '路径';

  @override
  String get permanentArchives => '永久归档';

  @override
  String get permanentArchivesAndTheirImageFilesAreProtectedAndWill_889010d8 =>
      '永久归档及归档引用的图片文件受保护，会完整保留。';

  @override
  String get permissionGranted => '权限已授予';

  @override
  String get permissionRequired => '需要授予权限';

  @override
  String get permissionStatusUnavailable => '无法获取权限状态';

  @override
  String get pin => '置顶';

  @override
  String get pinInLibrary => '在资源库置顶';

  @override
  String get pink => '粉色';

  @override
  String get pinned => '已置顶';

  @override
  String get plainText => '纯文本';

  @override
  String get portChangesApplyTheNextTimeDingDongStarts =>
      '端口修改将在下次启动 DingDong 时生效。';

  @override
  String preferredPortPreferredPortWasUnavailableUsingActualPort(
    Object preferredPort,
    Object actualPort,
  ) {
    return '首选端口 $preferredPort 不可用，当前使用 $actualPort。';
  }

  @override
  String get preparingUpdate => '正在准备更新…';

  @override
  String get pressAShortcut => '请按下快捷键…';

  @override
  String get pressToRecordADifferentShortcut => '按下后录制新的快捷键';

  @override
  String get preview => '预览';

  @override
  String get previewImageWithSystemApp => '使用系统应用预览图片';

  @override
  String get previewRealTrayStatesWithoutCreatingHistoryRecords =>
      '预览真实菜单栏状态，不创建历史记录。';

  @override
  String get previewSound => '试听声音';

  @override
  String get priorityFirstMatchWins => '匹配顺序 · 上方优先';

  @override
  String priorityIndexDragToReorder(Object index) {
    return '优先级 $index · 拖动排序';
  }

  @override
  String get privateHistoryMetadata => '私有历史元数据';

  @override
  String get projectDirectory => '项目目录';

  @override
  String get projectDirectoryEquals => '项目目录 · 等于';

  @override
  String get projectInstallationScope => '项目安装范围';

  @override
  String get projectSkillPathIsInvalid => '项目 Skill 路径无效';

  @override
  String get prompt => '提示词';

  @override
  String get promptFooterSymbol => 'Prompt 尾部符号';

  @override
  String get promptName => '提示词名称';

  @override
  String get promptSymbol => 'Prompt 符号';

  @override
  String get prompts => '提示词';

  @override
  String get promptsSkillsMCPResourcesAndTriggerScopes =>
      'Prompt、Skill、MCP 资源与触发范围';

  @override
  String get protectedData => '受保护数据';

  @override
  String get protectedDataIsNotClearedHere => '受保护数据不会在这里清除';

  @override
  String get purple => '紫色';

  @override
  String get qrCode => '二维码';

  @override
  String get quickPasteNeedsAccessibilityPermission => '快捷粘贴需要辅助功能权限。';

  @override
  String get quickPastePermission => '快捷粘贴权限';

  @override
  String get quickPastePermissionGranted => '快捷粘贴权限已开启';

  @override
  String get readOnly => '只读';

  @override
  String get recentAgents => '最近 Agent';

  @override
  String get recheckLocalService => '重新检查本机服务';

  @override
  String get reconnect => '重新连接';

  @override
  String get reconnectThisAgent => '重新接入这个 Agent';

  @override
  String get refreshStatus => '刷新状态';

  @override
  String get regularExpressionIsInvalid => '正则表达式格式不正确。';

  @override
  String get release => '发布页';

  @override
  String get rememberAfterRestart => '重启后保留记录';

  @override
  String get removeFromSelection => '取消选择';

  @override
  String get removeRule => '删除规则';

  @override
  String get reorder => '调整顺序';

  @override
  String repeatcountNotificationsForThisConversation(Object repeatCount) {
    return '此会话已提醒 $repeatCount 次';
  }

  @override
  String get reportAProblem => '上报问题';

  @override
  String get repositoryAddress => '仓库地址';

  @override
  String get requestAFeature => '提出需求';

  @override
  String get requiredInstructionsThatAreAppliedAutomaticallyWhenever_7564e51c =>
      '命中后必须自动应用的完整指令。';

  @override
  String get reset => '恢复默认';

  @override
  String get reset2 => '重置';

  @override
  String get resetChanges => '重置更改';

  @override
  String resetSemanticLabel(Object semanticLabel) {
    return '恢复$semanticLabel默认值';
  }

  @override
  String get resource => '资源';

  @override
  String get resourceActions => '资源操作';

  @override
  String get resourceLibrary => '资源';

  @override
  String get resourceLibrary2 => '资源库';

  @override
  String get resourceManager => '资源管理';

  @override
  String get resources => '资源';

  @override
  String get resourcesBecomeAvailableWhenASelectedGroupMatchesThis_ae977468 =>
      '所选触发组命中当前项目或 Agent 来源时，资源才会生效。';

  @override
  String get resourcesUsingThisGroupWillBecomeUnrestricted =>
      '使用此触发组的资源将变为不限制项目。';

  @override
  String get restart => '重启';

  @override
  String get restore => '恢复内置';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get restoreOneHistoryItem => '恢复单个历史条目';

  @override
  String get retentionDays => '保留天数';

  @override
  String get returnedAsACandidate => '成为候选';

  @override
  String get reviewOnlineResources => '检查在线资源';

  @override
  String get reviewResourceSyncAgentConfigurationAndAnythingElseThat_a562ea61 =>
      '集中查看资源同步、Agent 配置及其他需要处理的问题。';

  @override
  String
  get reviewTheSkillBeforeInstallingDingDongSavesTheFullFolder_1375b575 =>
      '安装前先确认内容。DingDong 会保存包括脚本和参考资料在内的完整目录，更新由你手动触发。';

  @override
  String get richMobileDetail => '手机长描述';

  @override
  String ruleAndItsMatchingConditionsWillBeRemovedClipboardItems_48d9a089(
    Object rule,
  ) {
    return '“$rule”及其匹配条件将被移除，剪贴板条目不会被删除。';
  }

  @override
  String get rulesRunFromTopToBottomTheFirstMatchWins => '规则从上到下匹配，首个命中分类生效。';

  @override
  String get run => '测试';

  @override
  String get running => '执行中…';

  @override
  String get runningTest => '正在执行测试…';

  @override
  String get runtimeCheck => '运行时检查';

  @override
  String get runtimeStatusUnverified => '运行状态尚未验证';

  @override
  String get save => '保存';

  @override
  String get saveAsPrompt => '保存为提示词';

  @override
  String get saveCategory => '保存分类';

  @override
  String get saveGroup => '保存触发组';

  @override
  String get saved => '已保存';

  @override
  String savedAsSKILLMdNameName(Object name) {
    return '保存为 SKILL.md · name: $name';
  }

  @override
  String get savedYAMLRevisionsCurrentAdaptersStayIntact =>
      '已保存的 YAML 修订；当前 Adapter 不受影响';

  @override
  String get saving => '保存中…';

  @override
  String get scanToConnect => '扫码连接';

  @override
  String get scanToShareClickToEnlarge => '扫码分享 · 点击放大';

  @override
  String get scanWithTheDeviceYouWantToTrust => '请使用要信任的设备扫码。';

  @override
  String get scope => '作用域';

  @override
  String get scoped => '有触发范围';

  @override
  String get searchClipboard => '搜索剪贴板';

  @override
  String get searchClipboardHistory => '搜索剪贴板历史';

  @override
  String get searchGroups => '搜索分组';

  @override
  String get searchNameOrContent => '搜索名称或内容';

  @override
  String get searchNamesOrRules => '搜索名称或规则';

  @override
  String get searchPromptsSkillsAndMCP => '搜索提示词、Skills 和 MCP';

  @override
  String get searchResources => '搜索资源';

  @override
  String get searchSources => '搜索来源';

  @override
  String get seeWhatDingDongStoresLocallyAndCleanOnlyTheHistoryYou_a955b365 =>
      '查看 DingDong 的本地占用，只清理你明确选择的历史数据。';

  @override
  String get selectAConfigurationToInspectOrEdit => '选择一项配置以查看或编辑';

  @override
  String get selectAll => '全选';

  @override
  String get selectAnItemToPreview => '选择一个条目以预览';

  @override
  String get selectItem => '选择条目';

  @override
  String get selectItem2 => '选择此项';

  @override
  String selectioncountResourcesSelected(Object selectionCount) {
    return '已选择 $selectionCount 项资源';
  }

  @override
  String selectioncountSelected(Object selectionCount) {
    return '已选 $selectionCount 项';
  }

  @override
  String semanticlabelWaitingForAShortcut(Object semanticLabel) {
    return '$semanticLabel，正在等待快捷键';
  }

  @override
  String get send3 => '发送 3 条';

  @override
  String get sendTestNotification => '发送测试通知';

  @override
  String get sendTheOneLineSetupRequestToEachAffectedAgentMarkIt_3a68e15f =>
      '把这一句接入请求发给受影响的 Agent；确认 MCP 和任务完成提醒都验证通过后，再标记完成。';

  @override
  String get sendToDevice => '发送到设备';

  @override
  String get sendToDeviceDialog => '发送到设备弹框';

  @override
  String get sensitiveContentHidden => '敏感内容已隐藏';

  @override
  String get serverName => '服务名称';

  @override
  String get serverURL => '服务地址';

  @override
  String get serviceHealth => '服务健康状态';

  @override
  String get setTheSystemWidePanelShortcutAndTheShortcutsUsedInside_4f5138fb =>
      '设置面板全局快捷键，以及面板获得焦点时使用的工作区快捷键。';

  @override
  String get settings => '设备设置';

  @override
  String get settings2 => '设置';

  @override
  String get sharedDatabaseFiles => '共享数据库文件';

  @override
  String shortcutReady(Object shortcut) {
    return '$shortcut 就绪';
  }

  @override
  String get showCategoriesAndGroups => '展开分类与分组';

  @override
  String get showCategoriesAndGroupsFiltersActive => '展开分类与分组（筛选已启用）';

  @override
  String get showConversationTokenUsage => '显示会话 Token 用量';

  @override
  String get showMessage => '展开';

  @override
  String get showPairingQR => '显示连接二维码';

  @override
  String get showQRCodeToPairATrustedDevice => '显示二维码以连接可信设备';

  @override
  String get showTheSleepingMascotBrieflyThenRestoreTheCurrentState =>
      '短暂显示睡眠小人，然后恢复当前状态。';

  @override
  String get shownOnlyWhenCodexClaudeCodeOrPiProvidesExactLocalUsage_7e557397 =>
      '仅在 Codex、Claude Code 或 Pi 可提供本机精确用量时显示；不支持的 Agent 不做估算。';

  @override
  String get skill => 'Skill';

  @override
  String get skill2 => '技能';

  @override
  String get skillConfigurationIsInvalid => 'Skill 配置无效';

  @override
  String get skillFooterSymbol => 'Skill 尾部符号';

  @override
  String get skillMdContent => 'SKILL.md 内容';

  @override
  String get skillMdNeedsValidNameAndDescriptionFieldsInItsYAML_c05294f5 =>
      'SKILL.md 的 YAML frontmatter 需要有效的 name 和 description。';

  @override
  String get skillName => 'Skill 名称';

  @override
  String get skillNameConflict => 'Skill 名称冲突';

  @override
  String get skillPackageIsMissing => 'Skill 包缺失';

  @override
  String get skillSource => 'Skill 来源';

  @override
  String get skillSymbol => 'Skill 符号';

  @override
  String get skills => '技能';

  @override
  String skippedcountResourcesAlreadyExistAndWillBeSkippedOr_6aa841ce(
    Object skippedCount,
  ) {
    return '发现 $skippedCount 项已有资源，导入时会跳过或标记为冲突。';
  }

  @override
  String get sleepingState => '睡眠状态';

  @override
  String get sound => '声音';

  @override
  String get source => '来源';

  @override
  String get sourceApplicationRegularExpression => '来源应用正则';

  @override
  String sourceFilterSummary(Object summary) {
    return '来源筛选：$summary';
  }

  @override
  String get sourceRegex => '来源正则';

  @override
  String get sourceURL => '来源链接';

  @override
  String get sources => '来源';

  @override
  String get startDingDongAfterYouSignInToThisComputer =>
      '登录此电脑后自动启动 DingDong。';

  @override
  String get status => '状态';

  @override
  String get stopConnecting => '停止连接';

  @override
  String get subagentNotifications => '子智能体提醒';

  @override
  String get system => '跟随系统';

  @override
  String get systemSound => '系统声音';

  @override
  String get tagsAndAliases => '标签与别名';

  @override
  String get taskMatch => '任务匹配';

  @override
  String get testAConciseSummaryPlusALongerMobileDetailBody =>
      '测试简短摘要与手机端较长详情正文。';

  @override
  String get testNotificationSent => '测试通知已发送';

  @override
  String get testPanel => '测试面板';

  @override
  String get text => '文本';

  @override
  String get textFromPhone => '来自手机的文字';

  @override
  String get textHistory => '文字记录';

  @override
  String get textIsLargerThan128KiBAndWasNotSent => '文本超过 128 KiB，未发送。';

  @override
  String get textLinksCodeCommandsAndRichText => '文本、链接、代码、命令与富文本';

  @override
  String get theBundledBridgeExposesPromptsSkillsMCPReferencesAnd_a0f4fd67 =>
      '内置桥接通过 JSON-RPC 提供提示词、技能、MCP 引用与通知能力。';

  @override
  String get theCommandBelowUsesTheActualEndpointWhenTheRuntime_0a3909c7 =>
      '运行时提供了实际地址时，下方命令会使用实际地址。';

  @override
  String get theCompleteSkillPackageCouldNotBeFoundReinstallOrUpdate_2a4648b6 =>
      '找不到完整 Skill 包，请重新安装或更新来源。';

  @override
  String get theDEVPWAEndpointIsNotConfiguredInThisBuild =>
      '这个构建尚未配置 DEV PWA 地址。';

  @override
  String get theDeviceDisconnectedBeforeSending => '发送前设备已断开。';

  @override
  String
  get theEncryptedMessageIsLargerThanThe256KiBRelayLimitAndWas_3231b01c =>
      '内容加密后超过 256 KiB 中继上限，未发送。';

  @override
  String get theHealthEndpointRespondedSuccessfully => '/health 已成功响应。';

  @override
  String get theHelperOpensAccessibilityAndPlacesADraggableDingDong_11660c82 =>
      '助手会打开“辅助功能”，并在旁边显示可拖拽的 DingDong。“−”可用时先删除旧条目再拖入；若“−”置灰，先拖一次让它可用，删除旧条目后再拖一次并打开开关。';

  @override
  String get theInstalledPackageIsReadOnlyReviewTheSourceBefore_d3e0119e =>
      '已安装的 Skill 包为只读。更新前请先查看来源。';

  @override
  String get theKeyStaysInTheQRWebRTCIsPreferredTheEncryptedRelay_ca235c45 =>
      '密钥只存在于二维码中；优先使用 WebRTC 直连，加密中继不保存内容。';

  @override
  String get theRuntimeEndpointDidNotPassItsHealthCheck => '实际运行地址未通过健康检查。';

  @override
  String get theSKILLMdMetadataCouldNotBeParsedReviewTheResource_d8ef0c36 =>
      '无法解析 SKILL.md 元数据，请检查资源内容后再启用。';

  @override
  String
  get theScopedProjectDirectoryNoLongerExistsOrIsNotAnAbsolute_78de1cff =>
      '限定的项目目录不存在，或不是有效的绝对路径。';

  @override
  String get theSourceDidNotReturnAUsableSKILLMdCheckTheRepository_8db02039 =>
      '来源链接没有返回可用的 SKILL.md，请确认仓库路径和访问权限。';

  @override
  String get theTestFailedCheckTheConnectionAndSystemPermissions =>
      '测试执行失败，请检查连接状态和系统权限。';

  @override
  String get theme => '主题';

  @override
  String get theseResourcesWillBeLoadedFromTheInternetCheckTheSource_08e83c52 =>
      '以下资源会从互联网加载。请先检查来源链接，确认无误后再导入。';

  @override
  String get thisComputerHost => '这台电脑 · 主机';

  @override
  String thisComputerName(Object name) {
    return '这台电脑 → $name';
  }

  @override
  String get thisConflictsWithAnotherDingDongOrSystemShortcut =>
      '这个组合与其他 DingDong 或系统快捷键冲突。';

  @override
  String get thisContentIsNoLongerAvailableOrCouldNotBeOpened =>
      '该内容已不存在或无法打开。';

  @override
  String get thisContentNoLongerExistsOrCannotBeOpened => '该内容已不存在或无法打开。';

  @override
  String thisConversationHasNotifiedYouRepeatCountTimesAndUsed_3d5931a3(
    Object repeatCount,
    Object totalTokens,
  ) {
    return '本轮会话已经提醒 $repeatCount 次，共消耗 $totalTokens Token';
  }

  @override
  String thisGroupContainsCountArchivedCopiesCopiesWithNoOther_d4ba7c7d(
    int count,
  ) {
    return '这个分组中有 $count 个归档副本。没有其他分组的副本会被删除，剪贴板历史不受影响。';
  }

  @override
  String get thisMCPResourceCannotBeWrittenToAgentConfigurationUntil_ad7aa3e0 =>
      '修正格式前，该 MCP 资源无法写入 Agent 配置。';

  @override
  String get thisOnlineSkillDoesNotHaveAnAvailableSource =>
      '这个在线 Skill 没有可用的来源链接。';

  @override
  String thisRemovesCategoryHistoryCategory2CurrentResourcesAnd_a27899ae(
    Object category,
    Object category2,
  ) {
    return '将删除$category历史（$category2），当前资源与配置会保留。';
  }

  @override
  String thisRemovesLengthResourcesFromTheLocalLibrary(Object length) {
    return '这会从本地资源库中移除 $length 项资源。';
  }

  @override
  String thisRemovesOnlyThisPartOfClipboardHistoryCategory(Object category) {
    return '只会删除这部分剪贴板历史（$category）。';
  }

  @override
  String get thisRemovesTheResourceFromTheSharedAgentLibrary =>
      '此操作会将资源从共享 Agent 资源库中移除。';

  @override
  String thisRemovesTitleFromTheLocalResourceLibrary(Object title) {
    return '这会从本地资源库中移除“$title”。';
  }

  @override
  String get threeAlertBurst => '连续三条提醒';

  @override
  String get title => '标题';

  @override
  String get trayMascotPreviewsAreUnavailableOnThisPlatformTheOther_ab13b937 =>
      '当前平台不支持状态小人预览；其余集成测试仍可使用。';

  @override
  String get triggerGroups => '选择触发组';

  @override
  String get triggerScope => '触发范围';

  @override
  String get triggeredHorizontalNudge => '已触发：左右摇动';

  @override
  String get triggeredSleepingState => '已触发：睡眠状态';

  @override
  String get trustAndDirectionalSettingsWillBeRevokedPairAgainTo_f59587ea =>
      '将撤销信任和方向设置；下次连接需要重新扫码。';

  @override
  String get twoDingDongResourcesResolveToTheSameSkillDestination_aac6ae3f =>
      '两个 DingDong 资源指向同一 Skill 位置，请改名或停用其中一个。';

  @override
  String get type => '类型';

  @override
  String get unavailable => '不可用';

  @override
  String get uncategorized => '未分类';

  @override
  String get unknown => '未知';

  @override
  String get unknownAgentConversation => '未知 Agent 会话';

  @override
  String get unpin => '取消置顶';

  @override
  String get unrecognizedLocalFilesAreKept => '保留未识别的本地文件';

  @override
  String get untitledClipboardItem => '未命名剪贴板条目';

  @override
  String get upTo7CharactersThisNameIsShownFirstInTheAgent_b892681f =>
      '最多 7 个字。Agent 会话中优先展示这个名称；留空时回退到资源标题。';

  @override
  String get update => '需要更新';

  @override
  String get updateCheckFailed => '更新检查失败';

  @override
  String get updateFailed => '更新失败';

  @override
  String get updateLink => '更新链接';

  @override
  String updateToVersion(Object version) {
    return '更新到 $version';
  }

  @override
  String get updated => '已更新';

  @override
  String get updated2 => '更新';

  @override
  String get updated3 => '更新时间';

  @override
  String updatedTitleFromItsSource(Object title) {
    return '已从来源更新 $title。';
  }

  @override
  String get updating => '更新中…';

  @override
  String get updating2 => '正在更新…';

  @override
  String get usage => '使用';

  @override
  String get usage2 => '使用统计';

  @override
  String get usage3 => '占用';

  @override
  String get useALetterNumberF1F12ArrowSpaceOrReturn =>
      '请使用字母、数字、F1–F12、方向键、空格或回车。';

  @override
  String get useAValidSTDIOOrStreamableHTTPMCPConfiguration =>
      '请填写有效的 STDIO 或 Streamable HTTP MCP 配置。';

  @override
  String get useRegularExpressionsOnlyWhenTypeAndLengthAreNotEnough =>
      '仅在类型和长度条件不足时使用正则表达式。';

  @override
  String get used => '使用';

  @override
  String get used2 => '使用';

  @override
  String get usesTheRealLocalDingRouteUnreadBadgeNativeAlertAnd_63a64edd =>
      '走真实本地 /ding、未读角标、系统提醒和已连接手机分发链路。';

  @override
  String get verifyTheLocalServiceAndInspectRealAgentSignals =>
      '验证本机服务，并查看真实的 Agent 信号。';

  @override
  String get verifyingUpdate => '正在校验更新…';

  @override
  String get version => '版本';

  @override
  String get viewAllRecentAgents => '查看全部最近 Agent';

  @override
  String get viewResource => '查看资源';

  @override
  String get visibleForReferenceOnlyTheseItemsCannotBeClearedHere =>
      '仅供查看占用；这些数据不允许在这里清除。';

  @override
  String get waitingForTheLoopbackHealthResponse => '正在等待本机回环健康检查。';

  @override
  String
  get webrtcIsPreferredTheEndToEndEncryptedRelayFallbackStores_816753f3 =>
      '优先使用 WebRTC 直连；端到端加密中继不保存剪贴板、文件或 Agent 内容。';

  @override
  String get website => '官网';

  @override
  String get whenDisabledTheNextLaunchStartsWithAnEmptyAgentHistory =>
      '关闭后，下次启动将从空的 Agent 历史开始。';

  @override
  String get whenItApplies => '生效方式';

  @override
  String get whenOffSubagentActivityShowsNoNotificationOrDingDong_ce161d98 =>
      '关闭后，子智能体动态不显示提醒，也不播放叮咚声音。';

  @override
  String get whenOffTasksStartedInCodexVoiceModeDoNotNotifyOrPlayA_75237958 =>
      '关闭后，从 Codex 语音模式发起的任务不显示提醒，也不播放叮咚声音。';

  @override
  String get whenToUse => '什么时候使用';

  @override
  String get windowOpacity => '窗口透明度';

  @override
  String get workspaceShortcutsApplyOnlyWhileThePanelIsFocused_1b6f2968 =>
      '工作区快捷键只在面板获得焦点时生效。默认：macOS 为 Control+Q/W/E，Windows 为 Alt+Q/W/E。';

  @override
  String get youReUpToDate => '已是最新版本';

  @override
  String get yourDevices => '已连接设备';

  @override
  String get yourEditsHaveNotBeenSavedLeavingThisPageWillDiscardThem =>
      '当前编辑尚未保存，离开此页面将放弃这些更改。';

  @override
  String get custom => '自定义';

  @override
  String get builtIn => '内置';

  @override
  String get invalidConfiguration => '配置无效';

  @override
  String get loadExternal => '载入外部版本';

  @override
  String get directoryNotChecked => '目录尚未检查';

  @override
  String get directoryNotDetected => '未检测到目录';

  @override
  String get directoryDetected => '已检测到目录';

  @override
  String get unsaved => '尚未保存';

  @override
  String get newAgent => '新 Agent';

  @override
  String get newLabel => '新建';

  @override
  String get refresh => '刷新';

  @override
  String get versionComparison => '版本对比';

  @override
  String get advancedConfig => '高级配置';

  @override
  String get deleteThisAdapter => '删除这个 Adapter？';

  @override
  String get restoreBuiltInVersion => '恢复内置版本？';

  @override
  String get notChecked => '尚未检查';

  @override
  String get notDetected => '未检测到';

  @override
  String get detected => '已检测到';

  @override
  String get managedButDisabled => '已托管但未启用';

  @override
  String get managedAndEnabled => '已托管并启用';

  @override
  String get trustedButDisabled => '已信任但未启用';

  @override
  String get trustedAndEnabled => '已信任并启用';

  @override
  String get checkingCodex => '正在检查 Codex…';

  @override
  String get trustEnable => '信任并启用';

  @override
  String get checkAgain => '重新检查';

  @override
  String get notDeclared => '未声明';

  @override
  String get declared => '已声明';

  @override
  String get skillPaths => 'Skill 路径';

  @override
  String get mcpConfigurationPath => 'MCP 配置路径';

  @override
  String get agentDirectory => 'Agent 目录';

  @override
  String get invalid => '无效';

  @override
  String get valid => '有效';

  @override
  String get adapterDocument => 'Adapter 文档';

  @override
  String get configurationEvidence => '配置证据';

  @override
  String get storedOnThisDevice => '数据保存在本机';

  @override
  String get agentAccess => 'Agent 接入';

  @override
  String get workspace => '管理';

  @override
  String get userOverride => '用户覆盖';

  @override
  String get selectAnAgentAdapterOrCreateOne => '选择一个 Agent Adapter，或新建一个。';

  @override
  String get theFileChangedOutsideDingDongWhileYouHaveUnsavedEdits =>
      '外部 Agent 修改了文件，但编辑器里还有未保存内容。';

  @override
  String
  get directoryDetectionAndDeclaredPathsVerifyRuntimeConnectionsSeparately =>
      '目录检测与配置路径；实际运行连接需单独验证';

  @override
  String get agentConnectionConfiguration => 'Agent 连接配置';

  @override
  String get aComparisonAppearsAfterTheNextSavedOrExternalEdit =>
      '保存或外部修改下一版后，这里会显示差异。';

  @override
  String get twoVersionsAgo => '上两个版本';

  @override
  String get previousVersion => '上一个版本';

  @override
  String get newAgentAdapter => '新建 Agent Adapter';

  @override
  String get theCustomYAMLFileWillBeDeletedAgentResourcesWillStopSyncing =>
      '自定义 YAML 文件会被删除，Agent 资源也将停止同步到这个客户端。';

  @override
  String get theUserOverrideWillBeRemovedItsSnapshotsRemainInLocalHistory =>
      '用户覆盖文件会被移除，已有快照仍保留在本地历史中。';

  @override
  String get connectionHasNotBeenInferred => '未推断连接成功';

  @override
  String get agentDirectoryDetectedDoesNotVerifyConnections =>
      '当前已知：DingDong 检测到声明的 Agent 目录。检测到目录或声明了路径，都不能证明 MCP、Hook、Bridge、鉴权或完成回调已连通；请在“Agent 连接”中验证本机 API 和真实完成回执。';

  @override
  String get agentDirectoryNotDetectedDoesNotVerifyConnections =>
      '当前已知：DingDong 未检测到声明的 Agent 目录。检测到目录或声明了路径，都不能证明 MCP、Hook、Bridge、鉴权或完成回调已连通；请在“Agent 连接”中验证本机 API 和真实完成回执。';

  @override
  String get codexDidNotReturnAVerifiableHookState => 'Codex 没有返回可验证的 Hook 状态。';

  @override
  String get thisHookIsManagedAndDisabledDingDongCannotChangeIt =>
      '这个 Hook 由外部策略托管且已停用，DingDong 无法修改。';

  @override
  String get thisManagedHookIsEnabledAndCanRunAfterTaskCompletion =>
      '这个托管 Hook 已启用，可在任务完成后运行。';

  @override
  String get theCurrentHashIsTrustedButThisHookIsDisabled =>
      '当前哈希已受信任，但这个 Hook 仍处于停用状态。';

  @override
  String get codexCanRunDingDongAfterATaskCompletes =>
      'Codex 可在任务完成后调用 DingDong。';

  @override
  String get theHookChangedAfterItsLastReviewCheckTheCurrentCommandAnd =>
      'Hook 在上次审核后发生了变化，请检查当前命令和哈希后再重新信任。';

  @override
  String get codexIsBlockingThisHookUntilItsExactCurrentHashIsTrusted =>
      'Codex 正在阻止这个 Hook，需确认并信任当前精确哈希后才会执行。';

  @override
  String get aDingDongHookExistsButItsCommandDoesNotExactlyMatchThis =>
      '已存在 DingDong Hook，但命令与当前安装的应用不完全一致，因此没有授予信任。';

  @override
  String get theExpectedDingDongStopHookIsNotConfiguredInCodex =>
      'Codex 中尚未配置预期的 DingDong Stop Hook。';

  @override
  String get thisCodexBuildCouldNotBeReachedThroughAppServerUseHooks =>
      '当前无法通过 App Server 连接这个 Codex 版本，请改用 /hooks 审核 Hook。';

  @override
  String get selectRefreshToReadTheCurrentStateFromCodex =>
      '点击刷新，从 Codex 读取当前状态。';

  @override
  String get readingTheCurrentHookDefinitionAndTrustStateFromCodex =>
      '正在从 Codex 读取当前 Hook 定义与信任状态。';

  @override
  String get verificationFailed => '验证失败';

  @override
  String get changedSinceReview => '审核后已发生变化';

  @override
  String get trustRequired => '需要信任';

  @override
  String get commandMismatch => '命令不匹配';

  @override
  String get hookNotConfigured => '尚未配置 Hook';

  @override
  String get codexUnavailable => 'Codex 不可用';

  @override
  String get onlyTheExactHookShownAboveAndItsCurrentHashWillBe =>
      '只会信任上面显示的精确 Hook 与当前哈希；以后 Hook 定义再次变化时仍需重新确认。';

  @override
  String get codexCompletionHook => 'Codex 完成 Hook';

  @override
  String get thisAdapterDoesNotDeclareBothGlobalAndProjectSkillPaths =>
      '这个 Adapter 没有同时声明全局与项目 Skill 路径。';

  @override
  String get thisAdapterDoesNotDeclareAPromptFile =>
      '这个 Adapter 没有声明 Prompt 文件。';

  @override
  String get promptConfigurationPath => 'Prompt 配置路径';

  @override
  String get thisAdapterDoesNotDeclareAnMCPFile => '这个 Adapter 没有声明 MCP 文件。';

  @override
  String get unavailableBecauseTheAdapterIsInvalid => 'Adapter 无效，无法读取检测路径。';

  @override
  String get yamlStructureAndDeclaredPathsPassedValidation =>
      'YAML 结构和声明路径已通过校验。';

  @override
  String get detectionIsNotConnectionVerification => '检测不等于连接验证';

  @override
  String agentAdapterCatalogSummary(
    Object configurationCount,
    Object detectedCount,
  ) {
    return '$configurationCount 个配置 · 检测到 $detectedCount 个目录';
  }

  @override
  String agentAdapterCatalogSummaryWithInvalid(
    Object configurationCount,
    Object detectedCount,
    Object invalidCount,
  ) {
    return '$configurationCount 个配置 · 检测到 $detectedCount 个目录 · $invalidCount 个无效';
  }

  @override
  String get openClipboard => '打开剪贴板';

  @override
  String get openConnectedDevices => '打开连接设备';

  @override
  String get clipboardMonitoringOn => '正在监听剪贴板';

  @override
  String get clipboardMonitoringPaused => '剪贴板监听已暂停';

  @override
  String get stopMonitoring => '停止监听';

  @override
  String get startMonitoring => '开始监听';

  @override
  String get quitDingDong => '退出 DingDong';

  @override
  String get quitDingDongDev => '退出 DingDong DEV';

  @override
  String dingDongUnreadCount(Object count) {
    return 'DingDong · $count 条未读内容';
  }

  @override
  String get connectedDevicesWindowTitle => 'DingDong · 连接设备';

  @override
  String get settingsWindowTitle => 'DingDong · 设置';

  @override
  String get developmentTestPanelWindowTitle => 'DingDong DEV · 测试面板';

  @override
  String get resourceManagerWindowTitle => 'DingDong · 资源管理';

  @override
  String connectDingDongToCurrentAgent(String commandPath) {
    return '请将「$commandPath」接入当前 Agent，配置为名为 dingdong 的用户级 STDIO MCP（不加 args），保留现有配置，并验证 dingdong_bridge。若支持用户级任务完成 Hook，再为任务完成事件配置 Hook 命令：同一程序加上「--notify-stop --source \"<当前 Agent 名称>\"」，并验证提醒。';
  }

  @override
  String get about => '关于';

  @override
  String get timeSingular => '次';

  @override
  String get timePlural => '次';

  @override
  String get agentNeedsYourAttention => 'Agent 需要你处理';

  @override
  String get agentCompleted => 'Agent 完成啦';

  @override
  String get mobileDevice => '移动设备';

  @override
  String get sharedFile => '共享文件';

  @override
  String fromDevice(Object name) {
    return '来自 $name';
  }

  @override
  String get dingDongComputer => 'DingDong 电脑';

  @override
  String get currentTask => '当前任务';

  @override
  String sourceCompletedCurrentTask(Object source) {
    return '$source 已完成本轮任务';
  }

  @override
  String get devAgentCompletedMessage => 'DEV 测试：Agent 已完成本轮任务';

  @override
  String get devAgentCompletedDetail => '这是测试面板生成的基础完成提醒，不代表真实 Agent 任务结果。';

  @override
  String get devCrossDeviceTaskCompletedMessage => 'DEV 测试：跨设备任务已完成';

  @override
  String get devCrossDeviceTaskCompletedDetail =>
      '这是测试面板生成的模拟完成说明，用来检查手机卡片的长描述、来源、完成时间与震动开关。它不代表真实 Agent 任务结果。';

  @override
  String devRepeatedAlertMessage(Object index) {
    return 'DEV 测试：连续提醒 $index/3';
  }

  @override
  String get devRepeatedAlertDetail => '用于检查未读数字、时间顺序和手机端连续接收；这是模拟测试数据。';

  @override
  String get devPhoneTextSampleTitle => 'DEV 手机文字样例';

  @override
  String get devPhoneTextSampleContent =>
      'DingDong DEV 测试：这段文字模拟用户在手机输入框粘贴内容并主动点击“发送”。';

  @override
  String get devTestPhoneSource => '来自 DEV 测试手机';

  @override
  String get devAutoSyncSampleTitle => 'DEV 电脑自动同步样例';

  @override
  String get devAutoSyncSampleContent =>
      'DingDong DEV 测试：由电脑创建，仅发送给开启“自动同步”的已连接设备。';

  @override
  String get devTestPanelSource => 'DingDong DEV 测试面板';

  @override
  String get devManualSendSampleTitle => 'DEV 主动发送样例';

  @override
  String get devManualSendSampleContent =>
      'DingDong DEV 测试：请选择一个已连接设备主动发送这条内容。';

  @override
  String get devPhoneFileBody =>
      'DingDong DEV 测试文件\n\n这是一份由测试面板创建的本地样例，用于模拟手机主动选择文件并点击发送。\n它不是来自真实手机，也不包含真实用户内容。\n';

  @override
  String get devPhoneFileSampleTitle => 'DingDong DEV 手机文件样例.txt';

  @override
  String get agentAPI => 'Agent API';

  @override
  String get audioFiles => '音频文件';

  @override
  String get chooseSoundFile => '选择声音';

  @override
  String get importThisFolder => '导入此文件夹';

  @override
  String get importAction => '导入';

  @override
  String get exportAction => '导出';

  @override
  String get jsonFiles => 'JSON 文件';

  @override
  String get jsonFile => 'JSON 文件';

  @override
  String get categoryRuleKeywordsExample => 'command, alias:build';

  @override
  String get httpsOrGitHubFileURL => 'HTTPS 或 GitHub 文件 URL';
}
