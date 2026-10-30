part of 'settings_screen.dart';

// Search the labels and choices users see; matching keeps the whole group so
// controls retain their context and dependencies. No network request is made.
Map<String, List<String>> _settingsSearchTerms(BuildContext context) => {
  'general': [
    context.l10n.general,
    context.l10n.chooseHowDingDongBehavesWhenYouSignIn,
    context.l10n.launchAtStartup,
    context.l10n.startDingDongAfterYouSignInToThisComputer,
    context.l10n.hideDockIcon,
    context.l10n.notchHoverEnabled,
    context.l10n.notchHoverDescription,
    context.l10n.keepDingDongInTheMenuBarWithoutShowingItInTheDock,
    context.l10n.menuBarIconHiddenByTheCameraHousing,
    context.l10n.findIcon,
  ],
  'keyboardShortcuts': [
    context.l10n.keyboardShortcuts,
    context
        .l10n
        .setTheSystemWidePanelShortcutAndTheShortcutsUsedInside_4f5138fb,
    context.l10n.openOrHideClipboard,
    context.l10n.workspaceShortcutsApplyOnlyWhileThePanelIsFocused_1b6f2968,
    context.l10n.dynamicWorkspace,
    context.l10n.dynamicWorkspaceShortcut,
    context.l10n.libraryWorkspace,
    context.l10n.libraryWorkspaceShortcut,
    context.l10n.clipboardWorkspace,
    context.l10n.clipboardWorkspaceShortcut,
  ],
  'quickPaste': [
    context.l10n.quickPastePermission,
    context
        .l10n
        .afterTheGlobalShortcutDingDongCanReturnFocusAndPasteThe_5ad1a82a,
    context.l10n.permissionGranted,
    context.l10n.permissionRequired,
    context.l10n.permissionStatusUnavailable,
    context.l10n.refreshStatus,
    context.l10n.openPermissionHelper,
    context
        .l10n
        .theHelperOpensAccessibilityAndPlacesADraggableDingDong_11660c82,
  ],
  'storage': [
    context.l10n.usage3,
    context.l10n.seeWhatDingDongStoresLocallyAndCleanOnlyTheHistoryYou_a955b365,
    context.l10n.clipboardHistory2,
    context
        .l10n
        .imagesTextAndFilesAreIndependentCleaningThemNeverRemoves_cb27e3f9,
    context.l10n.protectedData,
    context.l10n.visibleForReferenceOnlyTheseItemsCannotBeClearedHere,
    context.l10n.maintenance,
    context.l10n.localData,
    context.l10n.currentMemory,
    context.l10n.openDingDongImageCache,
    context.l10n.openDingDongDataFolder,
    context.l10n.clean,
    context.l10n.protectedDataIsNotClearedHere,
    context.l10n.unavailable,
    context.l10n.clipboardDatabase,
    context.l10n.imageCache,
    context.l10n.textHistory,
    context.l10n.fileHistory,
    context.l10n.permanentArchives,
    context.l10n.resourceLibrary2,
    context.l10n.agentActivity,
    context.l10n.adapterVersionHistory,
    context.l10n.applicationConfiguration,
    context.l10n.otherLocalFiles,
    context.l10n.sharedDatabaseFiles,
    context.l10n.dingdongOwnedImageCopiesAndRecords,
    context.l10n.textLinksCodeCommandsAndRichText,
    context.l10n.copiedFileReferencesOriginalFilesAreNeverDeleted,
    context.l10n.independentCopiesProtectedFromHistoryCleanup,
    context.l10n.promptsSkillsMCPResourcesAndTriggerScopes,
    context.l10n.completionHistoryAndRecentCounts,
    context.l10n.savedYAMLRevisionsCurrentAdaptersStayIntact,
    context.l10n.currentAgentAccessClipboardRulesAndRuntimeState,
    context.l10n.unrecognizedLocalFilesAreKept,
    context.l10n.onlyImageCopiesInsideDingDongSCacheAreRemovedSource_28dfcaa2,
    context
        .l10n
        .onlyDingDongSLocalFileReferencesAreRemovedOriginalFiles_aea4cfa6,
    context.l10n.onlyTextRecordsStoredByDingDongAreRemoved,
  ],
  'appearance': [
    context.l10n.appearance,
    context.l10n.keepTheWorkspaceComfortableInYourCurrentDesktop_41d3bc46,
    context.l10n.theme,
    context.l10n.system,
    context.l10n.light,
    context.l10n.dark,
    context.l10n.language,
    context.l10n.languageEnglish,
    context.l10n.languageChinese,
    context.l10n.languageSpanish,
    context.l10n.windowOpacity,
    context.l10n.defaultWorkspace,
    context.l10n.dynamicMessage,
    context.l10n.libraryMessage,
    context.l10n.clipboard,
  ],
  'clipboardHistory2': [
    context.l10n.clipboardHistory2,
    context
        .l10n
        .historyStaysOnThisDeviceAgentAccessToClipboardContentIs_74a8f236,
    context.l10n.monitorClipboardChanges,
    context.l10n.captureTextFilesAndImagesWhileDingDongIsRunning,
    context.l10n.allowAgentsToReadClipboardContent,
    context
        .l10n
        .offByDefaultMetadataStaysAvailableSensitiveRecordsStill_fa1a5f8f,
    context.l10n.maximumItems,
    context.l10n.retentionDays,
  ],
  'recentAgents': [
    context.l10n.quickPanelAgentCount,
    context.l10n.quickPanelAgentCountDescription,
    context.l10n.recentAgents,
    context.l10n.completionDetailsStayOnThisDeviceCountingMetadata_9920ce29,
    context.l10n.groupRepeatedSessions,
    context
        .l10n
        .keepTheSameConversationIDInOneItemShowNAndDoNotIncrease_925894bb,
    context.l10n.rememberAfterRestart,
    context.l10n.whenDisabledTheNextLaunchStartsWithAnEmptyAgentHistory,
    context.l10n.maximumDetailedItems,
    context.l10n.countWindowHours,
  ],
  'notifications': [
    context.l10n.notificationsAndSounds,
    context.l10n.notifications,
    context.l10n.chooseWhichAgentEventsShouldNotifyYouThenCustomizeThe_7d9141e4,
    context.l10n.completionMinimumDuration,
    context.l10n.completionMinimumAny,
    context.l10n.completionMinimumDescription,
    context.l10n.quietHours,
    context.l10n.quietHoursDescription,
    context.l10n.quietHoursFrom,
    context.l10n.quietHoursTo,
    context.l10n.quietHoursAllowAttention,
    context.l10n.reminderProfiles,
    context.l10n.addReminder,
    context.l10n.reorderReminder,
    context.l10n.edit,
    context.l10n.delete,
    context.l10n.codexVoiceTaskNotifications,
    context.l10n.whenOffTasksStartedInCodexVoiceModeDoNotNotifyOrPlayA_75237958,
    context.l10n.subagentNotifications,
    context.l10n.whenOffSubagentActivityShowsNoNotificationOrDingDong_ce161d98,
    context.l10n.reminderAudioImportFailed,
    context.l10n.agentCompletionNotifications,
    context.l10n.needsYourInput2,
    context.l10n.dingdongClassic,
    context.l10n.dingdongSoft,
    context.l10n.dingdongBright,
    context.l10n.dingdongCrisp,
    context.l10n.dingdongDeep,
    context.l10n.systemSound,
    context.l10n.muted,
    context.l10n.previewSound,
    context.l10n.importReminderSound,
    context.l10n.reminderAudioFormat,
    context.l10n.sound,
  ],
  'footer': [
    context.l10n.agentReplyFooter,
    context
        .l10n
        .configureTheFinalDingDongResourceLineAndOptionallyAppend_e6f7cb62,
    context.l10n.showConversationTokenUsage,
    context
        .l10n
        .shownOnlyWhenCodexClaudeCodeOrPiProvidesExactLocalUsage_7e557397,
    context.l10n.promptSymbol,
    context.l10n.promptFooterSymbol,
    context.l10n.enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved,
    context.l10n.skillSymbol,
    context.l10n.skillFooterSymbol,
    context.l10n.mcpSymbol,
    context.l10n.mcpFooterSymbol,
    context.l10n.preview,
    context
        .l10n
        .aSkillMeansItsFullInstructionsWereLoadedForThisTaskAnMCP_240facd9,
    context.l10n.restoreDefaults,
  ],
  'agentAPI': [
    context.l10n.agentAPI,
    context.l10n.dingdongListensOnlyOnTheLocalLoopbackInterface,
    context.l10n.localPort,
    context.l10n.restart,
    context.l10n.portChangesApplyTheNextTimeDingDongStarts,
  ],
  'release': [
    context.l10n.version,
    context.l10n.releasePreviewNotice,
    context.l10n.current,
    context.l10n.latest,
    context.l10n.unknown,
    context.l10n.anonymousInstallAndUpdateStatistics,
    context.l10n.onByDefaultSendsOneEventAfterInstallationOrAVersion_153fb4ab,
    context.l10n.allowBetaUpdates,
    context.l10n.allowBetaUpdatesDescription,
    context.l10n.check2,
    context.l10n.website,
    context.l10n.release,
    context.l10n.reportAProblem,
    context.l10n.requestAFeature,
    context
        .l10n
        .afterUpdatingYouWillNeedToGrantDingDongSMacOSPermissions_20660ff5,
    context.l10n.preparingUpdate,
    context.l10n.downloadingUpdate,
    context.l10n.verifyingUpdate,
    context.l10n.installingAndRestarting,
    context.l10n.updateFailed,
    context.l10n.releasePreviewCurrent,
    context.l10n.youReUpToDate,
    context.l10n.checkingForUpdates,
    context.l10n.updateCheckFailed,
    context.l10n.aNewVersionIsAvailable,
    context.l10n.noUpdateMetadataYet,
    context.l10n.updating2,
  ],
};

class _SettingsSearchHeader extends SliverPersistentHeaderDelegate {
  _SettingsSearchHeader({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  double get minExtent => 76;
  @override
  double get maxExtent => 76;
  @override
  bool shouldRebuild(covariant _SettingsSearchHeader oldDelegate) => true;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(
    height: maxExtent,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 18, 36, 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.settings2,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: DesktopSearchField(
                key: const Key('settings-search'),
                controller: controller,
                clearButtonKey: const Key('settings-search-clear'),
                hintText: context.l10n.searchSettings,
                clearTooltip: context.l10n.clearSearch,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
