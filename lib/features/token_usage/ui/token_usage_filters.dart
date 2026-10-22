part of 'token_usage_screen.dart';

/// A supported-reader catalog, with observed local availability alongside it.
class _AgentFilter extends StatelessWidget {
  const _AgentFilter({
    required this.selected,
    required this.enabled,
    required this.snapshot,
    required this.onChanged,
  });
  final Set<ConversationTokenUsageSource>? selected;
  final bool enabled;
  final TokenUsageSnapshot snapshot;
  final ValueChanged<Set<ConversationTokenUsageSource>?> onChanged;

  static final agents = ConversationTokenUsageSource.values
      .where((s) => s != ConversationTokenUsageSource.dingdong)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final label = selected == null
        ? context.l10n.tokenUsageAllAgents
        : selected!.isEmpty
        ? context.l10n.tokenUsageNoAgents
        : selected!.map(tokenUsageSourceLabel).join(', ');
    return MenuAnchor(
      alignmentOffset: const Offset(0, 5),
      style: MenuStyle(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surface,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      menuChildren: [
        CheckboxMenuButton(
          key: const Key('token-usage-source-all'),
          value: selected == null,
          closeOnActivate: false,
          onChanged: enabled
              ? (value) => onChanged(value == true ? null : {})
              : null,
          child: Text(context.l10n.tokenUsageAllAgents),
        ),
        const Divider(height: 1),
        for (final source in agents)
          CheckboxMenuButton(
            key: Key('token-usage-source-${source.apiValue}'),
            value: selected == null || selected!.contains(source),
            closeOnActivate: false,
            onChanged: enabled
                ? (value) {
                    final next = {...selected ?? agents};
                    if (value == true) {
                      next.add(source);
                    } else {
                      next.remove(source);
                    }
                    onChanged(next.length == agents.length ? null : next);
                  }
                : null,
            child: SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tokenUsageSourceLabel(source)),
                  Text(
                    _availability(context, source),
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
      builder: (context, menu, child) => Tooltip(
        message: context.l10n.tokenUsageAgentSourcesHelp,
        child: SizedBox(
          width: 260,
          child: DesktopActionButton(
            key: const Key('token-usage-agent-filter'),
            height: 42,
            semanticLabel: '${context.l10n.tokenUsageAgents}: $label',
            onPressed: enabled
                ? () => menu.isOpen ? menu.close() : menu.open()
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _availability(
    BuildContext context,
    ConversationTokenUsageSource source,
  ) {
    if (snapshot.days.any((day) => day.source == source)) {
      return context.l10n.tokenUsageAvailable;
    }
    final coverage = snapshot.coverage
        .where((item) => item.source == source)
        .firstOrNull;
    return switch (coverage?.availability) {
      TokenUsageAvailability.unreadable => context.l10n.tokenUsageUnreadable,
      TokenUsageAvailability.missing => context.l10n.tokenUsageMissing,
      TokenUsageAvailability.available => context.l10n.tokenUsageNoRecords,
      null => context.l10n.tokenUsageNotReported,
    };
  }
}

String _purposeLabel(BuildContext context, String? purpose) =>
    switch (purpose) {
      'analysis' => context.l10n.tokenUsageFunctionAnalysis,
      'connectionTest' => context.l10n.tokenUsageFunctionConnection,
      'resourceSelection' => context.l10n.tokenUsageFunctionSelection,
      _ => context.l10n.tokenUsageFunctionOther,
    };

class _InternalFunctions extends StatelessWidget {
  const _InternalFunctions({required this.records, required this.periodLabel});
  final List<TokenUsageDay> records;
  final String periodLabel;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('token-usage-functions'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${context.l10n.tokenUsageFunctions} · $periodLabel',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        context.l10n.aiInternalPartial,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              horizontalMargin: 0,
              columnSpacing: 24,
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              columns: [
                DataColumn(label: Text(context.l10n.tokenUsageFunction)),
                for (final label in [
                  context.l10n.tokenUsageRequests,
                  context.l10n.tokenUsageTotal,
                  context.l10n.tokenUsageInput,
                  context.l10n.tokenUsageOutput,
                  context.l10n.tokenUsageCacheRead,
                  context.l10n.tokenUsageCacheWrite,
                ])
                  DataColumn(label: Text(label), numeric: true),
              ],
              rows: [
                for (final purpose in <String?>{
                  'resourceSelection',
                  'analysis',
                  'connectionTest',
                  ...records.map((r) => r.internalPurpose),
                })
                  _row(context, purpose),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  DataRow _row(BuildContext context, String? purpose) {
    final entries = records.where(
      (record) => record.internalPurpose == purpose,
    );
    final totals = TokenUsageTotals.sum(entries.map((r) => r.totals));
    return DataRow(
      key: ValueKey('token-usage-function-${purpose ?? 'other'}'),
      cells: [
        DataCell(Text(_purposeLabel(context, purpose))),
        DataCell(
          Text(
            _formatNumber(
              context,
              entries.fold(0, (count, r) => count + r.eventCount),
            ),
          ),
        ),
        DataCell(Text(_formatTotal(context, totals))),
        for (final count in [
          totals.inputTokens,
          totals.outputTokens,
          totals.cachedInputTokens,
          totals.cacheWriteInputTokens,
        ])
          DataCell(
            Text(
              count == null
                  ? context.l10n.tokenUsageNotReported
                  : _formatNumber(context, count),
            ),
          ),
      ],
    );
  }
}
