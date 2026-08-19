import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'dingdong_localizations_en.dart';
import 'dingdong_localizations_es.dart';
import 'dingdong_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of DingDongLocalizations
/// returned by `DingDongLocalizations.of(context)`.
///
/// Applications need to include `DingDongLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/dingdong_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: DingDongLocalizations.localizationsDelegates,
///   supportedLocales: DingDongLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the DingDongLocalizations.supportedLocales
/// property.
abstract class DingDongLocalizations {
  DingDongLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static DingDongLocalizations of(BuildContext context) {
    return Localizations.of<DingDongLocalizations>(
      context,
      DingDongLocalizations,
    )!;
  }

  static const LocalizationsDelegate<DingDongLocalizations> delegate =
      _DingDongLocalizationsDelegate();

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
    Locale('es'),
  ];

  /// Display name for the English language option.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Display name for the Chinese language option.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// Display name for the Spanish language option.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get aNewVersionIsAvailable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'A selected local-path resource could not be shared: {error}'**
  String aSelectedLocalPathResourceCouldNotBeSharedError(Object error);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'A Skill * means its full instructions were loaded for this task. An MCP * means one of its tools was called, not that the call succeeded. Prompts stay unmarked.'**
  String get aSkillMeansItsFullInstructionsWereLoadedForThisTaskAnMCP_240facd9;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'A tool connection whose MCP tools are called only when the task requires them.'**
  String get aToolConnectionWhoseMCPToolsAreCalledOnlyWhenTheTask_08282426;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{action} {count} {times}'**
  String actionCountTimes(Object action, Object count, Object times);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get activated;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'activated'**
  String get activated2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Adapter version history'**
  String get adapterVersionHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add a local note about how you use this Skill.'**
  String get addALocalNoteAboutHowYouUseThisSkill;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add agent configuration'**
  String get addAgentConfiguration;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add at least one complete rule.'**
  String get addAtLeastOneCompleteRule;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add one or more existing absolute project directories.'**
  String get addOneOrMoreExistingAbsoluteProjectDirectories;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add project'**
  String get addProject;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get addRule;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add title'**
  String get addTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Add to groups'**
  String get addToGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Advanced API and MCP details'**
  String get advancedAPIAndMCPDetails;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Advanced commands and the installation prompt. Their presence does not mean an Agent has been verified.'**
  String get advancedCommandsAndTheInstallationPromptTheirPresence_b84b4903;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Advanced matching'**
  String get advancedMatching;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'After the global shortcut, DingDong can return focus and paste the selected item.'**
  String get afterTheGlobalShortcutDingDongCanReturnFocusAndPasteThe_5ad1a82a;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'After updating, you will need to grant DingDong\'s macOS permissions again in System Settings.'**
  String get afterUpdatingYouWillNeedToGrantDingDongSMacOSPermissions_20660ff5;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent activity'**
  String get agentActivity;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent alerts'**
  String get agentAlerts;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent and clipboard items created here are explicit DEV test data. Phone-origin samples are simulations, never captured from a real phone clipboard.'**
  String get agentAndClipboardItemsCreatedHereAreExplicitDEVTestData_f8625f9f;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent completion'**
  String get agentCompletion;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent completion notifications'**
  String get agentCompletionNotifications;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent completion notifications for {name}'**
  String agentCompletionNotificationsForName(Object name);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent completion signal'**
  String get agentCompletionSignal;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent configuration file is invalid'**
  String get agentConfigurationFileIsInvalid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent connection center'**
  String get agentConnectionCenter;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent connections'**
  String get agentConnections;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent decides'**
  String get agentDecides;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent plugin provides the same Skill'**
  String get agentPluginProvidesTheSameSkill;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent reply footer'**
  String get agentReplyFooter;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent resource sync failed'**
  String get agentResourceSyncFailed;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent session loading name'**
  String get agentSessionLoadingName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent setup needs update'**
  String get agentSetupNeedsUpdate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent setup prompt'**
  String get agentSetupPrompt;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent setup prompt needs updating'**
  String get agentSetupPromptNeedsUpdating;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent source'**
  String get agentSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'All projects · no restriction'**
  String get allProjectsNoRestriction;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get allSources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Allow Agents to read clipboard content'**
  String get allowAgentsToReadClipboardContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Allowed by the explicit Settings switch'**
  String get allowedByTheExplicitSettingsSwitch;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get always;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'An enabled Agent plugin provides a Skill with the same name. Both remain available; review which one should be used.'**
  String get anEnabledAgentPluginProvidesASkillWithTheSameNameBoth_c5e2f5ee;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'An existing user-managed Skill was preserved. DingDong did not overwrite it.'**
  String get anExistingUserManagedSkillWasPreservedDingDongDidNot_0f7d7c2a;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Anonymous install and update statistics'**
  String get anonymousInstallAndUpdateStatistics;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'API | Agent connections'**
  String get apiAgentConnections;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'API listening on {host}:{port}'**
  String apiListeningOnHostPort(Object host, Object port);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'API status unverified'**
  String get apiStatusUnverified;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Application configuration'**
  String get applicationConfiguration;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Archive to…'**
  String get archiveTo;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Archive to groups'**
  String get archiveToGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Archived copies remain unchanged.'**
  String get archivedCopiesRemainUnchanged;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Arguments · one per line'**
  String get argumentsOnePerLine;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Auto send clipboard'**
  String get autoSendClipboard;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Auto send clipboard from this computer to {name}'**
  String autoSendClipboardFromThisComputerToName(Object name);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Available to installed Agents'**
  String get availableToInstalledAgents;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Back to categories'**
  String get backToCategories;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Back to Dynamic'**
  String get backToDynamic;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Back to resources'**
  String get backToResources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get backToTop;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Basic completion'**
  String get basicCompletion;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Bearer token env'**
  String get bearerTokenEnv;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Called'**
  String get called;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'called'**
  String get called2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Cancel device pairing'**
  String get cancelDevicePairing;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Cancel pairing'**
  String get cancelPairing;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Candidate'**
  String get candidate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Capture current clipboard'**
  String get captureCurrentClipboard;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Capture now'**
  String get captureNow;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Capture text, files, and images while DingDong is running.'**
  String get captureTextFilesAndImagesWhileDingDongIsRunning;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Case sensitive'**
  String get caseSensitive;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Category name is required.'**
  String get categoryNameIsRequired;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Category rule'**
  String get categoryRule;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check3;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Check unread counting, ordering, and repeated phone delivery.'**
  String get checkUnreadCountingOrderingAndRepeatedPhoneDelivery;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Check update'**
  String get checkUpdate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get checking;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get checkingForUpdates;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Checking local service'**
  String get checkingLocalService;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Choose how DingDong behaves when you sign in.'**
  String get chooseHowDingDongBehavesWhenYouSignIn;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Choose rules'**
  String get chooseRules;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Choose which Agent events should notify you, then customize the alert sound and color.'**
  String get chooseWhichAgentEventsShouldNotifyYouThenCustomizeThe_7d9141e4;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get clean;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clear {category}?'**
  String clearCategory(Object category);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clear custom sound'**
  String get clearCustomSound;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Click anywhere to close · Esc'**
  String get clickAnywhereToCloseEsc;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Click to enlarge QR code'**
  String get clickToEnlargeQRCode;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboard;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard and devices'**
  String get clipboardAndDevices;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard body access'**
  String get clipboardBodyAccess;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard categories'**
  String get clipboardCategories;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard content'**
  String get clipboardContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard content stays metadata-only unless explicitly enabled in Settings.'**
  String get clipboardContentStaysMetadataOnlyUnlessExplicitlyEnabled_df1d930e;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard database'**
  String get clipboardDatabase;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard details and complete content'**
  String get clipboardDetailsAndCompleteContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard history'**
  String get clipboardHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard history'**
  String get clipboardHistory2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard history remains unchanged.'**
  String get clipboardHistoryRemainsUnchanged;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard item.'**
  String get clipboardItem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard sort: {label}'**
  String clipboardSortLabel(Object label);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard workspace'**
  String get clipboardWorkspace;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard workspace shortcut'**
  String get clipboardWorkspaceShortcut;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Close enlarged view'**
  String get closeEnlargedView;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Codex subagent'**
  String get codexSubagent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Codex voice task notifications'**
  String get codexVoiceTaskNotifications;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get command;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get command2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Completion details stay on this device. Counting metadata contains timestamps only.'**
  String get completionDetailsStayOnThisDeviceCountingMetadata_9920ce29;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Completion history and recent counts'**
  String get completionHistoryAndRecentCounts;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Completion notifications are off for this device'**
  String get completionNotificationsAreOffForThisDevice;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Configuration details'**
  String get configurationDetails;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get configurationSaved;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Configure projects'**
  String get configureProjects;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Configure the final DingDong resource line and optionally append exact session usage.'**
  String get configureTheFinalDingDongResourceLineAndOptionallyAppend_e6f7cb62;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connect a new device'**
  String get connectANewDevice;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connected devices'**
  String get connectedDevices;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connection manager'**
  String get connectionManager;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed: {error}'**
  String connectionTestFailedError(Object error);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get connectionType;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Contains'**
  String get contains;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get contains2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Content QR code'**
  String get contentQRCode;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Content regex'**
  String get contentRegex;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Content regular expression'**
  String get contentRegularExpression;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get contentType;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Content types'**
  String get contentTypes;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} times'**
  String copiedCountTimes(Object count);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copied file references; original files are never deleted'**
  String get copiedFileReferencesOriginalFilesAreNeverDeleted;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copy content'**
  String get copyContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copy count'**
  String get copyCount;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Copy count'**
  String get copyCount2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Core endpoints'**
  String get coreEndpoints;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not apply this Skill delivery policy. {detail}'**
  String couldNotApplyThisSkillDeliveryPolicyDetail(Object detail);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch this update: {error}'**
  String couldNotFetchThisUpdateError(Object error);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not import this resource bundle: {error}'**
  String couldNotImportThisResourceBundleError(Object error);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not open this Agent conversation.'**
  String get couldNotOpenThisAgentConversation;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not open this Skill source.'**
  String get couldNotOpenThisSkillSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the source. Check your network and link, then try again.'**
  String get couldNotReachTheSourceCheckYourNetworkAndLinkThenTry_1c1ff9ae;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not save this configuration. Check the content and try again.'**
  String get couldNotSaveThisConfigurationCheckTheContentAndTryAgain;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Could not sync this resource to an installed Agent. {detail}'**
  String couldNotSyncThisResourceToAnInstalledAgentDetail(Object detail);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{count} issues need attention'**
  String countIssuesNeedAttention(Object count);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String countItems(Object count);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {description}'**
  String countItemsDescription(Object count, Object description);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{count} paired devices'**
  String countPairedDevices(Object count);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String countSelected(Object count);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Count window (hours)'**
  String get countWindowHours;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create a computer record and send it only to connected devices with auto-send enabled.'**
  String get createAComputerRecordAndSendItOnlyToConnectedDevicesWith_41a63724;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create a QR code, then scan it with the device you trust.'**
  String get createAQRCodeThenScanItWithTheDeviceYouTrust;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create a sample and open the real target-device chooser.'**
  String get createASampleAndOpenTheRealTargetDeviceChooser;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create and send'**
  String get createAndSend;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create one clearly labeled DEV completion.'**
  String get createOneClearlyLabeledDEVCompletion;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create one to start organizing clipboard items.'**
  String get createOneToStartOrganizingClipboardItems;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Create resource'**
  String get createResource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Created: basic Agent completion'**
  String get createdBasicAgentCompletion;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Created: computer auto-send sample'**
  String get createdComputerAutoSendSample;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Created: rich mobile Agent detail'**
  String get createdRichMobileAgentDetail;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Created: simulated phone file row'**
  String get createdSimulatedPhoneFileRow;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Created: simulated phone text row'**
  String get createdSimulatedPhoneTextRow;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Created: three Agent completions'**
  String get createdThreeAgentCompletions;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Creates removable DEV samples or opens the real device workflow.'**
  String get createsRemovableDEVSamplesOrOpensTheRealDeviceWorkflow;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Curated content reusable by agents'**
  String get curatedContentReusableByAgents;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Current Agent access, clipboard rules, and runtime state'**
  String get currentAgentAccessClipboardRulesAndRuntimeState;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Current memory'**
  String get currentMemory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Cursor-compatible format'**
  String get cursorCompatibleFormat;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Custom file'**
  String get customFile;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Custom sound'**
  String get customSound;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Default order'**
  String get defaultOrder;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Default workspace'**
  String get defaultWorkspace;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Define what content belongs in this category.'**
  String get defineWhatContentBelongsInThisCategory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete “{group}”?'**
  String deleteGroup2(Object group);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteName(Object name);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete selected items?'**
  String get deleteSelectedItems;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete selected resources?'**
  String get deleteSelectedResources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete this archived copy?'**
  String get deleteThisArchivedCopy;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete this category?'**
  String get deleteThisCategory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete this clipboard item?'**
  String get deleteThisClipboardItem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete this device?'**
  String get deleteThisDevice;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete this resource?'**
  String get deleteThisResource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete this resource?'**
  String get deleteThisResource2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Deleted history cannot be restored.'**
  String get deletedHistoryCannotBeRestored;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delivery by Agent'**
  String get deliveryByAgent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Describe the behavior the Agent should follow.'**
  String get describeTheBehaviorTheAgentShouldFollow;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Desktop behavior, history privacy, and local agent connectivity.'**
  String get desktopBehaviorHistoryPrivacyAndLocalAgentConnectivity;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Desktop notification'**
  String get desktopNotification;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong Bright'**
  String get dingdongBright;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong checks automatically when resources change. Use Check in the upper-right corner to run it again.'**
  String get dingdongChecksAutomaticallyWhenResourcesChangeUseCheckIn_ab07f57c;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong Classic'**
  String get dingdongClassic;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong copies the complete Skill package into each selected project\'s native directory. The Skill is discovered only when that Agent works in the project.'**
  String get dingdongCopiesTheCompleteSkillPackageIntoEachSelected_de26f089;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong Crisp'**
  String get dingdongCrisp;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong {currentAppVersion} · Desktop'**
  String dingdongCurrentAppVersionDesktop(Object currentAppVersion);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong Deep'**
  String get dingdongDeep;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong device connection manager'**
  String get dingdongDeviceConnectionManager;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong has recorded these local statistics since {date}. Earlier activity is not backfilled, so 0 does not necessarily mean this resource was never used.'**
  String dingdongHasRecordedTheseLocalStatisticsSinceDateEarlier_90d48aa0(
    Object date,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong listens only on the local loopback interface.'**
  String get dingdongListensOnlyOnTheLocalLoopbackInterface;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong-owned image copies and records'**
  String get dingdongOwnedImageCopiesAndRecords;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong preserved the existing Agent file because it could not be parsed safely.'**
  String get dingdongPreservedTheExistingAgentFileBecauseItCouldNotBe_6c5484e5;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong resource manager window'**
  String get dingdongResourceManagerWindow;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong settings window'**
  String get dingdongSettingsWindow;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong Skills use the same name'**
  String get dingdongSkillsUseTheSameName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong Soft'**
  String get dingdongSoft;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Disable category'**
  String get disableCategory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Disable resource'**
  String get disableResource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardUnsavedChanges;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get downloadingUpdate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Downloading update… {percent}%'**
  String downloadingUpdatePercent(Object percent);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Dynamic loads on demand through DingDong. Native · Global installs in the Agent user directory. Native · Project installs only in selected projects.'**
  String get dynamicLoadsOnDemandThroughDingDongNativeGlobalInstalls_ff4bd6e5;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Dynamic'**
  String get dynamicMessage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Dynamic workspace'**
  String get dynamicWorkspace;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Dynamic workspace shortcut'**
  String get dynamicWorkspaceShortcut;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'e.g. Concise release notes'**
  String get eGConciseReleaseNotes;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'e.g. DingDong projects'**
  String get eGDingDongProjects;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'e.g. Figma'**
  String get eGFigma;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'e.g. Project drafts'**
  String get eGProjectDrafts;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Each project must be an existing absolute directory.'**
  String get eachProjectMustBeAnExistingAbsoluteDirectory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Edit and organize'**
  String get editAndOrganize;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Edit project group'**
  String get editProjectGroup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Edit rules'**
  String get editRules;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get editText;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get editTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Edit trigger group'**
  String get editTriggerGroup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enable category'**
  String get enableCategory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enable resource'**
  String get enableResource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enable resources from the library to see them here.'**
  String get enableResourcesFromTheLibraryToSeeThemHere;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enabled · Phone vibration is off'**
  String get enabledPhoneVibrationIsOff;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enabled · Phone vibration is on'**
  String get enabledPhoneVibrationIsOn;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Endpoints, commands, and setup prompt'**
  String get endpointsCommandsAndSetupPrompt;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enlarge QR code'**
  String get enlargeQRCode;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enter a trigger-group name.'**
  String get enterATriggerGroupName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid web source before opening it.'**
  String get enterAValidWebSourceBeforeOpeningIt;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Enter one visible symbol. Asterisk and vertical bar are reserved.'**
  String get enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environment;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Equals'**
  String get equals;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'equals'**
  String get equals2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Executable path, npx, uvx…'**
  String get executablePathNpxUvx;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Exercise real DingDong integration paths from one place.'**
  String get exerciseRealDingDongIntegrationPathsFromOnePlace;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJSON;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Exported resource library to {path}'**
  String exportedResourceLibraryToPath(Object path);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Fetch and review'**
  String get fetchAndReview;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Fetch latest content'**
  String get fetchLatestContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'File from phone'**
  String get fileFromPhone;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'File history'**
  String get fileHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Find icon'**
  String get findIcon;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'For example: Project links'**
  String get forExampleProjectLinks;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Group repeated sessions'**
  String get groupRepeatedSessions;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get headers;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Health check failed'**
  String get healthCheckFailed;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Health check passed'**
  String get healthCheckPassed;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Hide categories and groups'**
  String get hideCategoriesAndGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Hide Dock icon'**
  String get hideDockIcon;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Hide in conversation'**
  String get hideInConversation;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideMessage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'History stays on this device. Agent access to clipboard content is controlled below.'**
  String get historyStaysOnThisDeviceAgentAccessToClipboardContentIs_74a8f236;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Horizontal nudge'**
  String get horizontalNudge;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{hours} h · {count}'**
  String hoursHCount(Object hours, Object count);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/dingdong-resources.json'**
  String get httpsExampleComDingdongResourcesJson;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Image cache'**
  String get imageCache;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Images, text, and files are independent. Cleaning them never removes permanent archives.'**
  String get imagesTextAndFilesAreIndependentCleaningThemNeverRemoves_cb27e3f9;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Impeccable project Hook (approval required in /hooks)'**
  String get impeccableProjectHookApprovalRequiredInHooks;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Import from link'**
  String get importFromLink;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Import history'**
  String get importHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Import JSON file'**
  String get importJSONFile;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Import {length} resources'**
  String importLengthResources(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Imported {importedCount}; skipped {skippedCount}.'**
  String importedImportedCountSkippedSkippedCount(
    Object importedCount,
    Object skippedCount,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Imported knowledge available to Agent context.'**
  String get importedKnowledgeAvailableToAgentContext;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Imported {length}; skipped {skippedCount}.{suffix}'**
  String importedLengthSkippedSkippedCountSuffix(
    Object length,
    Object skippedCount,
    Object suffix,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Include at least one modifier key.'**
  String get includeAtLeastOneModifierKey;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Independent copies protected from history cleanup'**
  String get independentCopiesProtectedFromHistoryCleanup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Install in any of these projects'**
  String get installInAnyOfTheseProjects;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Install Skill'**
  String get installSkill;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Installed from an online source'**
  String get installedFromAnOnlineSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Installed Skill package · SKILL.md'**
  String get installedSkillPackageSKILLMd;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Installing and restarting…'**
  String get installingAndRestarting;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{issueCount} issue(s) need attention'**
  String issuecountIssueSNeedAttention(Object issueCount);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get issues;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'JSON, TOML, or YAML configuration'**
  String get jsonTOMLOrYAMLConfiguration;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Keep DingDong in the menu bar without showing it in the Dock.'**
  String get keepDingDongInTheMenuBarWithoutShowingItInTheDock;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Keep the same conversation ID in one item, show ×N, and do not increase the recent count.'**
  String get keepTheSameConversationIDInOneItemShowNAndDoNotIncrease_925894bb;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Keep the workspace comfortable in your current desktop environment.'**
  String get keepTheWorkspaceComfortableInYourCurrentDesktop_41d3bc46;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Keep this item easy to find across multiple groups.'**
  String get keepThisItemEasyToFindAcrossMultipleGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get knowledge;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Knowledge is collected from imports and Agent context; it cannot be newly authored here yet.'**
  String get knowledgeIsCollectedFromImportsAndAgentContextItCannotBe_08bd7ed0;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Known configuration issues'**
  String get knownConfigurationIssues;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Last {date} {time}'**
  String lastDateTime(Object date, Object time);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Last received from {source} at {completedAt}'**
  String lastReceivedFromSourceAtCompletedAt(Object source, Object completedAt);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get launchAtStartup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the resource title.'**
  String get leaveEmptyToUseTheResourceTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{length} duplicates'**
  String lengthDuplicates(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{length} ID conflicts'**
  String lengthIDConflicts(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{length} online sources checked'**
  String lengthOnlineSourcesChecked(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Length range'**
  String get lengthRange;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{length} results'**
  String lengthResults(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{length} selected'**
  String lengthSelected(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{length} sources'**
  String lengthSources(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryMessage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Library workspace'**
  String get libraryWorkspace;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Library workspace shortcut'**
  String get libraryWorkspaceShortcut;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Load this resource without showing its name in the Agent conversation.'**
  String get loadThisResourceWithoutShowingItsNameInTheAgent_ec7e075b;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Loaded'**
  String get loaded;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'loaded'**
  String get loaded2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Local API'**
  String get localAPI;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Local authoring'**
  String get localAuthoring;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Local data'**
  String get localData;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Local port'**
  String get localPort;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Local service unavailable'**
  String get localServiceUnavailable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Local service verified'**
  String get localServiceVerified;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'lowercase-hyphen-name'**
  String get lowercaseHyphenName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Manage Agents'**
  String get manageAgents;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manageCategories;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Mark as updated'**
  String get markAsUpdated;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Match a project path, repository, or Agent source.'**
  String get matchAProjectPathRepositoryOrAgentSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Match any of these rules'**
  String get matchAnyOfTheseRules;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Matched by description, then loaded as a complete Skill package only when needed.'**
  String get matchedByDescriptionThenLoadedAsACompleteSkillPackage_fa102bfe;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Matches everything'**
  String get matchesEverything;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Maximum characters'**
  String get maximumCharacters;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Maximum detailed items'**
  String get maximumDetailedItems;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Maximum items'**
  String get maximumItems;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Maximum length cannot be negative.'**
  String get maximumLengthCannotBeNegative;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'MCP access'**
  String get mcpAccess;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'MCP configuration is invalid'**
  String get mcpConfigurationIsInvalid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'MCP footer symbol'**
  String get mcpFooterSymbol;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'MCP symbol'**
  String get mcpSymbol;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Menu bar alert color'**
  String get menuBarAlertColor;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Menu bar icon hidden by the camera housing'**
  String get menuBarIconHiddenByTheCameraHousing;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Menu-bar mascot'**
  String get menuBarMascot;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Metadata only'**
  String get metadataOnly;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Minimum characters'**
  String get minimumCharacters;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Minimum length cannot be negative.'**
  String get minimumLengthCannotBeNegative;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Minimum length cannot exceed maximum length.'**
  String get minimumLengthCannotExceedMaximumLength;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'MOCK: add a phone-origin text row without reading any phone clipboard.'**
  String get mockAddAPhoneOriginTextRowWithoutReadingAnyPhone_381a76fb;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'MOCK: create a small local file and show its device source.'**
  String get mockCreateASmallLocalFileAndShowItsDeviceSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Monitor clipboard changes'**
  String get monitorClipboardChanges;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get muted;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'My note'**
  String get myNote;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'---\nname: my-skill\ndescription: Use when…\n---\n\n# Instructions'**
  String get nameMySkillDescriptionUseWhenInstructions;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Native · Project'**
  String get nativeProject;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Native · User'**
  String get nativeUser;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Needs your input'**
  String get needsYourInput;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Needs your input'**
  String get needsYourInput2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New configuration'**
  String get newConfiguration;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New project group'**
  String get newProjectGroup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New resource'**
  String get newResource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New trigger group'**
  String get newTriggerGroup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Newest first. Click a resumable item to return to its conversation.'**
  String get newestFirstClickAResumableItemToReturnToItsConversation;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No Agent completions yet'**
  String get noAgentCompletionsYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategoriesYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No connected devices yet'**
  String get noConnectedDevicesYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No device is online. Connect one first.'**
  String get noDeviceIsOnlineConnectOneFirst;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No issues found'**
  String get noIssuesFound;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No known issue; this is not a connection guarantee'**
  String get noKnownIssueThisIsNotAConnectionGuarantee;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No matching groups'**
  String get noMatchingGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No matching resources'**
  String get noMatchingResources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No matching sources'**
  String get noMatchingSources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No matching trigger groups'**
  String get noMatchingTriggerGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No project groups yet'**
  String get noProjectGroupsYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No project selected'**
  String get noProjectSelected;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No real Agent completion has been received yet'**
  String get noRealAgentCompletionHasBeenReceivedYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No recent agent events'**
  String get noRecentAgentEvents;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No resource imports yet.'**
  String get noResourceImportsYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No sound selected'**
  String get noSoundSelected;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No trigger groups yet'**
  String get noTriggerGroupsYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'No update metadata yet'**
  String get noUpdateMetadataYet;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get notInstalled;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Not installed Agents ({length})'**
  String notInstalledAgentsLength(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerified;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get notify;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Notify when an Agent finishes its current task turn.'**
  String get notifyWhenAnAgentFinishesItsCurrentTaskTurn;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Notify when an Agent is waiting for confirmation, a choice, or your takeover.'**
  String get notifyWhenAnAgentIsWaitingForConfirmationAChoiceOrYour_825d0876;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Nudge the tray mascot like an overdue reminder.'**
  String get nudgeTheTrayMascotLikeAnOverdueReminder;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Off by default. Metadata stays available; sensitive records still require an explicit request when enabled.'**
  String get offByDefaultMetadataStaysAvailableSensitiveRecordsStill_fa1a5f8f;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'On by default. Sends one event after installation or a version update with a random installation ID, app version, operating system, and architecture. No activity, feature usage, clipboard content, files, or Agent messages are sent. The implementation is open source, and you can turn this off at any time.'**
  String get onByDefaultSendsOneEventAfterInstallationOrAVersion_153fb4ab;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'One-way auto send'**
  String get oneWayAutoSend;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Online: {onlineTitles}'**
  String onlineOnlineTitles(Object onlineTitles);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Online Skill updated'**
  String get onlineSkillUpdated;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Online sync'**
  String get onlineSync;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Online sync is not ready in this window. Reopen Resource Manager and try again.'**
  String get onlineSyncIsNotReadyInThisWindowReopenResourceManagerAnd_2ceb1f90;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Only active in its configured trigger scope'**
  String get onlyActiveInItsConfiguredTriggerScope;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Only DingDong\'s local file references are removed. Original files and folders stay untouched.'**
  String get onlyDingDongSLocalFileReferencesAreRemovedOriginalFiles_aea4cfa6;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Only exact, existing project directories can receive a native Skill.'**
  String get onlyExactExistingProjectDirectoriesCanReceiveANative_7c3d0f93;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Only image copies inside DingDong\'s cache are removed. Source images elsewhere stay untouched.'**
  String get onlyImageCopiesInsideDingDongSCacheAreRemovedSource_28dfcaa2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Only text records stored by DingDong are removed.'**
  String get onlyTextRecordsStoredByDingDongAreRemoved;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Only the configured preferred port is known.'**
  String get onlyTheConfiguredPreferredPortIsKnown;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open Agent conversation'**
  String get openAgentConversation;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open {category} location'**
  String openCategoryLocation(Object category);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open DingDong data folder'**
  String get openDingDongDataFolder;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open DingDong image cache'**
  String get openDingDongImageCache;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open file with system app'**
  String get openFileWithSystemApp;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open for details or retry.'**
  String get openForDetailsOrRetry;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open link with system browser'**
  String get openLinkWithSystemBrowser;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open or hide clipboard'**
  String get openOrHideClipboard;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open path with system app'**
  String get openPathWithSystemApp;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open permission helper'**
  String get openPermissionHelper;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get openSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open the standalone QR, device, switch, disconnect, and delete surface.'**
  String get openTheStandaloneQRDeviceSwitchDisconnectAndDelete_441119af;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open {title}'**
  String openTitle(Object title);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Opened: connection manager'**
  String get openedConnectionManager;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Opened: send-to-device chooser'**
  String get openedSendToDeviceChooser;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get orange;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Organize clipboard item'**
  String get organizeClipboardItem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Other local files'**
  String get otherLocalFiles;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Other settings'**
  String get otherSettings;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Pair a trusted device and choose what this computer sends.'**
  String get pairATrustedDeviceAndChooseWhatThisComputerSends;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Pairing does not copy content by itself.'**
  String get pairingDoesNotCopyContentByItself;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Pairing QR code for {name}'**
  String pairingQRCodeForName(Object name);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Paste a GitHub Skill repository, folder, or direct SKILL.md link.\nExamples:\nhttps://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste\nhttps://github.com/mattpocock/skills/tree/main/skills/productivity/grilling'**
  String get pasteAGitHubSkillRepositoryFolderOrDirectSKILLMdLink_1ee790e1;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Paste a JSON bundle link. DingDong will fetch it, resolve its online resources, and show the sources for review before importing.'**
  String get pasteAJSONBundleLinkDingDongWillFetchItResolveItsOnline_cb404168;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Paste as Plain Text'**
  String get pasteAsPlainText;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Paste config'**
  String get pasteConfig;

  /// Explains what the short Agent setup instruction changes.
  ///
  /// In en, this message translates to:
  /// **'Paste this short instruction into a local Agent. It includes this installation’s exact MCP path, keeps existing settings intact, and adds the completion alert only when supported.'**
  String get pasteAgentSetupInstructionDescription;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Permanent archives'**
  String get permanentArchives;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Permanent archives and their image files are protected and will stay intact.'**
  String get permanentArchivesAndTheirImageFilesAreProtectedAndWill_889010d8;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Permission granted'**
  String get permissionGranted;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permissionRequired;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Permission status unavailable'**
  String get permissionStatusUnavailable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Pin in library'**
  String get pinInLibrary;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get pink;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get plainText;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Port changes apply the next time DingDong starts.'**
  String get portChangesApplyTheNextTimeDingDongStarts;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Preferred port {preferredPort} was unavailable; using {actualPort}.'**
  String preferredPortPreferredPortWasUnavailableUsingActualPort(
    Object preferredPort,
    Object actualPort,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Preparing update…'**
  String get preparingUpdate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Press a shortcut…'**
  String get pressAShortcut;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Press to record a different shortcut'**
  String get pressToRecordADifferentShortcut;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Preview image with system app'**
  String get previewImageWithSystemApp;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Preview real tray states without creating history records.'**
  String get previewRealTrayStatesWithoutCreatingHistoryRecords;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Preview sound'**
  String get previewSound;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Priority · first match wins'**
  String get priorityFirstMatchWins;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Priority {index} · drag to reorder'**
  String priorityIndexDragToReorder(Object index);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Private history metadata'**
  String get privateHistoryMetadata;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Project directory'**
  String get projectDirectory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Project directory · Equals'**
  String get projectDirectoryEquals;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Project installation scope'**
  String get projectInstallationScope;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Project Skill path is invalid'**
  String get projectSkillPathIsInvalid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get prompt;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Prompt footer symbol'**
  String get promptFooterSymbol;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Prompt name'**
  String get promptName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Prompt symbol'**
  String get promptSymbol;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get prompts;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Prompts, Skills, MCP resources, and trigger scopes'**
  String get promptsSkillsMCPResourcesAndTriggerScopes;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Protected data'**
  String get protectedData;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Protected data is not cleared here'**
  String get protectedDataIsNotClearedHere;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get purple;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get qrCode;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Quick paste needs Accessibility permission.'**
  String get quickPasteNeedsAccessibilityPermission;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Quick paste permission'**
  String get quickPastePermission;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Quick paste permission granted'**
  String get quickPastePermissionGranted;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get readOnly;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Recent agents'**
  String get recentAgents;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Recheck local service'**
  String get recheckLocalService;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reconnect this Agent'**
  String get reconnectThisAgent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get refreshStatus;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Regular expression is invalid.'**
  String get regularExpressionIsInvalid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get release;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Remember after restart'**
  String get rememberAfterRestart;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Remove from selection'**
  String get removeFromSelection;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get removeRule;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{repeatCount} notifications for this conversation'**
  String repeatcountNotificationsForThisConversation(Object repeatCount);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportAProblem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Repository address'**
  String get repositoryAddress;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Request a feature'**
  String get requestAFeature;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Required instructions that are applied automatically whenever active.'**
  String get requiredInstructionsThatAreAppliedAutomaticallyWhenever_7564e51c;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reset changes'**
  String get resetChanges;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reset {semanticLabel}'**
  String resetSemanticLabel(Object semanticLabel);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get resource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resource actions'**
  String get resourceActions;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resource library'**
  String get resourceLibrary;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resource library'**
  String get resourceLibrary2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resource manager'**
  String get resourceManager;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resources become available when a selected group matches this project or Agent source.'**
  String get resourcesBecomeAvailableWhenASelectedGroupMatchesThis_ae977468;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Resources using this group will become unrestricted.'**
  String get resourcesUsingThisGroupWillBecomeUnrestricted;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restoreDefaults;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Restore one history item'**
  String get restoreOneHistoryItem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Retention days'**
  String get retentionDays;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'returned as a candidate'**
  String get returnedAsACandidate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Review online resources'**
  String get reviewOnlineResources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Review resource sync, Agent configuration, and anything else that needs attention.'**
  String get reviewResourceSyncAgentConfigurationAndAnythingElseThat_a562ea61;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Review the Skill before installing. DingDong saves the full folder, including scripts and references; updates stay manual.'**
  String get reviewTheSkillBeforeInstallingDingDongSavesTheFullFolder_1375b575;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Rich mobile detail'**
  String get richMobileDetail;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'“{rule}” and its matching conditions will be removed. Clipboard items are not deleted.'**
  String ruleAndItsMatchingConditionsWillBeRemovedClipboardItems_48d9a089(
    Object rule,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Rules run from top to bottom; the first match wins.'**
  String get rulesRunFromTopToBottomTheFirstMatchWins;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get running;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Running test…'**
  String get runningTest;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Runtime check'**
  String get runtimeCheck;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Runtime status unverified'**
  String get runtimeStatusUnverified;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Save as prompt'**
  String get saveAsPrompt;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Save category'**
  String get saveCategory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Save group'**
  String get saveGroup;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Saved as SKILL.md · name: {name}'**
  String savedAsSKILLMdNameName(Object name);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Saved YAML revisions; current Adapters stay intact'**
  String get savedYAMLRevisionsCurrentAdaptersStayIntact;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Scan to connect'**
  String get scanToConnect;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Scan to share · Click to enlarge'**
  String get scanToShareClickToEnlarge;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Scan with the device you want to trust.'**
  String get scanWithTheDeviceYouWantToTrust;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get scope;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Scoped'**
  String get scoped;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search clipboard'**
  String get searchClipboard;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search clipboard history'**
  String get searchClipboardHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get searchGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search name or content'**
  String get searchNameOrContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search names or rules'**
  String get searchNamesOrRules;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search prompts, skills, and MCP'**
  String get searchPromptsSkillsAndMCP;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search resources'**
  String get searchResources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Search sources'**
  String get searchSources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'See what DingDong stores locally and clean only the history you choose.'**
  String get seeWhatDingDongStoresLocallyAndCleanOnlyTheHistoryYou_a955b365;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Select a configuration to inspect or edit'**
  String get selectAConfigurationToInspectOrEdit;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Select an item to preview'**
  String get selectAnItemToPreview;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Select item'**
  String get selectItem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Select item'**
  String get selectItem2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{selectionCount} resources selected'**
  String selectioncountResourcesSelected(Object selectionCount);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{selectionCount} selected'**
  String selectioncountSelected(Object selectionCount);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{semanticLabel}, waiting for a shortcut'**
  String semanticlabelWaitingForAShortcut(Object semanticLabel);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Send 3'**
  String get send3;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Send test notification'**
  String get sendTestNotification;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Send the one-line setup request to each affected Agent. Mark it complete after the Agent verifies both MCP and completion alerts.'**
  String get sendTheOneLineSetupRequestToEachAffectedAgentMarkIt_3a68e15f;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Send to device'**
  String get sendToDevice;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Send to device dialog'**
  String get sendToDeviceDialog;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Sensitive content hidden'**
  String get sensitiveContentHidden;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get serverName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverURL;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Service health'**
  String get serviceHealth;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Set the system-wide panel shortcut and the shortcuts used inside the focused panel.'**
  String get setTheSystemWidePanelShortcutAndTheShortcutsUsedInside_4f5138fb;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Shared database files'**
  String get sharedDatabaseFiles;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{shortcut} ready'**
  String shortcutReady(Object shortcut);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show categories and groups'**
  String get showCategoriesAndGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show categories and groups (filters active)'**
  String get showCategoriesAndGroupsFiltersActive;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show conversation Token usage'**
  String get showConversationTokenUsage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get showMessage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show pairing QR'**
  String get showPairingQR;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show QR code to pair a trusted device'**
  String get showQRCodeToPairATrustedDevice;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show the sleeping mascot briefly, then restore the current state.'**
  String get showTheSleepingMascotBrieflyThenRestoreTheCurrentState;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Shown only when Codex, Claude Code, or Pi provides exact local usage. Unsupported Agents are not estimated.'**
  String get shownOnlyWhenCodexClaudeCodeOrPiProvidesExactLocalUsage_7e557397;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get skill;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get skill2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill configuration is invalid'**
  String get skillConfigurationIsInvalid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill footer symbol'**
  String get skillFooterSymbol;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'SKILL.md content'**
  String get skillMdContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'SKILL.md needs valid name and description fields in its YAML frontmatter.'**
  String get skillMdNeedsValidNameAndDescriptionFieldsInItsYAML_c05294f5;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill name'**
  String get skillName;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill name conflict'**
  String get skillNameConflict;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill package is missing'**
  String get skillPackageIsMissing;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill source'**
  String get skillSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill symbol'**
  String get skillSymbol;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{skippedCount} resources already exist and will be skipped or flagged as conflicts.'**
  String skippedcountResourcesAlreadyExistAndWillBeSkippedOr_6aa841ce(
    Object skippedCount,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Sleeping state'**
  String get sleepingState;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Source application regular expression'**
  String get sourceApplicationRegularExpression;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Source filter: {summary}'**
  String sourceFilterSummary(Object summary);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Source regex'**
  String get sourceRegex;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Source URL'**
  String get sourceURL;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Start DingDong after you sign in to this computer.'**
  String get startDingDongAfterYouSignInToThisComputer;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Stop connecting'**
  String get stopConnecting;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Subagent notifications'**
  String get subagentNotifications;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'System sound'**
  String get systemSound;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Tags and aliases'**
  String get tagsAndAliases;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Task match'**
  String get taskMatch;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Test a concise summary plus a longer mobile detail body.'**
  String get testAConciseSummaryPlusALongerMobileDetailBody;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent'**
  String get testNotificationSent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Test Panel'**
  String get testPanel;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Text from phone'**
  String get textFromPhone;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Text history'**
  String get textHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Text is larger than 128 KiB and was not sent.'**
  String get textIsLargerThan128KiBAndWasNotSent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Text, links, code, commands, and rich text'**
  String get textLinksCodeCommandsAndRichText;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The bundled bridge exposes prompts, skills, MCP references, and notifications through JSON-RPC.'**
  String get theBundledBridgeExposesPromptsSkillsMCPReferencesAnd_a0f4fd67;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The command below uses the actual endpoint when the runtime supplied one.'**
  String get theCommandBelowUsesTheActualEndpointWhenTheRuntime_0a3909c7;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The complete Skill package could not be found. Reinstall or update its source.'**
  String get theCompleteSkillPackageCouldNotBeFoundReinstallOrUpdate_2a4648b6;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The DEV PWA endpoint is not configured in this build.'**
  String get theDEVPWAEndpointIsNotConfiguredInThisBuild;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The device disconnected before sending.'**
  String get theDeviceDisconnectedBeforeSending;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The encrypted message is larger than the 256 KiB relay limit and was not sent.'**
  String get theEncryptedMessageIsLargerThanThe256KiBRelayLimitAndWas_3231b01c;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The /health endpoint responded successfully.'**
  String get theHealthEndpointRespondedSuccessfully;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The helper opens Accessibility and places a draggable DingDong beside it. If “−” works, remove the old entry before dragging. If “−” is disabled, drag once to make it available, remove the entry, then drag again and turn DingDong on.'**
  String get theHelperOpensAccessibilityAndPlacesADraggableDingDong_11660c82;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The installed package is read-only. Review the source before updating.'**
  String get theInstalledPackageIsReadOnlyReviewTheSourceBefore_d3e0119e;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The key stays in the QR. WebRTC is preferred; the encrypted relay fallback stores no content.'**
  String get theKeyStaysInTheQRWebRTCIsPreferredTheEncryptedRelay_ca235c45;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The runtime endpoint did not pass its health check.'**
  String get theRuntimeEndpointDidNotPassItsHealthCheck;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The SKILL.md metadata could not be parsed. Review the resource before enabling it.'**
  String get theSKILLMdMetadataCouldNotBeParsedReviewTheResource_d8ef0c36;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The scoped project directory no longer exists or is not an absolute path.'**
  String get theScopedProjectDirectoryNoLongerExistsOrIsNotAnAbsolute_78de1cff;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The source did not return a usable SKILL.md. Check the repository path and access.'**
  String get theSourceDidNotReturnAUsableSKILLMdCheckTheRepository_8db02039;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The test failed. Check the connection and system permissions.'**
  String get theTestFailedCheckTheConnectionAndSystemPermissions;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'These resources will be loaded from the internet. Check the source links before importing them.'**
  String get theseResourcesWillBeLoadedFromTheInternetCheckTheSource_08e83c52;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This computer · Host'**
  String get thisComputerHost;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This computer → {name}'**
  String thisComputerName(Object name);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This conflicts with another DingDong or system shortcut.'**
  String get thisConflictsWithAnotherDingDongOrSystemShortcut;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This content is no longer available or could not be opened.'**
  String get thisContentIsNoLongerAvailableOrCouldNotBeOpened;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This content no longer exists or cannot be opened.'**
  String get thisContentNoLongerExistsOrCannotBeOpened;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This conversation has notified you {repeatCount} times and used {totalTokens} tokens.'**
  String thisConversationHasNotifiedYouRepeatCountTimesAndUsed_3d5931a3(
    Object repeatCount,
    Object totalTokens,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This group contains {count, plural, =1{1 archived copy} other{{count} archived copies}}. Copies with no other group are deleted. Clipboard history is never changed.'**
  String thisGroupContainsCountArchivedCopiesCopiesWithNoOther_d4ba7c7d(
    int count,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This MCP resource cannot be written to Agent configuration until its format is corrected.'**
  String get thisMCPResourceCannotBeWrittenToAgentConfigurationUntil_ad7aa3e0;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This online Skill does not have an available source.'**
  String get thisOnlineSkillDoesNotHaveAnAvailableSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This removes {category} history ({category2}). Current resources and configuration stay intact.'**
  String thisRemovesCategoryHistoryCategory2CurrentResourcesAnd_a27899ae(
    Object category,
    Object category2,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This removes {length} resources from the local library.'**
  String thisRemovesLengthResourcesFromTheLocalLibrary(Object length);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This removes only this part of clipboard history ({category}).'**
  String thisRemovesOnlyThisPartOfClipboardHistoryCategory(Object category);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This removes the resource from the shared agent library.'**
  String get thisRemovesTheResourceFromTheSharedAgentLibrary;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This removes “{title}” from the local resource library.'**
  String thisRemovesTitleFromTheLocalResourceLibrary(Object title);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Three-alert burst'**
  String get threeAlertBurst;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Tray mascot previews are unavailable on this platform; the other integration tests remain available.'**
  String get trayMascotPreviewsAreUnavailableOnThisPlatformTheOther_ab13b937;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Trigger groups'**
  String get triggerGroups;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Trigger scope'**
  String get triggerScope;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Triggered: horizontal nudge'**
  String get triggeredHorizontalNudge;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Triggered: sleeping state'**
  String get triggeredSleepingState;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Trust and directional settings will be revoked. Pair again to reconnect.'**
  String get trustAndDirectionalSettingsWillBeRevokedPairAgainTo_f59587ea;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Two DingDong resources resolve to the same Skill destination. Rename or disable one of them.'**
  String get twoDingDongResourcesResolveToTheSameSkillDestination_aac6ae3f;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unknown Agent conversation'**
  String get unknownAgentConversation;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized local files are kept'**
  String get unrecognizedLocalFilesAreKept;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Untitled clipboard item'**
  String get untitledClipboardItem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Up to 7 characters. This name is shown first in the Agent conversation; an empty value falls back to the title.'**
  String get upTo7CharactersThisNameIsShownFirstInTheAgent_b892681f;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get update;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailed;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Update link'**
  String get updateLink;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String updateToVersion(Object version);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated3;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Updated {title} from its source.'**
  String updatedTitleFromItsSource(Object title);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get updating;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get updating2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage3;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Use a letter, number, F1–F12, arrow, Space, or Return.'**
  String get useALetterNumberF1F12ArrowSpaceOrReturn;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Use a valid STDIO or Streamable HTTP MCP configuration.'**
  String get useAValidSTDIOOrStreamableHTTPMCPConfiguration;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Use regular expressions only when type and length are not enough.'**
  String get useRegularExpressionsOnlyWhenTypeAndLengthAreNotEnough;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'used'**
  String get used2;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Uses the real local /ding route, unread badge, native alert, and connected-phone delivery.'**
  String get usesTheRealLocalDingRouteUnreadBadgeNativeAlertAnd_63a64edd;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Verify the local service and inspect real Agent signals.'**
  String get verifyTheLocalServiceAndInspectRealAgentSignals;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Verifying update…'**
  String get verifyingUpdate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'View all recent agents'**
  String get viewAllRecentAgents;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'View resource'**
  String get viewResource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Visible for reference only. These items cannot be cleared here.'**
  String get visibleForReferenceOnlyTheseItemsCannotBeClearedHere;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the loopback health response.'**
  String get waitingForTheLoopbackHealthResponse;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'WebRTC is preferred; the end-to-end encrypted relay fallback stores no clipboard, file, or Agent content.'**
  String get webrtcIsPreferredTheEndToEndEncryptedRelayFallbackStores_816753f3;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'When disabled, the next launch starts with an empty Agent history.'**
  String get whenDisabledTheNextLaunchStartsWithAnEmptyAgentHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'When it applies'**
  String get whenItApplies;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'When off, subagent activity shows no notification or DingDong sound.'**
  String get whenOffSubagentActivityShowsNoNotificationOrDingDong_ce161d98;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'When off, tasks started in Codex voice mode do not notify or play a DingDong sound.'**
  String get whenOffTasksStartedInCodexVoiceModeDoNotNotifyOrPlayA_75237958;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'When to use'**
  String get whenToUse;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Window opacity'**
  String get windowOpacity;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Workspace shortcuts apply only while the panel is focused. Defaults: Control+Q/W/E on macOS, Alt+Q/W/E on Windows.'**
  String get workspaceShortcutsApplyOnlyWhileThePanelIsFocused_1b6f2968;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get youReUpToDate;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Your devices'**
  String get yourDevices;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Your edits have not been saved. Leaving this page will discard them.'**
  String get yourEditsHaveNotBeenSavedLeavingThisPageWillDiscardThem;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get builtIn;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Invalid configuration'**
  String get invalidConfiguration;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Load external'**
  String get loadExternal;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Directory not checked'**
  String get directoryNotChecked;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Directory not detected'**
  String get directoryNotDetected;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Directory detected'**
  String get directoryDetected;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get unsaved;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New Agent'**
  String get newAgent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Version comparison'**
  String get versionComparison;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Advanced config'**
  String get advancedConfig;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Delete this Adapter?'**
  String get deleteThisAdapter;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Restore built-in version?'**
  String get restoreBuiltInVersion;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get notChecked;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Not detected'**
  String get notDetected;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get detected;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Managed but disabled'**
  String get managedButDisabled;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Managed and enabled'**
  String get managedAndEnabled;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Trusted but disabled'**
  String get trustedButDisabled;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Trusted and enabled'**
  String get trustedAndEnabled;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Checking Codex…'**
  String get checkingCodex;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Trust & enable'**
  String get trustEnable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Not declared'**
  String get notDeclared;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Declared'**
  String get declared;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Skill paths'**
  String get skillPaths;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'MCP configuration path'**
  String get mcpConfigurationPath;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent directory'**
  String get agentDirectory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get invalid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get valid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Adapter document'**
  String get adapterDocument;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Configuration evidence'**
  String get configurationEvidence;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device'**
  String get storedOnThisDevice;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent access'**
  String get agentAccess;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'WORKSPACE'**
  String get workspace;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'User override'**
  String get userOverride;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Select an Agent Adapter or create one.'**
  String get selectAnAgentAdapterOrCreateOne;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The file changed outside DingDong while you have unsaved edits.'**
  String get theFileChangedOutsideDingDongWhileYouHaveUnsavedEdits;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Directory detection and declared paths; verify runtime connections separately'**
  String
  get directoryDetectionAndDeclaredPathsVerifyRuntimeConnectionsSeparately;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent connection configuration'**
  String get agentConnectionConfiguration;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'A comparison appears after the next saved or external edit.'**
  String get aComparisonAppearsAfterTheNextSavedOrExternalEdit;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Two versions ago'**
  String get twoVersionsAgo;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Previous version'**
  String get previousVersion;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'New Agent Adapter'**
  String get newAgentAdapter;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The custom YAML file will be deleted. Agent resources will stop syncing to this client.'**
  String get theCustomYAMLFileWillBeDeletedAgentResourcesWillStopSyncing;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The user override will be removed. Its snapshots remain in local history.'**
  String get theUserOverrideWillBeRemovedItsSnapshotsRemainInLocalHistory;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Connection has not been inferred'**
  String get connectionHasNotBeenInferred;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'What is known: DingDong found the declared Agent directory. A detected directory or declared path does not verify MCP, Hook, Bridge, authentication, or completion callbacks. Use Agent connections to verify the running local API and real completion signals.'**
  String get agentDirectoryDetectedDoesNotVerifyConnections;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'What is known: DingDong did not find the declared Agent directory. A detected directory or declared path does not verify MCP, Hook, Bridge, authentication, or completion callbacks. Use Agent connections to verify the running local API and real completion signals.'**
  String get agentDirectoryNotDetectedDoesNotVerifyConnections;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Codex did not return a verifiable Hook state.'**
  String get codexDidNotReturnAVerifiableHookState;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This Hook is managed and disabled; DingDong cannot change it.'**
  String get thisHookIsManagedAndDisabledDingDongCannotChangeIt;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This managed Hook is enabled and can run after task completion.'**
  String get thisManagedHookIsEnabledAndCanRunAfterTaskCompletion;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The current hash is trusted, but this Hook is disabled.'**
  String get theCurrentHashIsTrustedButThisHookIsDisabled;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Codex can run DingDong after a task completes.'**
  String get codexCanRunDingDongAfterATaskCompletes;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The Hook changed after its last review. Check the current command and hash before trusting it again.'**
  String get theHookChangedAfterItsLastReviewCheckTheCurrentCommandAnd;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Codex is blocking this Hook until its exact current hash is trusted.'**
  String get codexIsBlockingThisHookUntilItsExactCurrentHashIsTrusted;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'A DingDong Hook exists, but its command does not exactly match this installed app. It was not trusted.'**
  String get aDingDongHookExistsButItsCommandDoesNotExactlyMatchThis;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'The expected DingDong Stop Hook is not configured in Codex.'**
  String get theExpectedDingDongStopHookIsNotConfiguredInCodex;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This Codex build could not be reached through App Server. Use /hooks to review the Hook.'**
  String get thisCodexBuildCouldNotBeReachedThroughAppServerUseHooks;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Select refresh to read the current state from Codex.'**
  String get selectRefreshToReadTheCurrentStateFromCodex;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Reading the current Hook definition and trust state from Codex.'**
  String get readingTheCurrentHookDefinitionAndTrustStateFromCodex;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get verificationFailed;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Changed since review'**
  String get changedSinceReview;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Trust required'**
  String get trustRequired;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Command mismatch'**
  String get commandMismatch;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Hook not configured'**
  String get hookNotConfigured;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Codex unavailable'**
  String get codexUnavailable;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Only the exact Hook shown above and its current hash will be trusted. A future change requires another review.'**
  String get onlyTheExactHookShownAboveAndItsCurrentHashWillBe;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Codex completion Hook'**
  String get codexCompletionHook;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This Adapter does not declare both global and project Skill paths.'**
  String get thisAdapterDoesNotDeclareBothGlobalAndProjectSkillPaths;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This Adapter does not declare a prompt file.'**
  String get thisAdapterDoesNotDeclareAPromptFile;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Prompt configuration path'**
  String get promptConfigurationPath;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This Adapter does not declare an MCP file.'**
  String get thisAdapterDoesNotDeclareAnMCPFile;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unavailable because the Adapter is invalid.'**
  String get unavailableBecauseTheAdapterIsInvalid;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'YAML structure and declared paths passed validation.'**
  String get yamlStructureAndDeclaredPathsPassedValidation;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Detection is not connection verification'**
  String get detectionIsNotConnectionVerification;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{configurationCount} configurations · {detectedCount} directories detected'**
  String agentAdapterCatalogSummary(
    Object configurationCount,
    Object detectedCount,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{configurationCount} configurations · {detectedCount} directories detected · {invalidCount} invalid'**
  String agentAdapterCatalogSummaryWithInvalid(
    Object configurationCount,
    Object detectedCount,
    Object invalidCount,
  );

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open Clipboard'**
  String get openClipboard;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Open Connected Devices'**
  String get openConnectedDevices;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Monitoring On'**
  String get clipboardMonitoringOn;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Monitoring Paused'**
  String get clipboardMonitoringPaused;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Stop Monitoring'**
  String get stopMonitoring;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Start Monitoring'**
  String get startMonitoring;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Quit DingDong'**
  String get quitDingDong;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Quit DingDong DEV'**
  String get quitDingDongDev;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong · {count} unread'**
  String dingDongUnreadCount(Object count);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong · Connected Devices'**
  String get connectedDevicesWindowTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong · Settings'**
  String get settingsWindowTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong DEV · Test Panel'**
  String get developmentTestPanelWindowTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong · Resource Manager'**
  String get resourceManagerWindowTitle;

  /// Short actionable setup instruction copied by the user.
  ///
  /// In en, this message translates to:
  /// **'Connect ‘{commandPath}’ to the current Agent as a user-level STDIO MCP server named dingdong with no args; preserve existing settings and verify dingdong_bridge. If user-level task-completion Hooks are supported, add a Hook command for that event using the same executable with ‘--notify-stop --source \"<current Agent name>\"’, then verify the alert.'**
  String connectDingDongToCurrentAgent(String commandPath);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Singular unit for a resource usage count.
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get timeSingular;

  /// Plural unit for a resource usage count.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get timePlural;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent needs your attention'**
  String get agentNeedsYourAttention;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent completed'**
  String get agentCompleted;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Mobile device'**
  String get mobileDevice;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Shared file'**
  String get sharedFile;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String fromDevice(Object name);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong computer'**
  String get dingDongComputer;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Current task'**
  String get currentTask;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'{source} completed the current task'**
  String sourceCompletedCurrentTask(Object source);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DEV test: Agent completed the current task'**
  String get devAgentCompletedMessage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This basic completion alert was created by the test panel. It is not a real Agent task result.'**
  String get devAgentCompletedDetail;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DEV test: cross-device task completed'**
  String get devCrossDeviceTaskCompletedMessage;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'This simulated completion detail tests long mobile card text, source, completion time, and vibration settings. It is not a real Agent task result.'**
  String get devCrossDeviceTaskCompletedDetail;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DEV test: repeated alert {index}/3'**
  String devRepeatedAlertMessage(Object index);

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Tests unread counts, chronological order, and repeated mobile delivery. This is simulated test data.'**
  String get devRepeatedAlertDetail;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DEV phone text sample'**
  String get devPhoneTextSampleTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong DEV test: this text simulates content pasted into the phone input and sent explicitly.'**
  String get devPhoneTextSampleContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'From DEV test phone'**
  String get devTestPhoneSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DEV computer auto-sync sample'**
  String get devAutoSyncSampleTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong DEV test: created on this computer and sent only to connected devices with auto-sync enabled.'**
  String get devAutoSyncSampleContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong DEV test panel'**
  String get devTestPanelSource;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DEV manual-send sample'**
  String get devManualSendSampleTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong DEV test: choose a connected device and send this item explicitly.'**
  String get devManualSendSampleContent;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong DEV test file\n\nThis local sample was created by the test panel to simulate choosing a file on a phone and sending it explicitly.\nIt did not come from a real phone and contains no real user content.\n'**
  String get devPhoneFileBody;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'DingDong DEV phone file sample.txt'**
  String get devPhoneFileSampleTitle;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Agent API'**
  String get agentAPI;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Audio files'**
  String get audioFiles;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Choose sound'**
  String get chooseSoundFile;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Import this folder'**
  String get importThisFolder;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportAction;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'JSON files'**
  String get jsonFiles;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'JSON file'**
  String get jsonFile;

  /// Technical example shown in the Clipboard tags and aliases field.
  ///
  /// In en, this message translates to:
  /// **'command, alias:build'**
  String get categoryRuleKeywordsExample;

  /// DingDong built-in interface copy.
  ///
  /// In en, this message translates to:
  /// **'HTTPS or GitHub file URL'**
  String get httpsOrGitHubFileURL;
}

class _DingDongLocalizationsDelegate
    extends LocalizationsDelegate<DingDongLocalizations> {
  const _DingDongLocalizationsDelegate();

  @override
  Future<DingDongLocalizations> load(Locale locale) {
    return SynchronousFuture<DingDongLocalizations>(
      lookupDingDongLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_DingDongLocalizationsDelegate old) => false;
}

DingDongLocalizations lookupDingDongLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return DingDongLocalizationsEn();
    case 'es':
      return DingDongLocalizationsEs();
    case 'zh':
      return DingDongLocalizationsZh();
  }

  throw FlutterError(
    'DingDongLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
