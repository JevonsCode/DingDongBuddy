import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/date_filter_range.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String dateFilterLabel(BuildContext context, DateFilterPreset preset) =>
    switch (preset) {
      DateFilterPreset.yesterday => context.l10n.dateFilterYesterday,
      DateFilterPreset.lastThreeDays => context.l10n.dateFilterLastThreeDays,
      DateFilterPreset.thisWeek => context.l10n.dateFilterThisWeek,
      DateFilterPreset.thisMonth => context.l10n.dateFilterThisMonth,
      DateFilterPreset.lastMonth => context.l10n.dateFilterLastMonth,
      DateFilterPreset.lastThreeMonths =>
        context.l10n.dateFilterLastThreeMonths,
      DateFilterPreset.thisYear => context.l10n.dateFilterThisYear,
      DateFilterPreset.custom => context.l10n.dateFilterCustom,
    };

String dateRangeLabel(BuildContext context, DateTimeRange range) {
  final format = DateFormat.yMd(
    Localizations.localeOf(context).toLanguageTag(),
  );
  return '${format.format(range.start)} – ${format.format(range.end)}';
}

/// The same anchored control and desktop calendar for both history views.
class DesktopDateFilter extends StatelessWidget {
  const DesktopDateFilter({
    required this.value,
    required this.onChanged,
    this.customRange,
    this.now,
    this.allowAll = false,
    super.key,
  });
  final DateFilterPreset? value;
  final DateTimeRange? customRange;
  final DateTime Function()? now;
  final bool allowAll;
  final void Function(DateFilterPreset?, DateTimeRange?) onChanged;

  @override
  Widget build(BuildContext context) => DesktopSelectField<DateFilterPreset?>(
    value: value,
    semanticLabel: context.l10n.tokenUsageRange,
    items: [
      if (allowAll)
        DesktopSelectItem(value: null, label: context.l10n.dateFilterAll),
      for (final preset in DateFilterPreset.values)
        DesktopSelectItem(
          value: preset,
          label: preset == DateFilterPreset.custom && customRange != null
              ? dateRangeLabel(context, customRange!)
              : dateFilterLabel(context, preset),
        ),
    ],
    onChanged: (preset) async {
      if (preset != DateFilterPreset.custom) {
        onChanged(preset, customRange);
        return;
      }
      final today = DateUtils.dateOnly((now ?? DateTime.now)());
      final picked = await showDesktopDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: today,
        initialRange:
            customRange ?? DateFilterPreset.lastThreeDays.bounds(today)!,
      );
      if (picked != null && context.mounted) onChanged(preset, picked);
    },
  );
}

Future<DateTimeRange?> showDesktopDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTimeRange initialRange,
}) => showDialog<DateTimeRange>(
  context: context,
  builder: (_) => _DateRangeDialog(
    firstDate: DateUtils.dateOnly(firstDate),
    lastDate: DateUtils.dateOnly(lastDate),
    initialRange: initialRange,
  ),
);

