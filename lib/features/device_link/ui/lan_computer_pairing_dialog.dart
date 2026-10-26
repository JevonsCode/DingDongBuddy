import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/features/device_link/domain/lan_computer_management.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LanComputerPairingDialog extends StatefulWidget {
  const LanComputerPairingDialog({required this.controller, super.key});
  final LanComputerManagement controller;
  @override
  State<LanComputerPairingDialog> createState() =>
      _LanComputerPairingDialogState();
}

class _LanComputerPairingDialogState extends State<LanComputerPairingDialog> {
  final _code = TextEditingController();
  final _address = TextEditingController();
  String? _addressError;
  String? _generalError;
  String? _selected;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(_run(widget.controller.refreshComputers));
  }

  @override
  void dispose() {
    _code.dispose();
    _address.dispose();
    unawaited(
      widget.controller.cancelComputerPairing().catchError((Object _) {}),
    );
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool finish = false,
    bool address = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _generalError = null;
      _addressError = null;
    });
    try {
      await action();
      if (mounted && finish) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(() {
          if (address && failure is FormatException) {
            _addressError = context.l10n.deviceAddressInvalid;
          } else {
            _generalError = finish
                ? context.l10n.lanPairingFailed
                : context.l10n.lanNetworkHelp;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _find() => _run(
    () => widget.controller.discoverComputerAddress(_address.text.trim()),
    address: true,
  );

  Future<void> _join() async {
    if (_selected == null || !RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _error = context.l10n.lanSelectAndEnterCode);
      return;
    }
    await _run(
      () => widget.controller.joinNearbyComputer(_selected!, _code.text),
      finish: true,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final l = context.l10n;
      final code = widget.controller.computerPairingCode;
      final nearby = widget.controller.nearbyComputers;
      return DesktopDialogFrame(
        dialogKey: const Key('device-computer-pairing-dialog'),
        width: 500,
        maxHeight: 660,
        header: DesktopDialogHeader(
          title: Text(l.connectAnotherComputer),
          subtitle: Text(l.lanComputerOnly),
          leading: const Icon(Icons.lan_outlined),
          onClose: _busy ? null : () => Navigator.pop(context),
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.lanGenerateHint),
              const SizedBox(height: 10),
              if (code != null) ...[
                SelectableText(
                  '${code.substring(0, 3)} ${code.substring(3)}',
                  key: const Key('device-computer-pairing-code'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(letterSpacing: 6),
                ),
                const SizedBox(height: 6),
                Text(l.lanCodeExpiry, textAlign: TextAlign.center),
                const SizedBox(height: 10),
              ],
              DesktopActionButton(
                key: const Key('device-computer-generate-code'),
                label: code == null ? l.lanGenerateCode : l.lanNewCode,
                icon: Icons.pin_outlined,
                onPressed: _busy
                    ? null
                    : () => unawaited(
                        _run(widget.controller.beginComputerPairing),
                      ),
              ),
              const Divider(height: 30),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.lanNearbyComputers,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  DesktopActionButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _run(widget.controller.refreshComputers),
                          ),
                    label: l.lanRefresh,
                  ),
                ],
              ),
              if (nearby.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l.lanNoComputers),
                ),
              for (final computer in nearby)
                ListTile(
                  key: Key('nearby-computer-${computer.id}'),
                  dense: true,
                  leading: const Icon(Icons.computer_rounded),
                  title: Text(
                    computer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    computer.pairing
                        ? l.lanEnterOtherCode
                        : l.lanWaitingForCode,
                  ),
                  selected: _selected == computer.id,
                  trailing: _selected == computer.id
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: _busy || !computer.pairing
                      ? null
                      : () => setState(() {
                          _selected = computer.id;
                          _error = null;
                        }),
                ),
              const SizedBox(height: 12),
              if (widget.controller.localComputerAddresses.isNotEmpty) ...[
                SelectableText(
                  l.deviceLocalAddresses(
                    widget.controller.localComputerAddresses.join(' · '),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              DesktopTextField(
                key: const Key('device-computer-find-address'),
                controller: _address,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l.deviceLanAddress,
                  helperText: l.lanFindByIpHelp,
                  helperMaxLines: 2,
                  errorText: _addressError,
                  errorMaxLines: 3,
                  suffixIcon: DesktopIconButton(
                    key: const Key('device-computer-find-address-submit'),
                    icon: const Icon(Icons.search),
                    tooltip: l.lanFindByIp,
                    onPressed: _busy ? null : () => unawaited(_find()),
                  ),
                ),
                onSubmitted: (_) => unawaited(_find()),
              ),
              const SizedBox(height: 16),
              DesktopTextField(
                key: const Key('device-computer-pairing-input'),
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l.lanSixDigitCode,
                  hintText: '000000',
                  errorText: _error,
                  errorMaxLines: 3,
                  counterText: '',
                ),
                onSubmitted: (_) => unawaited(_join()),
              ),
              if (widget.controller.computerDiscoveryError != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.controller.computerDiscoveryError == 'address_in_use'
                      ? l.lanPortBusy
                      : l.lanNetworkHelp,
                ),
              ],
              if (_generalError != null &&
                  widget.controller.computerDiscoveryError == null) ...[
                const SizedBox(height: 8),
                Text(
                  _generalError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l.computerSyncDefaultsNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  DesktopActionButton(
                    label: l.cancel,
                    onPressed: _busy ? null : () => Navigator.pop(context),
                  ),
                  DesktopActionButton(
                    key: const Key('device-computer-pairing-submit'),
                    label: _busy ? l.lanWorking : l.connectComputer,
                    icon: Icons.link_rounded,
                    tone: DesktopActionTone.primary,
                    onPressed: _busy ? null : () => unawaited(_join()),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
