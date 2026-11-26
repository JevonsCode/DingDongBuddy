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
  final _codeFocus = FocusNode();
  final _address = TextEditingController();
  String? _addressError;
  String? _generalError;
  NearbyComputer? _selected;
  bool _refreshing = false;
  bool _refreshFailed = false;
  bool _slowAction = false;
  Timer? _slowActionTimer;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _slowActionTimer?.cancel();
    _codeFocus.dispose();
    _code.dispose();
    _address.dispose();
    unawaited(
      widget.controller.cancelComputerPairing().catchError((Object _) {}),
    );
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });
    try {
      await widget.controller.refreshComputers().timeout(
        const Duration(seconds: 25),
      );
    } on Object {
      if (mounted) setState(() => _refreshFailed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
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
    _slowActionTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() => _slowAction = true);
    });
    try {
      await action();
      if (mounted && finish && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          if (address) {
            _addressError = failure is FormatException
                ? context.l10n.deviceAddressInvalid
                : context.l10n.lanLookupUnavailable;
          } else {
            _generalError = finish
                ? context.l10n.lanPairingFailed
                : context.l10n.lanGenerateFailed;
          }
        });
      }
    } finally {
      _slowActionTimer?.cancel();
      if (mounted) {
        setState(() {
          _slowAction = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _find() => _run(
    () => widget.controller.discoverComputerAddress(_address.text.trim()),
    address: true,
  );

  Future<void> _join() async {
    final code = _code.text;
    final selected = _selected;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = context.l10n.lanEnterSixDigits);
      return;
    }
    await _run(
      () => selected == null
          ? widget.controller.joinComputer(code)
          : widget.controller.joinNearbyComputer(selected.id, code),
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
          onClose: _busy && !_slowAction ? null : () => Navigator.pop(context),
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.lanGenerateHint),
              const SizedBox(height: 10),
              DesktopTextField(
                key: const Key('device-computer-pairing-input'),
                controller: _code,
                focusNode: _codeFocus,
                autofocus: true,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l.lanSixDigitCode,
                  hintText: '000000',
                  helperText: _selected?.name,
                  suffixIcon: _selected == null
                      ? null
                      : DesktopIconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l.lanClearPeer,
                          onPressed: _busy
                              ? null
                              : () => setState(() => _selected = null),
                        ),
                  errorText: _error,
                  errorMaxLines: 3,
                  counterText: '',
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => unawaited(_join()),
              ),
              if (_generalError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _generalError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
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
                if (!_busy && !widget.controller.codeLookupAvailable)
                  Text(l.lanCodeLookupUnavailable),
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
              if (_slowAction) Text(l.lanStillWorking),
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
                    onPressed: _busy || _refreshing
                        ? null
                        : () => unawaited(_refresh()),
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
                  selected: _selected?.id == computer.id,
                  trailing: _selected?.id == computer.id
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: _busy || !computer.pairing
                      ? null
                      : () {
                          setState(() {
                            _selected = computer;
                            _error = null;
                          });
                          _codeFocus.requestFocus();
                        },
                ),
              const SizedBox(height: 12),
              SelectableText(
                widget.controller.localComputerAddresses.isNotEmpty
                    ? l.deviceLocalAddresses(
                        widget.controller.localComputerAddresses.join(' · '),
                      )
                    : _refreshing
                    ? l.deviceLocalAddressLoading
                    : l.deviceLocalAddressUnavailable,
                key: const Key('device-computer-local-addresses'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DesktopTextField(
                key: const Key('device-computer-find-address'),
                controller: _address,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l.devicePeerLanAddress,
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
              if (_refreshFailed ||
                  widget.controller.computerDiscoveryError != null) ...[
                const SizedBox(height: 8),
                Text(switch (widget.controller.computerDiscoveryError) {
                  'address_in_use' => l.lanPortBusy,
                  'access_denied' => l.lanNetworkAccessDenied,
                  _ => l.lanNetworkHelp,
                }),
              ],
              const SizedBox(height: 12),
              Text(
                l.computerSyncDefaultsNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        footer: DesktopDialogFooter(
          actions: [
            DesktopActionButton(
              label: _slowAction ? l.close : l.cancel,
              onPressed: _busy && !_slowAction
                  ? null
                  : () => Navigator.pop(context),
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
      );
    },
  );
}