class _DateRangeDialog extends StatefulWidget {
  const _DateRangeDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialRange,
  });
  final DateTime firstDate, lastDate;
  final DateTimeRange initialRange;
  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _startText, _endText;
  late DateTime _month;
  DateTime? _start, _end;
  bool _pickingEnd = false;
  final _inputFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _start = DateUtils.dateOnly(widget.initialRange.start);
    _end = DateUtils.dateOnly(widget.initialRange.end);
    _month = DateTime(_start!.year, _start!.month);
    _startText = TextEditingController(text: _inputFormat.format(_start!));
    _endText = TextEditingController(text: _inputFormat.format(_end!));
  }

  @override
  void dispose() {
    _startText.dispose();
    _endText.dispose();
    super.dispose();
  }

  DateTime? _parse(String value) {
    try {
      return _inputFormat.parseStrict(value.trim());
    } on FormatException {
      return null;
    }
  }

  String? _validate(String? value, {bool end = false}) {
    final date = _parse(value ?? '');
    if (date == null ||
        date.isBefore(widget.firstDate) ||
        date.isAfter(widget.lastDate)) {
      return context.l10n.dateFilterInvalidDate;
    }
    final start = _parse(_startText.text);
    if (end && start != null && date.isBefore(start)) {
      return context.l10n.dateFilterInvalidRange;
    }
    return null;
  }

  void _pick(DateTime day) {
    setState(() {
      if (!_pickingEnd || _start == null) {
        _start = day;
        _end = null;
        _pickingEnd = true;
      } else {
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        _pickingEnd = false;
      }
      _startText.text = _inputFormat.format(_start!);
      _endText.text = _end == null ? '' : _inputFormat.format(_end!);
    });
  }

  void _typed() {
    setState(() {
      _start = _parse(_startText.text);
      _end = _parse(_endText.text);
    });
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      DateTimeRange(
        start: _parse(_startText.text)!,
        end: _parse(_endText.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final material = MaterialLocalizations.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.dateFilterCustom,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    DesktopIconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: material.closeButtonTooltip,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _form,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DesktopTextFormField(
                          key: const Key('date-range-start'),
                          controller: _startText,
                          decoration: InputDecoration(
                            labelText: context.l10n.dateFilterStart,
                            hintText: 'yyyy-MM-dd',
                            isDense: true,
                          ),
                          validator: _validate,
                          onChanged: (_) => _typed(),
                          onFieldSubmitted: (_) => _apply(),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 14, 12, 0),
                        child: Text('–'),
                      ),
                      Expanded(
                        child: DesktopTextFormField(
                          key: const Key('date-range-end'),
                          controller: _endText,
                          decoration: InputDecoration(
                            labelText: context.l10n.dateFilterEnd,
                            hintText: 'yyyy-MM-dd',
                            isDense: true,
                          ),
                          validator: (v) => _validate(v, end: true),
                          onChanged: (_) => _typed(),
                          onFieldSubmitted: (_) => _apply(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DesktopIconButton(
                      key: const Key('date-range-previous'),
                      icon: const Icon(Icons.chevron_left),
                      tooltip: material.previousMonthTooltip,
                      onPressed:
                          _month.isAfter(
                            DateTime(
                              widget.firstDate.year,
                              widget.firstDate.month,
                            ),
                          )
                          ? () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month - 1,
                              ),
                            )
                          : null,
                    ),
                    DesktopIconButton(
                      key: const Key('date-range-next'),
                      icon: const Icon(Icons.chevron_right),
                      tooltip: material.nextMonthTooltip,
                      onPressed:
                          DateTime(_month.year, _month.month + 1).isBefore(
                            DateTime(
                              widget.lastDate.year,
                              widget.lastDate.month,
                            ),
                          )
                          ? () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month + 1,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _calendar(_month)),
                      if (constraints.maxWidth >= 540) ...[
                        const SizedBox(width: 20),
                        Expanded(
                          child: _calendar(
                            DateTime(_month.year, _month.month + 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DesktopActionButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(material.cancelButtonLabel),
                    ),
                    const SizedBox(width: 8),
                    DesktopActionButton(
                      key: const Key('date-range-apply'),
                      onPressed: _apply,
                      style: DesktopActionButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                      child: Text(context.l10n.dateFilterApply),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendar(DateTime month) {
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final startOffset = month.weekday - 1;
    // Callers bound this history picker at their local today.
    final today = widget.lastDate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.yMMMM(locale).format(month),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        Table(
          children: [
            TableRow(
              children: [
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: Text(
                        DateFormat.E(locale).format(DateTime(2026, 1, 5 + i)),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < 6; row++)
              TableRow(
                children: [
                  for (var col = 0; col < 7; col++)
                    Builder(
                      builder: (context) {
                        final day = DateTime(
                          month.year,
                          month.month,
                          row * 7 + col - startOffset + 1,
                        );
                        if (day.month != month.month) {
                          return const SizedBox(height: 34);
                        }
                        final selected =
                            DateUtils.isSameDay(day, _start) ||
                            DateUtils.isSameDay(day, _end);
                        final between =
                            _start != null &&
                            _end != null &&
                            day.isAfter(_start!) &&
                            day.isBefore(_end!);
                        final enabled =
                            !day.isBefore(widget.firstDate) &&
                            !day.isAfter(widget.lastDate);
                        return SizedBox(
                          height: 34,
                          child: DesktopActionButton(
                            key: ValueKey(
                              'date-day-${_inputFormat.format(day)}',
                            ),
                            onPressed: enabled ? () => _pick(day) : null,
                            height: 34,
                            style: DesktopActionButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              foregroundColor: selected
                                  ? colors.onPrimary
                                  : colors.onSurface,
                              backgroundColor: selected
                                  ? colors.primary
                                  : between
                                  ? colors.primary.withValues(alpha: 0.09)
                                  : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  selected ? 5 : 0,
                                ),
                              ),
                              side: day == today && !selected
                                  ? BorderSide(
                                      color: colors.primary.withValues(
                                        alpha: 0.5,
                                      ),
                                    )
                                  : BorderSide.none,
                            ),
                            child: Text(
                              '${day.day}',
                              semanticsLabel: DateFormat.yMMMMd(
                                locale,
                              ).format(day),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
