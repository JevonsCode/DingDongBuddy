// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'dingdong_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class DingDongLocalizationsEn extends DingDongLocalizations {
  DingDongLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get aNewVersionIsAvailable => 'A new version is available';

  @override
  String aSelectedLocalPathResourceCouldNotBeSharedError(Object error) {
    return 'A selected local-path resource could not be shared: $error';
  }

  @override
  String
  get aSkillMeansItsFullInstructionsWereLoadedForThisTaskAnMCP_240facd9 =>
      'A Skill * means its full instructions were loaded for this task. An MCP * means one of its tools was called, not that the call succeeded. Prompts stay unmarked.';

  @override
  String get aToolConnectionWhoseMCPToolsAreCalledOnlyWhenTheTask_08282426 =>
      'A tool connection whose MCP tools are called only when the task requires them.';

  @override
  String actionCountTimes(Object action, Object count, Object times) {
    return '$action $count $times';
  }

  @override
  String get activated => 'Activated';

  @override
  String get activated2 => 'activated';

  @override
  String get adapterVersionHistory => 'Adapter version history';

  @override
  String get addALocalNoteAboutHowYouUseThisSkill =>
      'Add a local note about how you use this Skill.';

  @override
  String get addAgentConfiguration => 'Add agent configuration';

  @override
  String get addAtLeastOneCompleteRule => 'Add at least one complete rule.';

  @override
  String get addOneOrMoreExistingAbsoluteProjectDirectories =>
      'Add one or more existing absolute project directories.';

  @override
  String get addProject => 'Add project';

  @override
  String get addRule => 'Add rule';

  @override
  String get addTitle => 'Add title';

  @override
  String get addToGroups => 'Add to groups';

  @override
  String get advancedAPIAndMCPDetails => 'Advanced API and MCP details';

  @override
  String get advancedCommandsAndTheInstallationPromptTheirPresence_b84b4903 =>
      'Advanced commands and the installation prompt. Their presence does not mean an Agent has been verified.';

  @override
  String get advancedMatching => 'Advanced matching';

  @override
  String get afterTheGlobalShortcutDingDongCanReturnFocusAndPasteThe_5ad1a82a =>
      'After the global shortcut, DingDong can return focus and paste the selected item.';

  @override
  String
  get afterUpdatingYouWillNeedToGrantDingDongSMacOSPermissions_20660ff5 =>
      'After updating, you will need to grant DingDong\'s macOS permissions again in System Settings.';

  @override
  String get agentActivity => 'Agent activity';

  @override
  String get agentAlerts => 'Agent alerts';

  @override
  String get agentAndClipboardItemsCreatedHereAreExplicitDEVTestData_f8625f9f =>
      'Agent and clipboard items created here are explicit DEV test data. Phone-origin samples are simulations, never captured from a real phone clipboard.';

  @override
  String get agentCompletion => 'Agent completion';

  @override
  String get agentCompletionNotifications => 'Agent completion notifications';

  @override
  String agentCompletionNotificationsForName(Object name) {
    return 'Agent completion notifications for $name';
  }

  @override
  String get agentCompletionSignal => 'Agent completion signal';

  @override
  String get agentConfigurationFileIsInvalid =>
      'Agent configuration file is invalid';

  @override
  String get agentConnectionCenter => 'Agent connection center';

  @override
  String get agentConnections => 'Agent connections';

  @override
  String get agentDecides => 'Agent decides';

  @override
  String get agentPluginProvidesTheSameSkill =>
      'Agent plugin provides the same Skill';

  @override
  String get agentReplyFooter => 'Agent reply footer';

  @override
  String get agentResourceSyncFailed => 'Agent resource sync failed';

  @override
  String get agentSessionLoadingName => 'Agent session loading name';

  @override
  String get agentSetupNeedsUpdate => 'Agent setup needs update';

  @override
  String get agentSetupPrompt => 'Agent setup prompt';

  @override
  String get agentSetupPromptNeedsUpdating =>
      'Agent setup prompt needs updating';

  @override
  String get agentSource => 'Agent source';

  @override
  String get all => 'All';

  @override
  String get allProjectsNoRestriction => 'All projects · no restriction';

  @override
  String get allSources => 'All sources';

  @override
  String get allowAgentsToReadClipboardContent =>
      'Allow Agents to read clipboard content';

  @override
  String get allowedByTheExplicitSettingsSwitch =>
      'Allowed by the explicit Settings switch';

  @override
  String get always => 'Always';

  @override
  String get anEnabledAgentPluginProvidesASkillWithTheSameNameBoth_c5e2f5ee =>
      'An enabled Agent plugin provides a Skill with the same name. Both remain available; review which one should be used.';

  @override
  String get anExistingUserManagedSkillWasPreservedDingDongDidNot_0f7d7c2a =>
      'An existing user-managed Skill was preserved. DingDong did not overwrite it.';

  @override
  String get anonymousInstallAndUpdateStatistics =>
      'Anonymous install and update statistics';

  @override
  String get apiAgentConnections => 'API | Agent connections';

  @override
  String apiListeningOnHostPort(Object host, Object port) {
    return 'API listening on $host:$port';
  }

  @override
  String get apiStatusUnverified => 'API status unverified';

  @override
  String get appearance => 'Appearance';

  @override
  String get applicationConfiguration => 'Application configuration';

  @override
  String get apply => 'Apply';

  @override
  String get archiveTo => 'Archive to…';

  @override
  String get archiveToGroups => 'Archive to groups';

  @override
  String get archivedCopiesRemainUnchanged =>
      'Archived copies remain unchanged.';

  @override
  String get argumentsOnePerLine => 'Arguments · one per line';

  @override
  String get autoSendClipboard => 'Auto send clipboard';

  @override
  String autoSendClipboardFromThisComputerToName(Object name) {
    return 'Auto send clipboard from this computer to $name';
  }

  @override
  String get availableToInstalledAgents => 'Available to installed Agents';

  @override
  String get backToCategories => 'Back to categories';

  @override
  String get backToDynamic => 'Back to Dynamic';

  @override
  String get backToResources => 'Back to resources';

  @override
  String get backToTop => 'Back to top';

  @override
  String get basicCompletion => 'Basic completion';

  @override
  String get bearerTokenEnv => 'Bearer token env';

  @override
  String get blue => 'Blue';

  @override
  String get called => 'Called';

  @override
  String get called2 => 'called';

  @override
  String get cancel => 'Cancel';

  @override
  String get cancelDevicePairing => 'Cancel device pairing';

  @override
  String get cancelPairing => 'Cancel pairing';

  @override
  String get candidate => 'Candidate';

  @override
  String get captureCurrentClipboard => 'Capture current clipboard';

  @override
  String get captureNow => 'Capture now';

  @override
  String get captureTextFilesAndImagesWhileDingDongIsRunning =>
      'Capture text, files, and images while DingDong is running.';

  @override
  String get caseSensitive => 'Case sensitive';

  @override
  String get category => 'Category';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNameIsRequired => 'Category name is required.';

  @override
  String get categoryRule => 'Category rule';

  @override
  String get check => 'Check';

  @override
  String get check2 => 'Check';

  @override
  String get check3 => 'Check';

  @override
  String get checkUnreadCountingOrderingAndRepeatedPhoneDelivery =>
      'Check unread counting, ordering, and repeated phone delivery.';

  @override
  String get checkUpdate => 'Check update';

  @override
  String get checking => 'Checking';

  @override
  String get checkingForUpdates => 'Checking for updates…';

  @override
  String get checkingLocalService => 'Checking local service';

  @override
  String get choose => 'Choose';

  @override
  String get chooseHowDingDongBehavesWhenYouSignIn =>
      'Choose how DingDong behaves when you sign in.';

  @override
  String get chooseRules => 'Choose rules';

  @override
  String get chooseWhichAgentEventsShouldNotifyYouThenCustomizeThe_7d9141e4 =>
      'Choose which Agent events should notify you, then customize the alert sound and color.';

  @override
  String get clean => 'Clean';

  @override
  String get clear => 'Clear';

  @override
  String get clearAll => 'Clear all';

  @override
  String clearCategory(Object category) {
    return 'Clear $category?';
  }

  @override
  String get clearCustomSound => 'Clear custom sound';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get clearSelection2 => 'Clear selection';

  @override
  String get clickAnywhereToCloseEsc => 'Click anywhere to close · Esc';

  @override
  String get clickToEnlargeQRCode => 'Click to enlarge QR code';

  @override
  String get clipboard => 'Clipboard';

  @override
  String get clipboardAndDevices => 'Clipboard and devices';

  @override
  String get clipboardBodyAccess => 'Clipboard body access';

  @override
  String get clipboardCategories => 'Clipboard categories';

  @override
  String get clipboardContent => 'Clipboard content';

  @override
  String
  get clipboardContentStaysMetadataOnlyUnlessExplicitlyEnabled_df1d930e =>
      'Clipboard content stays metadata-only unless explicitly enabled in Settings.';

  @override
  String get clipboardDatabase => 'Clipboard database';

  @override
  String get clipboardDetailsAndCompleteContent =>
      'Clipboard details and complete content';

  @override
  String get clipboardHistory => 'Clipboard history';

  @override
  String get clipboardHistory2 => 'Clipboard history';

  @override
  String get clipboardHistoryRemainsUnchanged =>
      'Clipboard history remains unchanged.';

  @override
  String get clipboardItem => 'Clipboard item.';

  @override
  String clipboardSortLabel(Object label) {
    return 'Clipboard sort: $label';
  }

  @override
  String get clipboardWorkspace => 'Clipboard workspace';

  @override
  String get clipboardWorkspaceShortcut => 'Clipboard workspace shortcut';

  @override
  String get close => 'Close';

  @override
  String get closeEnlargedView => 'Close enlarged view';

  @override
  String get code => 'Code';

  @override
  String get codexSubagent => 'Codex subagent';

  @override
  String get codexVoiceTaskNotifications => 'Codex voice task notifications';

  @override
  String get command => 'Command';

  @override
  String get command2 => 'Command';

  @override
  String get completionDetailsStayOnThisDeviceCountingMetadata_9920ce29 =>
      'Completion details stay on this device. Counting metadata contains timestamps only.';

  @override
  String get completionHistoryAndRecentCounts =>
      'Completion history and recent counts';

  @override
  String get completionNotificationsAreOffForThisDevice =>
      'Completion notifications are off for this device';

  @override
  String get configurationDetails => 'Configuration details';

  @override
  String get configurationSaved => 'Configuration saved';

  @override
  String get configureProjects => 'Configure projects';

  @override
  String
  get configureTheFinalDingDongResourceLineAndOptionallyAppend_e6f7cb62 =>
      'Configure the final DingDong resource line and optionally append exact session usage.';

  @override
  String get connectANewDevice => 'Connect a new device';

  @override
  String get connectedDevices => 'Connected devices';

  @override
  String get connecting => 'Connecting…';

  @override
  String get connection => 'Connection';

  @override
  String get connectionError => 'Connection error';

  @override
  String get connectionManager => 'Connection manager';

  @override
  String connectionTestFailedError(Object error) {
    return 'Connection test failed: $error';
  }

  @override
  String get connectionType => 'Connection type';

  @override
  String get contains => 'Contains';

  @override
  String get contains2 => 'contains';

  @override
  String get content => 'Content';

  @override
  String get contentQRCode => 'Content QR code';

  @override
  String get contentRegex => 'Content regex';

  @override
  String get contentRegularExpression => 'Content regular expression';

  @override
  String get contentType => 'Content type';

  @override
  String get contentTypes => 'Content types';

  @override
  String get copied => 'Copied';

  @override
  String copiedCountTimes(Object count) {
    return 'Copied $count times';
  }

  @override
  String get copiedFileReferencesOriginalFilesAreNeverDeleted =>
      'Copied file references; original files are never deleted';

  @override
  String get copy => 'Copy';

  @override
  String get copyContent => 'Copy content';

  @override
  String get copyCount => 'Copy count';

  @override
  String get copyCount2 => 'Copy count';

  @override
  String get coreEndpoints => 'Core endpoints';

  @override
  String couldNotApplyThisSkillDeliveryPolicyDetail(Object detail) {
    return 'Could not apply this Skill delivery policy. $detail';
  }

  @override
  String couldNotFetchThisUpdateError(Object error) {
    return 'Could not fetch this update: $error';
  }

  @override
  String couldNotImportThisResourceBundleError(Object error) {
    return 'Could not import this resource bundle: $error';
  }

  @override
  String get couldNotOpenThisAgentConversation =>
      'Could not open this Agent conversation.';

  @override
  String get couldNotOpenThisSkillSource => 'Could not open this Skill source.';

  @override
  String get couldNotReachTheSourceCheckYourNetworkAndLinkThenTry_1c1ff9ae =>
      'Could not reach the source. Check your network and link, then try again.';

  @override
  String get couldNotSaveThisConfigurationCheckTheContentAndTryAgain =>
      'Could not save this configuration. Check the content and try again.';

  @override
  String couldNotSyncThisResourceToAnInstalledAgentDetail(Object detail) {
    return 'Could not sync this resource to an installed Agent. $detail';
  }

  @override
  String countIssuesNeedAttention(Object count) {
    return '$count issues need attention';
  }

  @override
  String countItems(Object count) {
    return '$count items';
  }

  @override
  String countItemsDescription(Object count, Object description) {
    return '$count items · $description';
  }

  @override
  String countPairedDevices(Object count) {
    return '$count paired devices';
  }

  @override
  String countSelected(Object count) {
    return '$count selected';
  }

  @override
  String get countWindowHours => 'Count window (hours)';

  @override
  String get create => 'Create';

  @override
  String
  get createAComputerRecordAndSendItOnlyToConnectedDevicesWith_41a63724 =>
      'Create a computer record and send it only to connected devices with auto-send enabled.';

  @override
  String get createAQRCodeThenScanItWithTheDeviceYouTrust =>
      'Create a QR code, then scan it with the device you trust.';

  @override
  String get createASampleAndOpenTheRealTargetDeviceChooser =>
      'Create a sample and open the real target-device chooser.';

  @override
  String get createAndSend => 'Create and send';

  @override
  String get createOneClearlyLabeledDEVCompletion =>
      'Create one clearly labeled DEV completion.';

  @override
  String get createOneToStartOrganizingClipboardItems =>
      'Create one to start organizing clipboard items.';

  @override
  String get createResource => 'Create resource';

  @override
  String get createdBasicAgentCompletion => 'Created: basic Agent completion';

  @override
  String get createdComputerAutoSendSample =>
      'Created: computer auto-send sample';

  @override
  String get createdRichMobileAgentDetail =>
      'Created: rich mobile Agent detail';

  @override
  String get createdSimulatedPhoneFileRow =>
      'Created: simulated phone file row';

  @override
  String get createdSimulatedPhoneTextRow =>
      'Created: simulated phone text row';

  @override
  String get createdThreeAgentCompletions => 'Created: three Agent completions';

  @override
  String get createsRemovableDEVSamplesOrOpensTheRealDeviceWorkflow =>
      'Creates removable DEV samples or opens the real device workflow.';

  @override
  String get curatedContentReusableByAgents =>
      'Curated content reusable by agents';

  @override
  String get current => 'Current';

  @override
  String get currentAgentAccessClipboardRulesAndRuntimeState =>
      'Current Agent access, clipboard rules, and runtime state';

  @override
  String get currentMemory => 'Current memory';

  @override
  String get cursorCompatibleFormat => 'Cursor-compatible format';

  @override
  String get customFile => 'Custom file';

  @override
  String get customSound => 'Custom sound';

  @override
  String get dark => 'Dark';

  @override
  String get defaultOrder => 'Default order';

  @override
  String get defaultWorkspace => 'Default workspace';

  @override
  String get defineWhatContentBelongsInThisCategory =>
      'Define what content belongs in this category.';

  @override
  String get delete => 'Delete';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String deleteGroup2(Object group) {
    return 'Delete “$group”?';
  }

  @override
  String deleteName(Object name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteSelectedItems => 'Delete selected items?';

  @override
  String get deleteSelectedResources => 'Delete selected resources?';

  @override
  String get deleteThisArchivedCopy => 'Delete this archived copy?';

  @override
  String get deleteThisCategory => 'Delete this category?';

  @override
  String get deleteThisClipboardItem => 'Delete this clipboard item?';

  @override
  String get deleteThisDevice => 'Delete this device?';

  @override
  String get deleteThisResource => 'Delete this resource?';

  @override
  String get deleteThisResource2 => 'Delete this resource?';

  @override
  String get deletedHistoryCannotBeRestored =>
      'Deleted history cannot be restored.';

  @override
  String get deliveryByAgent => 'Delivery by Agent';

  @override
  String get describeTheBehaviorTheAgentShouldFollow =>
      'Describe the behavior the Agent should follow.';

  @override
  String get desktopBehaviorHistoryPrivacyAndLocalAgentConnectivity =>
      'Desktop behavior, history privacy, and local agent connectivity.';

  @override
  String get desktopNotification => 'Desktop notification';

  @override
  String get details => 'Details';

  @override
  String get dingdongBright => 'DingDong Bright';

  @override
  String
  get dingdongChecksAutomaticallyWhenResourcesChangeUseCheckIn_ab07f57c =>
      'DingDong checks automatically when resources change. Use Check in the upper-right corner to run it again.';

  @override
  String get dingdongClassic => 'DingDong Classic';

  @override
  String get dingdongCopiesTheCompleteSkillPackageIntoEachSelected_de26f089 =>
      'DingDong copies the complete Skill package into each selected project\'s native directory. The Skill is discovered only when that Agent works in the project.';

  @override
  String get dingdongCrisp => 'DingDong Crisp';

  @override
  String dingdongCurrentAppVersionDesktop(Object currentAppVersion) {
    return 'DingDong $currentAppVersion · Desktop';
  }

  @override
  String get dingdongDeep => 'DingDong Deep';

  @override
  String get dingdongDeviceConnectionManager =>
      'DingDong device connection manager';

  @override
  String dingdongHasRecordedTheseLocalStatisticsSinceDateEarlier_90d48aa0(
    Object date,
  ) {
    return 'DingDong has recorded these local statistics since $date. Earlier activity is not backfilled, so 0 does not necessarily mean this resource was never used.';
  }

  @override
  String get dingdongListensOnlyOnTheLocalLoopbackInterface =>
      'DingDong listens only on the local loopback interface.';

  @override
  String get dingdongOwnedImageCopiesAndRecords =>
      'DingDong-owned image copies and records';

  @override
  String
  get dingdongPreservedTheExistingAgentFileBecauseItCouldNotBe_6c5484e5 =>
      'DingDong preserved the existing Agent file because it could not be parsed safely.';

  @override
  String get dingdongResourceManagerWindow =>
      'DingDong resource manager window';

  @override
  String get dingdongSettingsWindow => 'DingDong settings window';

  @override
  String get dingdongSkillsUseTheSameName =>
      'DingDong Skills use the same name';

  @override
  String get dingdongSoft => 'DingDong Soft';

  @override
  String get disable => 'Disable';

  @override
  String get disableCategory => 'Disable category';

  @override
  String get disableResource => 'Disable resource';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get discardUnsavedChanges => 'Discard unsaved changes?';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get downloadingUpdate => 'Downloading update…';

  @override
  String downloadingUpdatePercent(Object percent) {
    return 'Downloading update… $percent%';
  }

  @override
  String get dynamicLoadsOnDemandThroughDingDongNativeGlobalInstalls_ff4bd6e5 =>
      'Dynamic loads on demand through DingDong. Native · Global installs in the Agent user directory. Native · Project installs only in selected projects.';

  @override
  String get dynamicMessage => 'Dynamic';

  @override
  String get dynamicWorkspace => 'Dynamic workspace';

  @override
  String get dynamicWorkspaceShortcut => 'Dynamic workspace shortcut';

  @override
  String get eGConciseReleaseNotes => 'e.g. Concise release notes';

  @override
  String get eGDingDongProjects => 'e.g. DingDong projects';

  @override
  String get eGFigma => 'e.g. Figma';

  @override
  String get eGProjectDrafts => 'e.g. Project drafts';

  @override
  String get eachProjectMustBeAnExistingAbsoluteDirectory =>
      'Each project must be an existing absolute directory.';

  @override
  String get edit => 'Edit';

  @override
  String get editAndOrganize => 'Edit and organize';

  @override
  String get editProjectGroup => 'Edit project group';

  @override
  String get editRules => 'Edit rules';

  @override
  String get editText => 'Edit text';

  @override
  String get editTitle => 'Edit title';

  @override
  String get editTriggerGroup => 'Edit trigger group';

  @override
  String get email => 'Email';

  @override
  String get enable => 'Enable';

  @override
  String get enableCategory => 'Enable category';

  @override
  String get enableResource => 'Enable resource';

  @override
  String get enableResourcesFromTheLibraryToSeeThemHere =>
      'Enable resources from the library to see them here.';

  @override
  String get enabled => 'Enabled';

  @override
  String get enabled2 => 'Enabled';

  @override
  String get enabledPhoneVibrationIsOff => 'Enabled · Phone vibration is off';

  @override
  String get enabledPhoneVibrationIsOn => 'Enabled · Phone vibration is on';

  @override
  String get endpointsCommandsAndSetupPrompt =>
      'Endpoints, commands, and setup prompt';

  @override
  String get enlargeQRCode => 'Enlarge QR code';

  @override
  String get enterATriggerGroupName => 'Enter a trigger-group name.';

  @override
  String get enterAValidWebSourceBeforeOpeningIt =>
      'Enter a valid web source before opening it.';

  @override
  String get enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved =>
      'Enter one visible symbol. Asterisk and vertical bar are reserved.';

  @override
  String get environment => 'Environment';

  @override
  String get equals => 'Equals';

  @override
  String get equals2 => 'equals';

  @override
  String get executablePathNpxUvx => 'Executable path, npx, uvx…';

  @override
  String get exerciseRealDingDongIntegrationPathsFromOnePlace =>
      'Exercise real DingDong integration paths from one place.';

  @override
  String get exportJSON => 'Export JSON';

  @override
  String exportedResourceLibraryToPath(Object path) {
    return 'Exported resource library to $path';
  }

  @override
  String get fetchAndReview => 'Fetch and review';

  @override
  String get fetchLatestContent => 'Fetch latest content';

  @override
  String get file => 'File';

  @override
  String get fileFromPhone => 'File from phone';

  @override
  String get fileHistory => 'File history';

  @override
  String get files => 'Files';

  @override
  String get findIcon => 'Find icon';

  @override
  String get forExampleProjectLinks => 'For example: Project links';

  @override
  String get general => 'General';

  @override
  String get gotIt => 'Got it';

  @override
  String get green => 'Green';

  @override
  String get group => 'Group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupRepeatedSessions => 'Group repeated sessions';

  @override
  String get groups => 'Groups';

  @override
  String get groups2 => 'Groups';

  @override
  String get headers => 'Headers';

  @override
  String get healthCheckFailed => 'Health check failed';

  @override
  String get healthCheckPassed => 'Health check passed';

  @override
  String get hideCategoriesAndGroups => 'Hide categories and groups';

  @override
  String get hideDockIcon => 'Hide Dock icon';

  @override
  String get hideInConversation => 'Hide in conversation';

  @override
  String get hideMessage => 'Hide';

  @override
  String get historyStaysOnThisDeviceAgentAccessToClipboardContentIs_74a8f236 =>
      'History stays on this device. Agent access to clipboard content is controlled below.';

  @override
  String get horizontalNudge => 'Horizontal nudge';

  @override
  String hoursHCount(Object hours, Object count) {
    return '$hours h · $count';
  }

  @override
  String get httpsExampleComDingdongResourcesJson =>
      'https://example.com/dingdong-resources.json';

  @override
  String get image => 'Image';

  @override
  String get imageCache => 'Image cache';

  @override
  String get images => 'Images';

  @override
  String
  get imagesTextAndFilesAreIndependentCleaningThemNeverRemoves_cb27e3f9 =>
      'Images, text, and files are independent. Cleaning them never removes permanent archives.';

  @override
  String get impeccableProjectHookApprovalRequiredInHooks =>
      'Impeccable project Hook (approval required in /hooks)';

  @override
  String get importFromLink => 'Import from link';

  @override
  String get importHistory => 'Import history';

  @override
  String get importJSONFile => 'Import JSON file';

  @override
  String importLengthResources(Object length) {
    return 'Import $length resources';
  }

  @override
  String importedImportedCountSkippedSkippedCount(
    Object importedCount,
    Object skippedCount,
  ) {
    return 'Imported $importedCount; skipped $skippedCount.';
  }

  @override
  String get importedKnowledgeAvailableToAgentContext =>
      'Imported knowledge available to Agent context.';

  @override
  String importedLengthSkippedSkippedCountSuffix(
    Object length,
    Object skippedCount,
    Object suffix,
  ) {
    return 'Imported $length; skipped $skippedCount.$suffix';
  }

  @override
  String get includeAtLeastOneModifierKey =>
      'Include at least one modifier key.';

  @override
  String get independentCopiesProtectedFromHistoryCleanup =>
      'Independent copies protected from history cleanup';

  @override
  String get installInAnyOfTheseProjects => 'Install in any of these projects';

  @override
  String get installSkill => 'Install Skill';

  @override
  String get installedFromAnOnlineSource => 'Installed from an online source';

  @override
  String get installedSkillPackageSKILLMd =>
      'Installed Skill package · SKILL.md';

  @override
  String get installingAndRestarting => 'Installing and restarting…';

  @override
  String get instructions => 'Instructions';

  @override
  String issuecountIssueSNeedAttention(Object issueCount) {
    return '$issueCount issue(s) need attention';
  }

  @override
  String get issues => 'Issues';

  @override
  String get jsonTOMLOrYAMLConfiguration => 'JSON, TOML, or YAML configuration';

  @override
  String get keepDingDongInTheMenuBarWithoutShowingItInTheDock =>
      'Keep DingDong in the menu bar without showing it in the Dock.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get keepTheSameConversationIDInOneItemShowNAndDoNotIncrease_925894bb =>
      'Keep the same conversation ID in one item, show ×N, and do not increase the recent count.';

  @override
  String get keepTheWorkspaceComfortableInYourCurrentDesktop_41d3bc46 =>
      'Keep the workspace comfortable in your current desktop environment.';

  @override
  String get keepThisItemEasyToFindAcrossMultipleGroups =>
      'Keep this item easy to find across multiple groups.';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get knowledge => 'Knowledge';

  @override
  String
  get knowledgeIsCollectedFromImportsAndAgentContextItCannotBe_08bd7ed0 =>
      'Knowledge is collected from imports and Agent context; it cannot be newly authored here yet.';

  @override
  String get knownConfigurationIssues => 'Known configuration issues';

  @override
  String get language => 'Language';

  @override
  String lastDateTime(Object date, Object time) {
    return 'Last $date $time';
  }

  @override
  String lastReceivedFromSourceAtCompletedAt(
    Object source,
    Object completedAt,
  ) {
    return 'Last received from $source at $completedAt';
  }

  @override
  String get latest => 'Latest';

  @override
  String get launchAtStartup => 'Launch at startup';

  @override
  String get leaveEmptyToUseTheResourceTitle =>
      'Leave empty to use the resource title.';

  @override
  String lengthDuplicates(Object length) {
    return '$length duplicates';
  }

  @override
  String lengthIDConflicts(Object length) {
    return '$length ID conflicts';
  }

  @override
  String lengthOnlineSourcesChecked(Object length) {
    return '$length online sources checked';
  }

  @override
  String get lengthRange => 'Length range';

  @override
  String lengthResults(Object length) {
    return '$length results';
  }

  @override
  String lengthSelected(Object length) {
    return '$length selected';
  }

  @override
  String lengthSources(Object length) {
    return '$length sources';
  }

  @override
  String get libraryMessage => 'Library';

  @override
  String get libraryWorkspace => 'Library workspace';

  @override
  String get libraryWorkspaceShortcut => 'Library workspace shortcut';

  @override
  String get light => 'Light';

  @override
  String get link => 'Link';

  @override
  String get links => 'Links';

  @override
  String get loadThisResourceWithoutShowingItsNameInTheAgent_ec7e075b =>
      'Load this resource without showing its name in the Agent conversation.';

  @override
  String get loaded => 'Loaded';

  @override
  String get loaded2 => 'loaded';

  @override
  String get local => 'Local';

  @override
  String get localAPI => 'Local API';

  @override
  String get localAuthoring => 'Local authoring';

  @override
  String get localData => 'Local data';

  @override
  String get localPort => 'Local port';

  @override
  String get localServiceUnavailable => 'Local service unavailable';

  @override
  String get localServiceVerified => 'Local service verified';

  @override
  String get lowercaseHyphenName => 'lowercase-hyphen-name';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get manage => 'Manage';

  @override
  String get manageAgents => 'Manage Agents';

  @override
  String get manageCategories => 'Manage categories';

  @override
  String get manual => 'Manual';

  @override
  String get markAsUpdated => 'Mark as updated';

  @override
  String get matchAProjectPathRepositoryOrAgentSource =>
      'Match a project path, repository, or Agent source.';

  @override
  String get matchAnyOfTheseRules => 'Match any of these rules';

  @override
  String get matchedByDescriptionThenLoadedAsACompleteSkillPackage_fa102bfe =>
      'Matched by description, then loaded as a complete Skill package only when needed.';

  @override
  String get matchesEverything => 'Matches everything';

  @override
  String get maximumCharacters => 'Maximum characters';

  @override
  String get maximumDetailedItems => 'Maximum detailed items';

  @override
  String get maximumItems => 'Maximum items';

  @override
  String get maximumLengthCannotBeNegative =>
      'Maximum length cannot be negative.';

  @override
  String get mcpAccess => 'MCP access';

  @override
  String get mcpConfigurationIsInvalid => 'MCP configuration is invalid';

  @override
  String get mcpFooterSymbol => 'MCP footer symbol';

  @override
  String get mcpSymbol => 'MCP symbol';

  @override
  String get menuBarAlertColor => 'Menu bar alert color';

  @override
  String get menuBarIconHiddenByTheCameraHousing =>
      'Menu bar icon hidden by the camera housing';

  @override
  String get menuBarMascot => 'Menu-bar mascot';

  @override
  String get metadataOnly => 'Metadata only';

  @override
  String get minimumCharacters => 'Minimum characters';

  @override
  String get minimumLengthCannotBeNegative =>
      'Minimum length cannot be negative.';

  @override
  String get minimumLengthCannotExceedMaximumLength =>
      'Minimum length cannot exceed maximum length.';

  @override
  String get mockAddAPhoneOriginTextRowWithoutReadingAnyPhone_381a76fb =>
      'MOCK: add a phone-origin text row without reading any phone clipboard.';

  @override
  String get mockCreateASmallLocalFileAndShowItsDeviceSource =>
      'MOCK: create a small local file and show its device source.';

  @override
  String get monitorClipboardChanges => 'Monitor clipboard changes';

  @override
  String get more => 'More';

  @override
  String get moreActions => 'More actions';

  @override
  String get muted => 'Muted';

  @override
  String get myNote => 'My note';

  @override
  String get name => 'Name';

  @override
  String get nameMySkillDescriptionUseWhenInstructions =>
      '---\nname: my-skill\ndescription: Use when…\n---\n\n# Instructions';

  @override
  String get nativeProject => 'Native · Project';

  @override
  String get nativeUser => 'Native · User';

  @override
  String get needsYourInput => 'Needs your input';

  @override
  String get needsYourInput2 => 'Needs your input';

  @override
  String get never => 'Never';

  @override
  String get newCategory => 'New category';

  @override
  String get newConfiguration => 'New configuration';

  @override
  String get newGroup => 'New group';

  @override
  String get newProjectGroup => 'New project group';

  @override
  String get newResource => 'New resource';

  @override
  String get newTriggerGroup => 'New trigger group';

  @override
  String get newestFirstClickAResumableItemToReturnToItsConversation =>
      'Newest first. Click a resumable item to return to its conversation.';

  @override
  String get noAgentCompletionsYet => 'No Agent completions yet';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String get noConnectedDevicesYet => 'No connected devices yet';

  @override
  String get noDeviceIsOnlineConnectOneFirst =>
      'No device is online. Connect one first.';

  @override
  String get noIssuesFound => 'No issues found';

  @override
  String get noKnownIssueThisIsNotAConnectionGuarantee =>
      'No known issue; this is not a connection guarantee';

  @override
  String get noMatchingGroups => 'No matching groups';

  @override
  String get noMatchingResources => 'No matching resources';

  @override
  String get noMatchingSources => 'No matching sources';

  @override
  String get noMatchingTriggerGroups => 'No matching trigger groups';

  @override
  String get noProjectGroupsYet => 'No project groups yet';

  @override
  String get noProjectSelected => 'No project selected';

  @override
  String get noRealAgentCompletionHasBeenReceivedYet =>
      'No real Agent completion has been received yet';

  @override
  String get noRecentAgentEvents => 'No recent agent events';

  @override
  String get noResourceImportsYet => 'No resource imports yet.';

  @override
  String get noSoundSelected => 'No sound selected';

  @override
  String get noTriggerGroupsYet => 'No trigger groups yet';

  @override
  String get noUpdateMetadataYet => 'No update metadata yet';

  @override
  String get notInstalled => 'Not installed';

  @override
  String notInstalledAgentsLength(Object length) {
    return 'Not installed Agents ($length)';
  }

  @override
  String get notVerified => 'Not verified';

  @override
  String get notifications => 'Notifications';

  @override
  String get notify => 'Notify';

  @override
  String get notifyWhenAnAgentFinishesItsCurrentTaskTurn =>
      'Notify when an Agent finishes its current task turn.';

  @override
  String get notifyWhenAnAgentIsWaitingForConfirmationAChoiceOrYour_825d0876 =>
      'Notify when an Agent is waiting for confirmation, a choice, or your takeover.';

  @override
  String get nudgeTheTrayMascotLikeAnOverdueReminder =>
      'Nudge the tray mascot like an overdue reminder.';

  @override
  String get offByDefaultMetadataStaysAvailableSensitiveRecordsStill_fa1a5f8f =>
      'Off by default. Metadata stays available; sensitive records still require an explicit request when enabled.';

  @override
  String get offline => 'Offline';

  @override
  String get onByDefaultSendsOneEventAfterInstallationOrAVersion_153fb4ab =>
      'On by default. Sends one event after installation or a version update with a random installation ID, app version, operating system, and architecture. No activity, feature usage, clipboard content, files, or Agent messages are sent. The implementation is open source, and you can turn this off at any time.';

  @override
  String get oneWayAutoSend => 'One-way auto send';

  @override
  String get online => 'Online';

  @override
  String onlineOnlineTitles(Object onlineTitles) {
    return 'Online: $onlineTitles';
  }

  @override
  String get onlineSkillUpdated => 'Online Skill updated';

  @override
  String get onlineSync => 'Online sync';

  @override
  String
  get onlineSyncIsNotReadyInThisWindowReopenResourceManagerAnd_2ceb1f90 =>
      'Online sync is not ready in this window. Reopen Resource Manager and try again.';

  @override
  String get onlyActiveInItsConfiguredTriggerScope =>
      'Only active in its configured trigger scope';

  @override
  String get onlyDingDongSLocalFileReferencesAreRemovedOriginalFiles_aea4cfa6 =>
      'Only DingDong\'s local file references are removed. Original files and folders stay untouched.';

  @override
  String get onlyExactExistingProjectDirectoriesCanReceiveANative_7c3d0f93 =>
      'Only exact, existing project directories can receive a native Skill.';

  @override
  String get onlyImageCopiesInsideDingDongSCacheAreRemovedSource_28dfcaa2 =>
      'Only image copies inside DingDong\'s cache are removed. Source images elsewhere stay untouched.';

  @override
  String get onlyTextRecordsStoredByDingDongAreRemoved =>
      'Only text records stored by DingDong are removed.';

  @override
  String get onlyTheConfiguredPreferredPortIsKnown =>
      'Only the configured preferred port is known.';

  @override
  String get open => 'Open';

  @override
  String get openAgentConversation => 'Open Agent conversation';

  @override
  String openCategoryLocation(Object category) {
    return 'Open $category location';
  }

  @override
  String get openDingDongDataFolder => 'Open DingDong data folder';

  @override
  String get openDingDongImageCache => 'Open DingDong image cache';

  @override
  String get openFileWithSystemApp => 'Open file with system app';

  @override
  String get openForDetailsOrRetry => 'Open for details or retry.';

  @override
  String get openLinkWithSystemBrowser => 'Open link with system browser';

  @override
  String get openOrHideClipboard => 'Open or hide clipboard';

  @override
  String get openPathWithSystemApp => 'Open path with system app';

  @override
  String get openPermissionHelper => 'Open permission helper';

  @override
  String get openSettings => 'Open settings';

  @override
  String get openSource => 'Open source';

  @override
  String get openTheStandaloneQRDeviceSwitchDisconnectAndDelete_441119af =>
      'Open the standalone QR, device, switch, disconnect, and delete surface.';

  @override
  String openTitle(Object title) {
    return 'Open $title';
  }

  @override
  String get openedConnectionManager => 'Opened: connection manager';

  @override
  String get openedSendToDeviceChooser => 'Opened: send-to-device chooser';

  @override
  String get optional => 'Optional';

  @override
  String get optional2 => 'Optional';

  @override
  String get orange => 'Orange';

  @override
  String get organizeClipboardItem => 'Organize clipboard item';

  @override
  String get otherLocalFiles => 'Other local files';

  @override
  String get otherSettings => 'Other settings';

  @override
  String get pairATrustedDeviceAndChooseWhatThisComputerSends =>
      'Pair a trusted device and choose what this computer sends.';

  @override
  String get pairingDoesNotCopyContentByItself =>
      'Pairing does not copy content by itself.';

  @override
  String pairingQRCodeForName(Object name) {
    return 'Pairing QR code for $name';
  }

  @override
  String get paste => 'Paste';

  @override
  String get pasteAGitHubSkillRepositoryFolderOrDirectSKILLMdLink_1ee790e1 =>
      'Paste a GitHub Skill repository, folder, or direct SKILL.md link.\nExamples:\nhttps://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste\nhttps://github.com/mattpocock/skills/tree/main/skills/productivity/grilling';

  @override
  String get pasteAJSONBundleLinkDingDongWillFetchItResolveItsOnline_cb404168 =>
      'Paste a JSON bundle link. DingDong will fetch it, resolve its online resources, and show the sources for review before importing.';

  @override
  String get pasteAsPlainText => 'Paste as Plain Text';

  @override
  String get pasteConfig => 'Paste config';

  @override
  String get pasteAgentSetupInstructionDescription =>
      'Paste this short instruction into a local Agent. It includes this installation’s exact MCP path, keeps existing settings intact, and adds the completion alert only when supported.';

  @override
  String get path => 'Path';

  @override
  String get permanentArchives => 'Permanent archives';

  @override
  String get permanentArchivesAndTheirImageFilesAreProtectedAndWill_889010d8 =>
      'Permanent archives and their image files are protected and will stay intact.';

  @override
  String get permissionGranted => 'Permission granted';

  @override
  String get permissionRequired => 'Permission required';

  @override
  String get permissionStatusUnavailable => 'Permission status unavailable';

  @override
  String get pin => 'Pin';

  @override
  String get pinInLibrary => 'Pin in library';

  @override
  String get pink => 'Pink';

  @override
  String get pinned => 'Pinned';

  @override
  String get plainText => 'Plain text';

  @override
  String get portChangesApplyTheNextTimeDingDongStarts =>
      'Port changes apply the next time DingDong starts.';

  @override
  String preferredPortPreferredPortWasUnavailableUsingActualPort(
    Object preferredPort,
    Object actualPort,
  ) {
    return 'Preferred port $preferredPort was unavailable; using $actualPort.';
  }

  @override
  String get preparingUpdate => 'Preparing update…';

  @override
  String get pressAShortcut => 'Press a shortcut…';

  @override
  String get pressToRecordADifferentShortcut =>
      'Press to record a different shortcut';

  @override
  String get preview => 'Preview';

  @override
  String get previewImageWithSystemApp => 'Preview image with system app';

  @override
  String get previewRealTrayStatesWithoutCreatingHistoryRecords =>
      'Preview real tray states without creating history records.';

  @override
  String get previewSound => 'Preview sound';

  @override
  String get priorityFirstMatchWins => 'Priority · first match wins';

  @override
  String priorityIndexDragToReorder(Object index) {
    return 'Priority $index · drag to reorder';
  }

  @override
  String get privateHistoryMetadata => 'Private history metadata';

  @override
  String get projectDirectory => 'Project directory';

  @override
  String get projectDirectoryEquals => 'Project directory · Equals';

  @override
  String get projectInstallationScope => 'Project installation scope';

  @override
  String get projectSkillPathIsInvalid => 'Project Skill path is invalid';

  @override
  String get prompt => 'Prompt';

  @override
  String get promptFooterSymbol => 'Prompt footer symbol';

  @override
  String get promptName => 'Prompt name';

  @override
  String get promptSymbol => 'Prompt symbol';

  @override
  String get prompts => 'Prompts';

  @override
  String get promptsSkillsMCPResourcesAndTriggerScopes =>
      'Prompts, Skills, MCP resources, and trigger scopes';

  @override
  String get protectedData => 'Protected data';

  @override
  String get protectedDataIsNotClearedHere =>
      'Protected data is not cleared here';

  @override
  String get purple => 'Purple';

  @override
  String get qrCode => 'QR code';

  @override
  String get quickPasteNeedsAccessibilityPermission =>
      'Quick paste needs Accessibility permission.';

  @override
  String get quickPastePermission => 'Quick paste permission';

  @override
  String get quickPastePermissionGranted => 'Quick paste permission granted';

  @override
  String get readOnly => 'Read-only';

  @override
  String get recentAgents => 'Recent agents';

  @override
  String get recheckLocalService => 'Recheck local service';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get reconnectThisAgent => 'Reconnect this Agent';

  @override
  String get refreshStatus => 'Refresh status';

  @override
  String get regularExpressionIsInvalid => 'Regular expression is invalid.';

  @override
  String get release => 'Release';

  @override
  String get rememberAfterRestart => 'Remember after restart';

  @override
  String get removeFromSelection => 'Remove from selection';

  @override
  String get removeRule => 'Remove rule';

  @override
  String get reorder => 'Reorder';

  @override
  String repeatcountNotificationsForThisConversation(Object repeatCount) {
    return '$repeatCount notifications for this conversation';
  }

  @override
  String get reportAProblem => 'Report a problem';

  @override
  String get repositoryAddress => 'Repository address';

  @override
  String get requestAFeature => 'Request a feature';

  @override
  String get requiredInstructionsThatAreAppliedAutomaticallyWhenever_7564e51c =>
      'Required instructions that are applied automatically whenever active.';

  @override
  String get reset => 'Reset';

  @override
  String get reset2 => 'Reset';

  @override
  String get resetChanges => 'Reset changes';

  @override
  String resetSemanticLabel(Object semanticLabel) {
    return 'Reset $semanticLabel';
  }

  @override
  String get resource => 'Resource';

  @override
  String get resourceActions => 'Resource actions';

  @override
  String get resourceLibrary => 'Resource library';

  @override
  String get resourceLibrary2 => 'Resource library';

  @override
  String get resourceManager => 'Resource manager';

  @override
  String get resources => 'Resources';

  @override
  String get resourcesBecomeAvailableWhenASelectedGroupMatchesThis_ae977468 =>
      'Resources become available when a selected group matches this project or Agent source.';

  @override
  String get resourcesUsingThisGroupWillBecomeUnrestricted =>
      'Resources using this group will become unrestricted.';

  @override
  String get restart => 'Restart';

  @override
  String get restore => 'Restore';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get restoreOneHistoryItem => 'Restore one history item';

  @override
  String get retentionDays => 'Retention days';

  @override
  String get returnedAsACandidate => 'returned as a candidate';

  @override
  String get reviewOnlineResources => 'Review online resources';

  @override
  String get reviewResourceSyncAgentConfigurationAndAnythingElseThat_a562ea61 =>
      'Review resource sync, Agent configuration, and anything else that needs attention.';

  @override
  String
  get reviewTheSkillBeforeInstallingDingDongSavesTheFullFolder_1375b575 =>
      'Review the Skill before installing. DingDong saves the full folder, including scripts and references; updates stay manual.';

  @override
  String get richMobileDetail => 'Rich mobile detail';

  @override
  String ruleAndItsMatchingConditionsWillBeRemovedClipboardItems_48d9a089(
    Object rule,
  ) {
    return '“$rule” and its matching conditions will be removed. Clipboard items are not deleted.';
  }

  @override
  String get rulesRunFromTopToBottomTheFirstMatchWins =>
      'Rules run from top to bottom; the first match wins.';

  @override
  String get run => 'Run';

  @override
  String get running => 'Running…';

  @override
  String get runningTest => 'Running test…';

  @override
  String get runtimeCheck => 'Runtime check';

  @override
  String get runtimeStatusUnverified => 'Runtime status unverified';

  @override
  String get save => 'Save';

  @override
  String get saveAsPrompt => 'Save as prompt';

  @override
  String get saveCategory => 'Save category';

  @override
  String get saveGroup => 'Save group';

  @override
  String get saved => 'Saved';

  @override
  String savedAsSKILLMdNameName(Object name) {
    return 'Saved as SKILL.md · name: $name';
  }

  @override
  String get savedYAMLRevisionsCurrentAdaptersStayIntact =>
      'Saved YAML revisions; current Adapters stay intact';

  @override
  String get saving => 'Saving…';

  @override
  String get scanToConnect => 'Scan to connect';

  @override
  String get scanToShareClickToEnlarge => 'Scan to share · Click to enlarge';

  @override
  String get scanWithTheDeviceYouWantToTrust =>
      'Scan with the device you want to trust.';

  @override
  String get scope => 'Scope';

  @override
  String get scoped => 'Scoped';

  @override
  String get searchClipboard => 'Search clipboard';

  @override
  String get searchClipboardHistory => 'Search clipboard history';

  @override
  String get searchGroups => 'Search groups';

  @override
  String get searchNameOrContent => 'Search name or content';

  @override
  String get searchNamesOrRules => 'Search names or rules';

  @override
  String get searchPromptsSkillsAndMCP => 'Search prompts, skills, and MCP';

  @override
  String get searchResources => 'Search resources';

  @override
  String get searchSources => 'Search sources';

  @override
  String get seeWhatDingDongStoresLocallyAndCleanOnlyTheHistoryYou_a955b365 =>
      'See what DingDong stores locally and clean only the history you choose.';

  @override
  String get selectAConfigurationToInspectOrEdit =>
      'Select a configuration to inspect or edit';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectAnItemToPreview => 'Select an item to preview';

  @override
  String get selectItem => 'Select item';

  @override
  String get selectItem2 => 'Select item';

  @override
  String selectioncountResourcesSelected(Object selectionCount) {
    return '$selectionCount resources selected';
  }

  @override
  String selectioncountSelected(Object selectionCount) {
    return '$selectionCount selected';
  }

  @override
  String semanticlabelWaitingForAShortcut(Object semanticLabel) {
    return '$semanticLabel, waiting for a shortcut';
  }

  @override
  String get send3 => 'Send 3';

  @override
  String get sendTestNotification => 'Send test notification';

  @override
  String get sendTheOneLineSetupRequestToEachAffectedAgentMarkIt_3a68e15f =>
      'Send the one-line setup request to each affected Agent. Mark it complete after the Agent verifies both MCP and completion alerts.';

  @override
  String get sendToDevice => 'Send to device';

  @override
  String get sendToDeviceDialog => 'Send to device dialog';

  @override
  String get sensitiveContentHidden => 'Sensitive content hidden';

  @override
  String get serverName => 'Server name';

  @override
  String get serverURL => 'Server URL';

  @override
  String get serviceHealth => 'Service health';

  @override
  String get setTheSystemWidePanelShortcutAndTheShortcutsUsedInside_4f5138fb =>
      'Set the system-wide panel shortcut and the shortcuts used inside the focused panel.';

  @override
  String get settings => 'Settings';

  @override
  String get settings2 => 'Settings';

  @override
  String get sharedDatabaseFiles => 'Shared database files';

  @override
  String shortcutReady(Object shortcut) {
    return '$shortcut ready';
  }

  @override
  String get showCategoriesAndGroups => 'Show categories and groups';

  @override
  String get showCategoriesAndGroupsFiltersActive =>
      'Show categories and groups (filters active)';

  @override
  String get showConversationTokenUsage => 'Show conversation Token usage';

  @override
  String get showMessage => 'Show';

  @override
  String get showPairingQR => 'Show pairing QR';

  @override
  String get showQRCodeToPairATrustedDevice =>
      'Show QR code to pair a trusted device';

  @override
  String get showTheSleepingMascotBrieflyThenRestoreTheCurrentState =>
      'Show the sleeping mascot briefly, then restore the current state.';

  @override
  String get shownOnlyWhenCodexClaudeCodeOrPiProvidesExactLocalUsage_7e557397 =>
      'Shown only when Codex, Claude Code, or Pi provides exact local usage. Unsupported Agents are not estimated.';

  @override
  String get skill => 'Skill';

  @override
  String get skill2 => 'Skill';

  @override
  String get skillConfigurationIsInvalid => 'Skill configuration is invalid';

  @override
  String get skillFooterSymbol => 'Skill footer symbol';

  @override
  String get skillMdContent => 'SKILL.md content';

  @override
  String get skillMdNeedsValidNameAndDescriptionFieldsInItsYAML_c05294f5 =>
      'SKILL.md needs valid name and description fields in its YAML frontmatter.';

  @override
  String get skillName => 'Skill name';

  @override
  String get skillNameConflict => 'Skill name conflict';

  @override
  String get skillPackageIsMissing => 'Skill package is missing';

  @override
  String get skillSource => 'Skill source';

  @override
  String get skillSymbol => 'Skill symbol';

  @override
  String get skills => 'Skills';

  @override
  String skippedcountResourcesAlreadyExistAndWillBeSkippedOr_6aa841ce(
    Object skippedCount,
  ) {
    return '$skippedCount resources already exist and will be skipped or flagged as conflicts.';
  }

  @override
  String get sleepingState => 'Sleeping state';

  @override
  String get sound => 'Sound';

  @override
  String get source => 'Source';

  @override
  String get sourceApplicationRegularExpression =>
      'Source application regular expression';

  @override
  String sourceFilterSummary(Object summary) {
    return 'Source filter: $summary';
  }

  @override
  String get sourceRegex => 'Source regex';

  @override
  String get sourceURL => 'Source URL';

  @override
  String get sources => 'Sources';

  @override
  String get startDingDongAfterYouSignInToThisComputer =>
      'Start DingDong after you sign in to this computer.';

  @override
  String get status => 'Status';

  @override
  String get stopConnecting => 'Stop connecting';

  @override
  String get subagentNotifications => 'Subagent notifications';

  @override
  String get system => 'System';

  @override
  String get systemSound => 'System sound';

  @override
  String get tagsAndAliases => 'Tags and aliases';

  @override
  String get taskMatch => 'Task match';

  @override
  String get testAConciseSummaryPlusALongerMobileDetailBody =>
      'Test a concise summary plus a longer mobile detail body.';

  @override
  String get testNotificationSent => 'Test notification sent';

  @override
  String get testPanel => 'Test Panel';

  @override
  String get text => 'Text';

  @override
  String get textFromPhone => 'Text from phone';

  @override
  String get textHistory => 'Text history';

  @override
  String get textIsLargerThan128KiBAndWasNotSent =>
      'Text is larger than 128 KiB and was not sent.';

  @override
  String get textLinksCodeCommandsAndRichText =>
      'Text, links, code, commands, and rich text';

  @override
  String get theBundledBridgeExposesPromptsSkillsMCPReferencesAnd_a0f4fd67 =>
      'The bundled bridge exposes prompts, skills, MCP references, and notifications through JSON-RPC.';

  @override
  String get theCommandBelowUsesTheActualEndpointWhenTheRuntime_0a3909c7 =>
      'The command below uses the actual endpoint when the runtime supplied one.';

  @override
  String get theCompleteSkillPackageCouldNotBeFoundReinstallOrUpdate_2a4648b6 =>
      'The complete Skill package could not be found. Reinstall or update its source.';

  @override
  String get theDEVPWAEndpointIsNotConfiguredInThisBuild =>
      'The DEV PWA endpoint is not configured in this build.';

  @override
  String get theDeviceDisconnectedBeforeSending =>
      'The device disconnected before sending.';

  @override
  String
  get theEncryptedMessageIsLargerThanThe256KiBRelayLimitAndWas_3231b01c =>
      'The encrypted message is larger than the 256 KiB relay limit and was not sent.';

  @override
  String get theHealthEndpointRespondedSuccessfully =>
      'The /health endpoint responded successfully.';

  @override
  String get theHelperOpensAccessibilityAndPlacesADraggableDingDong_11660c82 =>
      'The helper opens Accessibility and places a draggable DingDong beside it. If “−” works, remove the old entry before dragging. If “−” is disabled, drag once to make it available, remove the entry, then drag again and turn DingDong on.';

  @override
  String get theInstalledPackageIsReadOnlyReviewTheSourceBefore_d3e0119e =>
      'The installed package is read-only. Review the source before updating.';

  @override
  String get theKeyStaysInTheQRWebRTCIsPreferredTheEncryptedRelay_ca235c45 =>
      'The key stays in the QR. WebRTC is preferred; the encrypted relay fallback stores no content.';

  @override
  String get theRuntimeEndpointDidNotPassItsHealthCheck =>
      'The runtime endpoint did not pass its health check.';

  @override
  String get theSKILLMdMetadataCouldNotBeParsedReviewTheResource_d8ef0c36 =>
      'The SKILL.md metadata could not be parsed. Review the resource before enabling it.';

  @override
  String
  get theScopedProjectDirectoryNoLongerExistsOrIsNotAnAbsolute_78de1cff =>
      'The scoped project directory no longer exists or is not an absolute path.';

  @override
  String get theSourceDidNotReturnAUsableSKILLMdCheckTheRepository_8db02039 =>
      'The source did not return a usable SKILL.md. Check the repository path and access.';

  @override
  String get theTestFailedCheckTheConnectionAndSystemPermissions =>
      'The test failed. Check the connection and system permissions.';

  @override
  String get theme => 'Theme';

  @override
  String get theseResourcesWillBeLoadedFromTheInternetCheckTheSource_08e83c52 =>
      'These resources will be loaded from the internet. Check the source links before importing them.';

  @override
  String get thisComputerHost => 'This computer · Host';

  @override
  String thisComputerName(Object name) {
    return 'This computer → $name';
  }

  @override
  String get thisConflictsWithAnotherDingDongOrSystemShortcut =>
      'This conflicts with another DingDong or system shortcut.';

  @override
  String get thisContentIsNoLongerAvailableOrCouldNotBeOpened =>
      'This content is no longer available or could not be opened.';

  @override
  String get thisContentNoLongerExistsOrCannotBeOpened =>
      'This content no longer exists or cannot be opened.';

  @override
  String thisConversationHasNotifiedYouRepeatCountTimesAndUsed_3d5931a3(
    Object repeatCount,
    Object totalTokens,
  ) {
    return 'This conversation has notified you $repeatCount times and used $totalTokens tokens.';
  }

  @override
  String thisGroupContainsCountArchivedCopiesCopiesWithNoOther_d4ba7c7d(
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archived copies',
      one: '1 archived copy',
    );
    return 'This group contains $_temp0. Copies with no other group are deleted. Clipboard history is never changed.';
  }

  @override
  String get thisMCPResourceCannotBeWrittenToAgentConfigurationUntil_ad7aa3e0 =>
      'This MCP resource cannot be written to Agent configuration until its format is corrected.';

  @override
  String get thisOnlineSkillDoesNotHaveAnAvailableSource =>
      'This online Skill does not have an available source.';

  @override
  String thisRemovesCategoryHistoryCategory2CurrentResourcesAnd_a27899ae(
    Object category,
    Object category2,
  ) {
    return 'This removes $category history ($category2). Current resources and configuration stay intact.';
  }

  @override
  String thisRemovesLengthResourcesFromTheLocalLibrary(Object length) {
    return 'This removes $length resources from the local library.';
  }

  @override
  String thisRemovesOnlyThisPartOfClipboardHistoryCategory(Object category) {
    return 'This removes only this part of clipboard history ($category).';
  }

  @override
  String get thisRemovesTheResourceFromTheSharedAgentLibrary =>
      'This removes the resource from the shared agent library.';

  @override
  String thisRemovesTitleFromTheLocalResourceLibrary(Object title) {
    return 'This removes “$title” from the local resource library.';
  }

  @override
  String get threeAlertBurst => 'Three-alert burst';

  @override
  String get title => 'Title';

  @override
  String get trayMascotPreviewsAreUnavailableOnThisPlatformTheOther_ab13b937 =>
      'Tray mascot previews are unavailable on this platform; the other integration tests remain available.';

  @override
  String get triggerGroups => 'Trigger groups';

  @override
  String get triggerScope => 'Trigger scope';

  @override
  String get triggeredHorizontalNudge => 'Triggered: horizontal nudge';

  @override
  String get triggeredSleepingState => 'Triggered: sleeping state';

  @override
  String get trustAndDirectionalSettingsWillBeRevokedPairAgainTo_f59587ea =>
      'Trust and directional settings will be revoked. Pair again to reconnect.';

  @override
  String get twoDingDongResourcesResolveToTheSameSkillDestination_aac6ae3f =>
      'Two DingDong resources resolve to the same Skill destination. Rename or disable one of them.';

  @override
  String get type => 'Type';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get unknown => 'Unknown';

  @override
  String get unknownAgentConversation => 'Unknown Agent conversation';

  @override
  String get unpin => 'Unpin';

  @override
  String get unrecognizedLocalFilesAreKept =>
      'Unrecognized local files are kept';

  @override
  String get untitledClipboardItem => 'Untitled clipboard item';

  @override
  String get upTo7CharactersThisNameIsShownFirstInTheAgent_b892681f =>
      'Up to 7 characters. This name is shown first in the Agent conversation; an empty value falls back to the title.';

  @override
  String get update => 'UPDATE';

  @override
  String get updateCheckFailed => 'Update check failed';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get updateLink => 'Update link';

  @override
  String updateToVersion(Object version) {
    return 'Update to $version';
  }

  @override
  String get updated => 'Updated';

  @override
  String get updated2 => 'Updated';

  @override
  String get updated3 => 'Updated';

  @override
  String updatedTitleFromItsSource(Object title) {
    return 'Updated $title from its source.';
  }

  @override
  String get updating => 'Updating…';

  @override
  String get updating2 => 'Updating…';

  @override
  String get usage => 'Usage';

  @override
  String get usage2 => 'Usage';

  @override
  String get usage3 => 'Usage';

  @override
  String get useALetterNumberF1F12ArrowSpaceOrReturn =>
      'Use a letter, number, F1–F12, arrow, Space, or Return.';

  @override
  String get useAValidSTDIOOrStreamableHTTPMCPConfiguration =>
      'Use a valid STDIO or Streamable HTTP MCP configuration.';

  @override
  String get useRegularExpressionsOnlyWhenTypeAndLengthAreNotEnough =>
      'Use regular expressions only when type and length are not enough.';

  @override
  String get used => 'Used';

  @override
  String get used2 => 'used';

  @override
  String get usesTheRealLocalDingRouteUnreadBadgeNativeAlertAnd_63a64edd =>
      'Uses the real local /ding route, unread badge, native alert, and connected-phone delivery.';

  @override
  String get verifyTheLocalServiceAndInspectRealAgentSignals =>
      'Verify the local service and inspect real Agent signals.';

  @override
  String get verifyingUpdate => 'Verifying update…';

  @override
  String get version => 'Version';

  @override
  String get viewAllRecentAgents => 'View all recent agents';

  @override
  String get viewResource => 'View resource';

  @override
  String get visibleForReferenceOnlyTheseItemsCannotBeClearedHere =>
      'Visible for reference only. These items cannot be cleared here.';

  @override
  String get waitingForTheLoopbackHealthResponse =>
      'Waiting for the loopback health response.';

  @override
  String
  get webrtcIsPreferredTheEndToEndEncryptedRelayFallbackStores_816753f3 =>
      'WebRTC is preferred; the end-to-end encrypted relay fallback stores no clipboard, file, or Agent content.';

  @override
  String get website => 'Website';

  @override
  String get whenDisabledTheNextLaunchStartsWithAnEmptyAgentHistory =>
      'When disabled, the next launch starts with an empty Agent history.';

  @override
  String get whenItApplies => 'When it applies';

  @override
  String get whenOffSubagentActivityShowsNoNotificationOrDingDong_ce161d98 =>
      'When off, subagent activity shows no notification or DingDong sound.';

  @override
  String get whenOffTasksStartedInCodexVoiceModeDoNotNotifyOrPlayA_75237958 =>
      'When off, tasks started in Codex voice mode do not notify or play a DingDong sound.';

  @override
  String get whenToUse => 'When to use';

  @override
  String get windowOpacity => 'Window opacity';

  @override
  String get workspaceShortcutsApplyOnlyWhileThePanelIsFocused_1b6f2968 =>
      'Workspace shortcuts apply only while the panel is focused. Defaults: Control+Q/W/E on macOS, Alt+Q/W/E on Windows.';

  @override
  String get youReUpToDate => 'You\'re up to date';

  @override
  String get yourDevices => 'Your devices';

  @override
  String get yourEditsHaveNotBeenSavedLeavingThisPageWillDiscardThem =>
      'Your edits have not been saved. Leaving this page will discard them.';

  @override
  String get custom => 'Custom';

  @override
  String get builtIn => 'Built in';

  @override
  String get invalidConfiguration => 'Invalid configuration';

  @override
  String get loadExternal => 'Load external';

  @override
  String get directoryNotChecked => 'Directory not checked';

  @override
  String get directoryNotDetected => 'Directory not detected';

  @override
  String get directoryDetected => 'Directory detected';

  @override
  String get unsaved => 'Unsaved';

  @override
  String get newAgent => 'New Agent';

  @override
  String get newLabel => 'New';

  @override
  String get refresh => 'Refresh';

  @override
  String get versionComparison => 'Version comparison';

  @override
  String get advancedConfig => 'Advanced config';

  @override
  String get deleteThisAdapter => 'Delete this Adapter?';

  @override
  String get restoreBuiltInVersion => 'Restore built-in version?';

  @override
  String get notChecked => 'Not checked';

  @override
  String get notDetected => 'Not detected';

  @override
  String get detected => 'Detected';

  @override
  String get managedButDisabled => 'Managed but disabled';

  @override
  String get managedAndEnabled => 'Managed and enabled';

  @override
  String get trustedButDisabled => 'Trusted but disabled';

  @override
  String get trustedAndEnabled => 'Trusted and enabled';

  @override
  String get checkingCodex => 'Checking Codex…';

  @override
  String get trustEnable => 'Trust & enable';

  @override
  String get checkAgain => 'Check again';

  @override
  String get notDeclared => 'Not declared';

  @override
  String get declared => 'Declared';

  @override
  String get skillPaths => 'Skill paths';

  @override
  String get mcpConfigurationPath => 'MCP configuration path';

  @override
  String get agentDirectory => 'Agent directory';

  @override
  String get invalid => 'Invalid';

  @override
  String get valid => 'Valid';

  @override
  String get adapterDocument => 'Adapter document';

  @override
  String get configurationEvidence => 'Configuration evidence';

  @override
  String get storedOnThisDevice => 'Stored on this device';

  @override
  String get agentAccess => 'Agent access';

  @override
  String get workspace => 'WORKSPACE';

  @override
  String get userOverride => 'User override';

  @override
  String get selectAnAgentAdapterOrCreateOne =>
      'Select an Agent Adapter or create one.';

  @override
  String get theFileChangedOutsideDingDongWhileYouHaveUnsavedEdits =>
      'The file changed outside DingDong while you have unsaved edits.';

  @override
  String
  get directoryDetectionAndDeclaredPathsVerifyRuntimeConnectionsSeparately =>
      'Directory detection and declared paths; verify runtime connections separately';

  @override
  String get agentConnectionConfiguration => 'Agent connection configuration';

  @override
  String get aComparisonAppearsAfterTheNextSavedOrExternalEdit =>
      'A comparison appears after the next saved or external edit.';

  @override
  String get twoVersionsAgo => 'Two versions ago';

  @override
  String get previousVersion => 'Previous version';

  @override
  String get newAgentAdapter => 'New Agent Adapter';

  @override
  String get theCustomYAMLFileWillBeDeletedAgentResourcesWillStopSyncing =>
      'The custom YAML file will be deleted. Agent resources will stop syncing to this client.';

  @override
  String get theUserOverrideWillBeRemovedItsSnapshotsRemainInLocalHistory =>
      'The user override will be removed. Its snapshots remain in local history.';

  @override
  String get connectionHasNotBeenInferred => 'Connection has not been inferred';

  @override
  String get agentDirectoryDetectedDoesNotVerifyConnections =>
      'What is known: DingDong found the declared Agent directory. A detected directory or declared path does not verify MCP, Hook, Bridge, authentication, or completion callbacks. Use Agent connections to verify the running local API and real completion signals.';

  @override
  String get agentDirectoryNotDetectedDoesNotVerifyConnections =>
      'What is known: DingDong did not find the declared Agent directory. A detected directory or declared path does not verify MCP, Hook, Bridge, authentication, or completion callbacks. Use Agent connections to verify the running local API and real completion signals.';

  @override
  String get codexDidNotReturnAVerifiableHookState =>
      'Codex did not return a verifiable Hook state.';

  @override
  String get thisHookIsManagedAndDisabledDingDongCannotChangeIt =>
      'This Hook is managed and disabled; DingDong cannot change it.';

  @override
  String get thisManagedHookIsEnabledAndCanRunAfterTaskCompletion =>
      'This managed Hook is enabled and can run after task completion.';

  @override
  String get theCurrentHashIsTrustedButThisHookIsDisabled =>
      'The current hash is trusted, but this Hook is disabled.';

  @override
  String get codexCanRunDingDongAfterATaskCompletes =>
      'Codex can run DingDong after a task completes.';

  @override
  String get theHookChangedAfterItsLastReviewCheckTheCurrentCommandAnd =>
      'The Hook changed after its last review. Check the current command and hash before trusting it again.';

  @override
  String get codexIsBlockingThisHookUntilItsExactCurrentHashIsTrusted =>
      'Codex is blocking this Hook until its exact current hash is trusted.';

  @override
  String get aDingDongHookExistsButItsCommandDoesNotExactlyMatchThis =>
      'A DingDong Hook exists, but its command does not exactly match this installed app. It was not trusted.';

  @override
  String get theExpectedDingDongStopHookIsNotConfiguredInCodex =>
      'The expected DingDong Stop Hook is not configured in Codex.';

  @override
  String get thisCodexBuildCouldNotBeReachedThroughAppServerUseHooks =>
      'This Codex build could not be reached through App Server. Use /hooks to review the Hook.';

  @override
  String get selectRefreshToReadTheCurrentStateFromCodex =>
      'Select refresh to read the current state from Codex.';

  @override
  String get readingTheCurrentHookDefinitionAndTrustStateFromCodex =>
      'Reading the current Hook definition and trust state from Codex.';

  @override
  String get verificationFailed => 'Verification failed';

  @override
  String get changedSinceReview => 'Changed since review';

  @override
  String get trustRequired => 'Trust required';

  @override
  String get commandMismatch => 'Command mismatch';

  @override
  String get hookNotConfigured => 'Hook not configured';

  @override
  String get codexUnavailable => 'Codex unavailable';

  @override
  String get onlyTheExactHookShownAboveAndItsCurrentHashWillBe =>
      'Only the exact Hook shown above and its current hash will be trusted. A future change requires another review.';

  @override
  String get codexCompletionHook => 'Codex completion Hook';

  @override
  String get thisAdapterDoesNotDeclareBothGlobalAndProjectSkillPaths =>
      'This Adapter does not declare both global and project Skill paths.';

  @override
  String get thisAdapterDoesNotDeclareAPromptFile =>
      'This Adapter does not declare a prompt file.';

  @override
  String get promptConfigurationPath => 'Prompt configuration path';

  @override
  String get thisAdapterDoesNotDeclareAnMCPFile =>
      'This Adapter does not declare an MCP file.';

  @override
  String get unavailableBecauseTheAdapterIsInvalid =>
      'Unavailable because the Adapter is invalid.';

  @override
  String get yamlStructureAndDeclaredPathsPassedValidation =>
      'YAML structure and declared paths passed validation.';

  @override
  String get detectionIsNotConnectionVerification =>
      'Detection is not connection verification';

  @override
  String agentAdapterCatalogSummary(
    Object configurationCount,
    Object detectedCount,
  ) {
    return '$configurationCount configurations · $detectedCount directories detected';
  }

  @override
  String agentAdapterCatalogSummaryWithInvalid(
    Object configurationCount,
    Object detectedCount,
    Object invalidCount,
  ) {
    return '$configurationCount configurations · $detectedCount directories detected · $invalidCount invalid';
  }

  @override
  String get openClipboard => 'Open Clipboard';

  @override
  String get openConnectedDevices => 'Open Connected Devices';

  @override
  String get clipboardMonitoringOn => 'Clipboard Monitoring On';

  @override
  String get clipboardMonitoringPaused => 'Clipboard Monitoring Paused';

  @override
  String get stopMonitoring => 'Stop Monitoring';

  @override
  String get startMonitoring => 'Start Monitoring';

  @override
  String get quitDingDong => 'Quit DingDong';

  @override
  String get quitDingDongDev => 'Quit DingDong DEV';

  @override
  String dingDongUnreadCount(Object count) {
    return 'DingDong · $count unread';
  }

  @override
  String get connectedDevicesWindowTitle => 'DingDong · Connected Devices';

  @override
  String get settingsWindowTitle => 'DingDong · Settings';

  @override
  String get developmentTestPanelWindowTitle => 'DingDong DEV · Test Panel';

  @override
  String get resourceManagerWindowTitle => 'DingDong · Resource Manager';

  @override
  String connectDingDongToCurrentAgent(String commandPath) {
    return 'Connect ‘$commandPath’ to the current Agent as a user-level STDIO MCP server named dingdong with no args; preserve existing settings and verify dingdong_bridge. If user-level task-completion Hooks are supported, add a Hook command for that event using the same executable with ‘--notify-stop --source \"<current Agent name>\"’, then verify the alert.';
  }

  @override
  String get about => 'About';

  @override
  String get timeSingular => 'time';

  @override
  String get timePlural => 'times';

  @override
  String get agentNeedsYourAttention => 'Agent needs your attention';

  @override
  String get agentCompleted => 'Agent completed';

  @override
  String get mobileDevice => 'Mobile device';

  @override
  String get sharedFile => 'Shared file';

  @override
  String fromDevice(Object name) {
    return 'From $name';
  }

  @override
  String get dingDongComputer => 'DingDong computer';

  @override
  String get currentTask => 'Current task';

  @override
  String sourceCompletedCurrentTask(Object source) {
    return '$source completed the current task';
  }

  @override
  String get devAgentCompletedMessage =>
      'DEV test: Agent completed the current task';

  @override
  String get devAgentCompletedDetail =>
      'This basic completion alert was created by the test panel. It is not a real Agent task result.';

  @override
  String get devCrossDeviceTaskCompletedMessage =>
      'DEV test: cross-device task completed';

  @override
  String get devCrossDeviceTaskCompletedDetail =>
      'This simulated completion detail tests long mobile card text, source, completion time, and vibration settings. It is not a real Agent task result.';

  @override
  String devRepeatedAlertMessage(Object index) {
    return 'DEV test: repeated alert $index/3';
  }

  @override
  String get devRepeatedAlertDetail =>
      'Tests unread counts, chronological order, and repeated mobile delivery. This is simulated test data.';

  @override
  String get devPhoneTextSampleTitle => 'DEV phone text sample';

  @override
  String get devPhoneTextSampleContent =>
      'DingDong DEV test: this text simulates content pasted into the phone input and sent explicitly.';

  @override
  String get devTestPhoneSource => 'From DEV test phone';

  @override
  String get devAutoSyncSampleTitle => 'DEV computer auto-sync sample';

  @override
  String get devAutoSyncSampleContent =>
      'DingDong DEV test: created on this computer and sent only to connected devices with auto-sync enabled.';

  @override
  String get devTestPanelSource => 'DingDong DEV test panel';

  @override
  String get devManualSendSampleTitle => 'DEV manual-send sample';

  @override
  String get devManualSendSampleContent =>
      'DingDong DEV test: choose a connected device and send this item explicitly.';

  @override
  String get devPhoneFileBody =>
      'DingDong DEV test file\n\nThis local sample was created by the test panel to simulate choosing a file on a phone and sending it explicitly.\nIt did not come from a real phone and contains no real user content.\n';

  @override
  String get devPhoneFileSampleTitle => 'DingDong DEV phone file sample.txt';

  @override
  String get agentAPI => 'Agent API';

  @override
  String get audioFiles => 'Audio files';

  @override
  String get chooseSoundFile => 'Choose sound';

  @override
  String get importThisFolder => 'Import this folder';

  @override
  String get importAction => 'Import';

  @override
  String get exportAction => 'Export';

  @override
  String get jsonFiles => 'JSON files';

  @override
  String get jsonFile => 'JSON file';

  @override
  String get categoryRuleKeywordsExample => 'command, alias:build';

  @override
  String get httpsOrGitHubFileURL => 'HTTPS or GitHub file URL';
}
