import 'dart:async';
import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/domain/lan_computer_management.dart';
import 'package:flutter/material.dart';

class LanComputerAddressDialog extends StatefulWidget {
  const LanComputerAddressDialog({
    required this.controller,
    required this.device,
    super.key,
  });
  final LanComputerManagement controller;
  final LinkedDevice device;

  @override
  State<LanComputerAddressDialog> createState() =>
      _LanComputerAddressDialogState();
}

class _LanComputerAddressDialogState extends State<LanComputerAddressDialog> {
  late final _address = TextEditingController(
    text: widget.controller.computerAddressOf(widget.device.id) ?? '',
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final value = _address.text.trim();
    final address = InternetAddress.tryParse(value);
    if (!RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$').hasMatch(value) ||
        address == null ||
        address.type != InternetAddressType.IPv4) {
      setState(() => _error = context.l10n.deviceAddressInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.setComputerAddress(widget.device.id, value);
      if (mounted) Navigator.pop(context);
    } on FormatException {
      if (mounted) setState(() => _error = context.l10n.deviceAddressInvalid);
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.deviceAddressSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DesktopDialogFrame(
    dialogKey: const Key('device-address-dialog'),
    width: 440,
    header: DesktopDialogHeader(
      title: Text(context.l10n.deviceEditAddress),
      subtitle: Text(widget.device.name),
      leading: const Icon(Icons.lan_outlined),
      onClose: _busy ? null : () => Navigator.pop(context),
    ),
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.deviceAddressHint),
        const SizedBox(height: 16),
        DesktopTextField(
          key: const Key('device-address-input'),
          controller: _address,
          autofocus: true,
          enabled: !_busy,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.deviceLanAddress,
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => unawaited(_save()),
        ),
      ],
    ),
    footer: DesktopDialogFooter(
      actions: [
        DesktopActionButton(
          label: context.l10n.cancel,
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        DesktopActionButton(
          key: const Key('device-address-save'),
          label: context.l10n.deviceSaveAndReconnect,
          tone: DesktopActionTone.primary,
          onPressed: _busy ? null : () => unawaited(_save()),
        ),
      ],
    ),
  );
}
