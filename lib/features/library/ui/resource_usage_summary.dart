import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ResourceUsageSummaryStyle { compact, detail }

enum ResourceUsageStage { activated, candidate, loaded, called, used }

final DateTime resourceUsageTrackingStartedAt = DateTime(2026, 8, 19);

String resourceUsageTrackingDescription(BuildContext context) {
  final String date = DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(resourceUsageTrackingStartedAt);
  return context.l10n
      .dingdongHasRecordedTheseLocalStatisticsSinceDateEarlier_90d48aa0(date);
}

class ResourceUsageHelpIcon extends StatelessWidget {
  const ResourceUsageHelpIcon({this.iconSize = 14, super.key});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final String message = resourceUsageTrackingDescription(context);
    return Tooltip(
      message: message,
      child: Semantics(
        label: message,
        child: Icon(
          Icons.help_outline_rounded,
          size: iconSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

final class ResourceUsageMetric {
  const ResourceUsageMetric({
    required this.stage,
    required this.count,
    required this.lastAt,
  });

  final ResourceUsageStage stage;
  final int count;
  final DateTime? lastAt;
}

List<ResourceUsageMetric> resourceUsageMetrics(Resource resource) =>
    switch (resource.type) {
      ResourceType.prompt => <ResourceUsageMetric>[
        ResourceUsageMetric(
          stage: ResourceUsageStage.activated,
          count: resource.usageCount,
          lastAt: resource.lastUsedAt,
        ),
      ],
      ResourceType.skill => <ResourceUsageMetric>[
        ResourceUsageMetric(
          stage: ResourceUsageStage.candidate,
          count: resource.candidateCount,
          lastAt: resource.lastCandidateAt,
        ),
        ResourceUsageMetric(
          stage: ResourceUsageStage.loaded,
          count: resource.usageCount,
          lastAt: resource.lastUsedAt,
        ),
      ],
      ResourceType.mcp => <ResourceUsageMetric>[
        ResourceUsageMetric(
          stage: ResourceUsageStage.candidate,
          count: resource.candidateCount,
          lastAt: resource.lastCandidateAt,
        ),
        ResourceUsageMetric(
          stage: ResourceUsageStage.called,
          count: resource.invocationCount,
          lastAt: resource.lastInvokedAt,
        ),
      ],
      ResourceType.knowledge || ResourceType.clipboard => <ResourceUsageMetric>[
        ResourceUsageMetric(
          stage: ResourceUsageStage.used,
          count: resource.usageCount,
          lastAt: resource.lastUsedAt,
        ),
      ],
    };

class ResourceUsageSummary extends StatelessWidget {
  const ResourceUsageSummary({
    required this.resource,
    this.style = ResourceUsageSummaryStyle.compact,
    super.key,
  });

  final Resource resource;
  final ResourceUsageSummaryStyle style;

  @override
  Widget build(BuildContext context) {
    final List<ResourceUsageMetric> metrics = resourceUsageMetrics(resource);
    final String semantics = metrics
        .map((ResourceUsageMetric metric) => _description(context, metric))
        .join('. ');
    final Widget child = style == ResourceUsageSummaryStyle.detail
        ? _DetailedMetrics(resource: resource, metrics: metrics)
        : _CompactMetrics(resource: resource, metrics: metrics);
    return Semantics(
      label: semantics,
      container: true,
      child: ExcludeSemantics(
        child: Tooltip(message: semantics, child: child),
      ),
    );
  }
}

class _CompactMetrics extends StatelessWidget {
  const _CompactMetrics({required this.resource, required this.metrics});

  final Resource resource;
  final List<ResourceUsageMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w400,
          height: 1.25,
        );
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final ResourceUsageMetric metric in metrics)
            Text.rich(
              key: ValueKey<String>(
                'resource-usage-metric-${metric.stage.name}-${resource.id}',
              ),
              TextSpan(
                style: labelStyle,
                children: <InlineSpan>[
                  TextSpan(text: '${_label(context, metric.stage)} '),
                  TextSpan(
                    text: _formatCount(context, metric.count),
                    style: labelStyle?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _DetailedMetrics extends StatelessWidget {
  const _DetailedMetrics({required this.resource, required this.metrics});

  final Resource resource;
  final List<ResourceUsageMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.usage2,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const ResourceUsageHelpIcon(
              key: Key('resource-usage-help-detail'),
              iconSize: 13,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < metrics.length; index += 1) ...<Widget>[
              if (index > 0) const SizedBox(width: 18),
              SizedBox(
                key: ValueKey<String>(
                  'resource-usage-detail-${metrics[index].stage.name}-${resource.id}',
                ),
                width: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _label(context, metrics[index].stage),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatCount(context, metrics[index].count),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _lastLabel(context, metrics[index]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _formatCount(BuildContext context, int count) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(count);

String _label(BuildContext context, ResourceUsageStage stage) =>
    switch (stage) {
      ResourceUsageStage.activated => context.l10n.activated,
      ResourceUsageStage.candidate => context.l10n.candidate,
      ResourceUsageStage.loaded => context.l10n.loaded,
      ResourceUsageStage.called => context.l10n.called,
      ResourceUsageStage.used => context.l10n.used,
    };

String _pastAction(BuildContext context, ResourceUsageStage stage) =>
    switch (stage) {
      ResourceUsageStage.activated => context.l10n.activated2,
      ResourceUsageStage.candidate => context.l10n.returnedAsACandidate,
      ResourceUsageStage.loaded => context.l10n.loaded2,
      ResourceUsageStage.called => context.l10n.called2,
      ResourceUsageStage.used => context.l10n.used2,
    };

String _description(BuildContext context, ResourceUsageMetric metric) {
  final String count = _formatCount(context, metric.count);
  final String action = _pastAction(context, metric.stage);
  final String countDescription = context.l10n.actionCountTimes(
    action,
    count,
    metric.count == 1 ? context.l10n.timeSingular : context.l10n.timePlural,
  );
  return '$countDescription · ${_lastLabel(context, metric)}';
}

String _lastLabel(BuildContext context, ResourceUsageMetric metric) {
  final DateTime? value = metric.lastAt;
  if (value == null) {
    return context.l10n.never;
  }
  final DateTime local = value.toLocal();
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  final String date = localizations.formatShortDate(local);
  final String time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return context.l10n.lastDateTime(date, time);
}
