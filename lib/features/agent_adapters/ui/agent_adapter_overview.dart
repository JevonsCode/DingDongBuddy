part of 'agent_adapter_screen.dart';

class _AdapterCatalogSummary extends StatelessWidget {
  const _AdapterCatalogSummary({required this.entries});

  final List<AgentAdapterEntry> entries;

  @override
  Widget build(BuildContext context) {
    final int detected = entries
        .where((AgentAdapterEntry entry) => entry.installed)
        .length;
    final int invalid = entries
        .where((AgentAdapterEntry entry) => !entry.isValid)
        .length;
    final String summary = invalid == 0
        ? context.l10n.agentAdapterCatalogSummary(entries.length, detected)
        : context.l10n.agentAdapterCatalogSummaryWithInvalid(
            entries.length,
            detected,
            invalid,
          );
    return Semantics(
      container: true,
      label: summary,
      child: Container(
        key: const Key('agent-adapter-catalog-summary'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              context.l10n.detectionIsNotConnectionVerification,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdapterOverview extends StatelessWidget {
  const _AdapterOverview({required this.entry, required this.controller});

  final AgentAdapterEntry entry;
  final AgentAdapterController controller;

  @override
  Widget build(BuildContext context) {
    final AgentAdapter? adapter = entry.adapter;
    final bool hasSkills =
        adapter?.globalSkillPath != null && adapter?.projectSkillPath != null;
    final bool hasMcp = adapter?.mcpFilePath != null;
    final bool hasPrompt = adapter?.promptFilePath != null;
    return ListView(
      key: const Key('agent-adapter-status-overview'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: <Widget>[
        _VerificationBoundaryNotice(entry: entry),
        if (entry.id == 'codex' &&
            controller.supportsCodexCompletionHook) ...<Widget>[
          const SizedBox(height: 14),
          _CodexCompletionHookCard(controller: controller),
        ],
        const SizedBox(height: 14),
        Text(
          context.l10n.configurationEvidence,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _EvidenceCard(
          children: <Widget>[
            _EvidenceRow(
              icon: entry.isValid
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              title: context.l10n.adapterDocument,
              value: entry.isValid ? context.l10n.valid : context.l10n.invalid,
              detail:
                  entry.error ??
                  context.l10n.yamlStructureAndDeclaredPathsPassedValidation,
              positive: entry.isValid,
              warning: !entry.isValid,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.folder_outlined,
              title: context.l10n.agentDirectory,
              value: entry.installed
                  ? context.l10n.detected
                  : context.l10n.notDetected,
              detail:
                  adapter?.detectDirectory ??
                  context.l10n.unavailableBecauseTheAdapterIsInvalid,
              positive: entry.installed,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.hub_outlined,
              title: context.l10n.mcpConfigurationPath,
              value: hasMcp ? context.l10n.declared : context.l10n.notDeclared,
              detail:
                  adapter?.mcpFilePath ??
                  context.l10n.thisAdapterDoesNotDeclareAnMCPFile,
              positive: hasMcp,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.description_outlined,
              title: context.l10n.promptConfigurationPath,
              value: hasPrompt
                  ? context.l10n.declared
                  : context.l10n.notDeclared,
              detail:
                  adapter?.promptFilePath ??
                  context.l10n.thisAdapterDoesNotDeclareAPromptFile,
              positive: hasPrompt,
            ),
            const Divider(height: 1),
            _EvidenceRow(
              icon: Icons.layers_outlined,
              title: context.l10n.skillPaths,
              value: hasSkills
                  ? context.l10n.declared
                  : context.l10n.notDeclared,
              detail: hasSkills
                  ? '${adapter!.globalSkillPath}\n${adapter.projectSkillPath}'
                  : context
                        .l10n
                        .thisAdapterDoesNotDeclareBothGlobalAndProjectSkillPaths,
              positive: hasSkills,
            ),
          ],
        ),
      ],
    );
  }
}

class _CodexCompletionHookCard extends StatelessWidget {
  const _CodexCompletionHookCard({required this.controller});

  final AgentAdapterController controller;

  @override
  Widget build(BuildContext context) {
    final CodexCompletionHookStatus status =
        controller.codexCompletionHookStatus;
    final bool checking = controller.isCheckingCodexCompletionHook;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool positive = status.isOperational;
    final Color accent = positive
        ? colors.primary
        : status.review == CodexCompletionHookReview.failed ||
              status.review == CodexCompletionHookReview.mismatched ||
              status.review == CodexCompletionHookReview.modified
        ? colors.error
        : colors.tertiary;
    final String title = _title(context, status, checking);
    final String detail = _detail(context, status, checking);
    return Container(
      key: const Key('codex-completion-hook-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              checking
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(
                      positive
                          ? Icons.verified_user_outlined
                          : Icons.gpp_maybe_outlined,
                      size: 20,
                      color: accent,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.codexCompletionHook,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              DesktopIconButton(
                key: const Key('codex-completion-hook-refresh'),
                tooltip: context.l10n.checkAgain,
                onPressed: checking
                    ? null
                    : controller.refreshCodexCompletionHook,
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          if (status.command != null) ...<Widget>[
            const SizedBox(height: 9),
            SelectableText(
              status.command!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFamily: 'Menlo',
                height: 1.35,
              ),
            ),
          ],
          if (status.currentHash != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              status.currentHash!,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFamily: 'Menlo',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            context.l10n.onlyTheExactHookShownAboveAndItsCurrentHashWillBe,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (status.canRepair) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: DesktopActionButton(
                key: const Key('codex-completion-hook-repair'),
                onPressed: checking
                    ? null
                    : controller.repairCodexCompletionHook,
                icon: const Icon(Icons.security_update_good_outlined, size: 17),
                label: status.review == CodexCompletionHookReview.trusted
                    ? context.l10n.enable
                    : context.l10n.trustEnable,
                tone: DesktopActionTone.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _title(
    BuildContext context,
    CodexCompletionHookStatus status,
    bool checking,
  ) {
    if (checking) {
      return context.l10n.checkingCodex;
    }
    return switch (status.review) {
      CodexCompletionHookReview.notChecked => context.l10n.notChecked,
      CodexCompletionHookReview.unavailable => context.l10n.codexUnavailable,
      CodexCompletionHookReview.missing => context.l10n.hookNotConfigured,
      CodexCompletionHookReview.mismatched => context.l10n.commandMismatch,
      CodexCompletionHookReview.untrusted => context.l10n.trustRequired,
      CodexCompletionHookReview.modified => context.l10n.changedSinceReview,
      CodexCompletionHookReview.trusted =>
        status.enabled
            ? context.l10n.trustedAndEnabled
            : context.l10n.trustedButDisabled,
      CodexCompletionHookReview.managed =>
        status.enabled
            ? context.l10n.managedAndEnabled
            : context.l10n.managedButDisabled,
      CodexCompletionHookReview.failed => context.l10n.verificationFailed,
    };
  }

  String _detail(
    BuildContext context,
    CodexCompletionHookStatus status,
    bool checking,
  ) {
    if (checking) {
      return context.l10n.readingTheCurrentHookDefinitionAndTrustStateFromCodex;
    }
    return switch (status.review) {
      CodexCompletionHookReview.notChecked =>
        context.l10n.selectRefreshToReadTheCurrentStateFromCodex,
      CodexCompletionHookReview.unavailable =>
        context.l10n.thisCodexBuildCouldNotBeReachedThroughAppServerUseHooks,
      CodexCompletionHookReview.missing =>
        context.l10n.theExpectedDingDongStopHookIsNotConfiguredInCodex,
      CodexCompletionHookReview.mismatched =>
        context.l10n.aDingDongHookExistsButItsCommandDoesNotExactlyMatchThis,
      CodexCompletionHookReview.untrusted =>
        context.l10n.codexIsBlockingThisHookUntilItsExactCurrentHashIsTrusted,
      CodexCompletionHookReview.modified =>
        context.l10n.theHookChangedAfterItsLastReviewCheckTheCurrentCommandAnd,
      CodexCompletionHookReview.trusted =>
        status.enabled
            ? context.l10n.codexCanRunDingDongAfterATaskCompletes
            : context.l10n.theCurrentHashIsTrustedButThisHookIsDisabled,
      CodexCompletionHookReview.managed =>
        status.enabled
            ? context.l10n.thisManagedHookIsEnabledAndCanRunAfterTaskCompletion
            : context.l10n.thisHookIsManagedAndDisabledDingDongCannotChangeIt,
      CodexCompletionHookReview.failed =>
        status.detail ?? context.l10n.codexDidNotReturnAVerifiableHookState,
    };
  }
}

class _VerificationBoundaryNotice extends StatelessWidget {
  const _VerificationBoundaryNotice({required this.entry});

  final AgentAdapterEntry entry;

  @override
  Widget build(BuildContext context) {
    final String message = entry.installed
        ? context.l10n.agentDirectoryDetectedDoesNotVerifyConnections
        : context.l10n.agentDirectoryNotDetectedDoesNotVerifyConnections;
    return Semantics(
      container: true,
      label: message,
      child: Container(
        key: const Key('agent-adapter-verification-boundary'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.tertiaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.rule_folder_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.connectionHasNotBeenInferred,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.positive,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final bool positive;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = warning
        ? colors.error
        : positive
        ? colors.primary
        : colors.onSurfaceVariant;
    return Semantics(
      container: true,
      label: '$title. $value. $detail',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontFamily: detail.contains('/') ? 'Menlo' : null,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionBadge extends StatelessWidget {
  const _DetectionBadge({required this.installed});

  final bool? installed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String label = switch (installed) {
      true => context.l10n.detected,
      false => context.l10n.notDetected,
      null => context.l10n.notChecked,
    };
    final Color foreground = installed == true
        ? colors.primary
        : colors.onSurfaceVariant;
    return Container(
      key: const Key('agent-adapter-detection-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
