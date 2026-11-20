import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:flutter/material.dart';

class LanComputerLabelDialog extends StatefulWidget {
  const LanComputerLabelDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.value,
    required this.save,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String label;
  final String hint;
  final String value;
  final Future<void> Function(String) save;

  @override
  State<LanComputerLabelDialog> createState() => _LanComputerLabelDialogState();
}

class _LanComputerLabelDialogState extends State<LanComputerLabelDialog> {
  late final _input = TextEditingController(text: widget.value);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_input.text);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is FormatException
            ? context.l10n.deviceLabelInvalid
            : context.l10n.deviceLabelSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => DesktopDialogFrame(
    dialogKey: const Key('device-label-dialog'),
    width: 440,
    header: DesktopDialogHeader(
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      onClose: _saving ? null : () => Navigator.pop(context),
    ),
    body: DesktopTextField(
      key: const Key('device-label-input'),
      controller: _input,
      autofocus: true,
      enabled: !_saving,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        helperMaxLines: 2,
        errorText: _error,
      ),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => unawaited(_save()),
    ),
    footer: DesktopDialogFooter(
      actions: [
        DesktopActionButton(
          label: context.l10n.cancel,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        DesktopActionButton(
          key: const Key('device-label-save'),
          label: context.l10n.save,
          tone: DesktopActionTone.primary,
          onPressed: _saving ? null : () => unawaited(_save()),
        ),
      ],
    ),
  );
}
