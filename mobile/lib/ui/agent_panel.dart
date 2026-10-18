import 'package:flutter/material.dart';

import 'clipboard_panel.dart' show ListEmpty, SectionHeading;
import 'companion_controller.dart';
import 'formatters.dart';
import 'tokens.dart';
import 'widgets.dart';

/// "正在运行" and "完成记录" (`#agent-panel`).
class AgentPanel extends StatelessWidget {
  const AgentPanel({super.key, required this.computer});

  final ComputerView computer;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final List<Map<String, Object?>> runs = computer.runs;
    final List<Map<String, Object?>> events = computer.events;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        SectionHeading(
          title: '正在运行',
          trailing: _CountPill(prefix: '', count: runs.length, suffix: ' 个'),
        ),
        if (runs.isEmpty)
          const ListEmpty(
            compact: true,
            image: 'assets/dingdong-rest-icon.png',
            title: '当前没有运行中的任务',
            body: 'Agent 开始新任务后，会实时出现在这里。',
          )
        else
          for (final Map<String, Object?> run in runs) ...<Widget>[
            _RunCard(run: run),
            const SizedBox(height: 9),
          ],
        Container(
          height: 1,
          margin: const EdgeInsets.fromLTRB(2, 22, 2, 18),
          color: t.border,
        ),
        SectionHeading(
          title: '完成记录',
          trailing: _CountPill(prefix: '未读 ', count: computer.unseenCount),
        ),
        if (events.isEmpty)
          const ListEmpty(
            image: 'assets/dingdong-rest-icon.png',
            title: '暂时没有完成记录',
            body: 'Agent 完成任务后，会在这里留下更完整的结果。',
          )
        else
          for (final Map<String, Object?> event in events) ...<Widget>[
            _EventCard(event: event),
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.prefix,
    required this.count,
    this.suffix = '',
  });

  final String prefix;
  final int count;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: t.surfaceSoft,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: t.textSecondary,
          ),
          children: <InlineSpan>[
            TextSpan(text: prefix),
            TextSpan(
              text: '$count',
              style: TextStyle(fontSize: 11, color: t.text),
            ),
            TextSpan(text: suffix),
          ],
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final Map<String, Object?> run;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final DateTime? started = parseDate(run['startedAt']);
    final String meta = <String?>[
      (run['source'] as String?)?.isNotEmpty == true
          ? run['source']! as String
          : 'Agent',
      started == null ? null : '${formatLifecycleTime(started)} 开始',
      workspaceName(run['workspacePath'] as String?),
    ].whereType<String>().join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.successSoft,
        border: Border.all(color: t.success.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(DingRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 6, right: 5),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2B9A6D),
                ),
              ),
              Expanded(
                child: Text(
                  (run['task'] as String?)?.isNotEmpty == true
                      ? run['task']! as String
                      : '当前任务',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: t.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(meta, style: TextStyle(fontSize: 10, color: t.textSecondary)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final Map<String, Object?> event;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final bool attention = event['notificationKind'] == 'attention';
    final bool unseen = event['unseen'] != false;
    final String summary = (event['summary'] as String?)?.isNotEmpty == true
        ? event['summary']! as String
        : attention
        ? '请查看详情并继续处理。'
        : '本轮任务已经完成。';
    final String detail = (event['detail'] as String?)?.isNotEmpty == true
        ? event['detail']! as String
        : summary;
    final DateTime? started = parseDate(event['startedAt']);
    final DateTime? completed = parseDate(event['completedAt']);
    final String? workspace = workspaceName(event['workspacePath'] as String?);
    final Color border = attention
        ? t.attention.withValues(alpha: 0.38)
        : unseen
        ? t.unseenBorder
        : t.border;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: attention ? t.attentionSoft : t.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(DingRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const DingMascot(
                'assets/dingdong-mobile-alert-icon-2.png',
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (event['title'] as String?)?.isNotEmpty == true
                          ? event['title']! as String
                          : attention
                          ? 'Agent 需要你处理'
                          : 'Agent 完成啦',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${(event['source'] as String?)?.isNotEmpty == true ? event['source'] : 'Agent'} · ${attention ? '需要你处理' : '已完成'}',
                      style: TextStyle(fontSize: 10, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: attention
                  ? t.surface.withValues(alpha: 0.72)
                  : t.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: attention ? t.attentionText : t.text,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _TimeItem(label: '开始', value: formatLifecycleTime(started)),
              _TimeItem(label: '结束', value: formatLifecycleTime(completed)),
              if (started != null &&
                  completed != null &&
                  !completed.isBefore(started))
                _TimeItem(
                  label: '总耗时',
                  value: formatDuration(completed.difference(started)),
                  full: true,
                ),
            ],
          ),
          if (detail != summary) ...<Widget>[
            const SizedBox(height: 9),
            Text(
              detail,
              style: TextStyle(
                fontSize: 12,
                height: 1.58,
                color: t.textSecondary,
              ),
            ),
          ],
          if (workspace != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '项目 · $workspace',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeItem extends StatelessWidget {
  const _TimeItem({
    required this.label,
    required this.value,
    this.full = false,
  });

  final String label;
  final String value;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints.tightFor(
            width: full ? constraints.maxWidth : (constraints.maxWidth - 7) / 2,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: t.surface.withValues(alpha: 0.58),
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: t.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
