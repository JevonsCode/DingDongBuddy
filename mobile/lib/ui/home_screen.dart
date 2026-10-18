import 'dart:async';

import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_panel.dart';
import 'clipboard_panel.dart';
import 'companion_controller.dart';
import 'dialogs.dart';
import 'tokens.dart';
import 'widgets.dart';

/// The PWA's single screen (docs/app/index.html): header, banners, the
/// 电脑剪贴板 / Agent 提醒 pager and the bottom composer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, this.initialTab = 0});

  final CompanionController controller;
  final int initialTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final PageController _pager = PageController(
    initialPage: widget.initialTab,
  );
  late int _tab = widget.initialTab;
  final TextEditingController _message = TextEditingController();
  final TextEditingController _pairName = TextEditingController();
  PlatformFile? _selectedFile;
  StreamSubscription<String>? _toastSubscription;
  StreamSubscription<void>? _sentSubscription;
  bool _resumed = true;
  String? _pairNameFor;

  CompanionController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_changed);
    _message.addListener(() => setState(() {}));
    _toastSubscription = controller.toasts.listen((String text) {
      if (mounted && text.isNotEmpty) showDingToast(context, text);
    });
    _sentSubscription = controller.sentEvents.listen((_) {
      if (!mounted) return;
      setState(() {
        _message.clear();
        _selectedFile = null;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    unawaited(_toastSubscription?.cancel());
    unawaited(_sentSubscription?.cancel());
    _pager.dispose();
    _message.dispose();
    _pairName.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) {
      unawaited(controller.refreshPermissions());
      _acknowledgeVisibleAgentEvents();
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _acknowledgeVisibleAgentEvents();
  }

  /// Opens the Agent tab, e.g. from a notification tap.
  void showAgentTab() => _selectTab(1);

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    if (_pager.hasClients) {
      unawaited(
        _pager.animateToPage(
          tab,
          duration: const Duration(milliseconds: 260),
          curve: const Cubic(0.22, 1, 0.36, 1),
        ),
      );
    }
    _acknowledgeVisibleAgentEvents();
  }

  /// Like the PWA, reminders count as seen once the Agent tab is visible.
  void _acknowledgeVisibleAgentEvents() {
    final ComputerView? computer = controller.active;
    if (_tab != 1 || !_resumed || computer == null || !computer.connected) {
      return;
    }
    final List<String> keys = <String>[
      for (final Map<String, Object?> event in computer.events)
        if (event['unseen'] != false)
          (event['activityId'] as String?) ?? event['id']! as String,
    ];
    if (keys.isEmpty) return;
    controller.sendForActive('markSeen', <String, Object?>{'ids': keys});
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final PlatformFile file = result.files.single;
    if (file.size > 25 * 1024 * 1024) {
      showDingToast(context, '文件超过 25 MB');
      return;
    }
    setState(() => _selectedFile = file);
  }

  void _send() {
    final ComputerView? computer = controller.active;
    if (computer == null || !computer.connected || computer.sending) return;
    final PlatformFile? file = _selectedFile;
    if (file != null && file.path != null) {
      controller.sendForActive('sendFile', <String, Object?>{
        'path': file.path,
        'name': file.name,
        'mime': _mimeFor(file.extension),
      });
      return;
    }
    final String text = _message.text;
    if (text.trim().isEmpty) return;
    controller.sendForActive('sendText', <String, Object?>{'text': text});
  }

  Future<void> _pasteLink() async {
    final String? link = await showPasteLinkDialog(context);
    if (link != null) controller.offerPairLink(link);
  }

  Future<void> _scan() async {
    try {
      final String? value = await CompanionController.native
          .invokeMethod<String>('scanQr');
      if (value == null || !mounted) return;
      if (!value.contains('#pair=')) {
        showDingToast(context, '这个二维码不是 DingDong 连接码');
        return;
      }
      controller.offerPairLink(value);
    } on PlatformException catch (error) {
      if (mounted) showDingToast(context, '无法打开扫码：${error.message ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final ComputerView? computer = controller.active;
    final bool showContent =
        !controller.booting &&
        controller.pendingPairLink == null &&
        computer != null;
    final SystemUiOverlayStyle overlay =
        Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: t.surface,
      ),
      child: Scaffold(
        backgroundColor: t.surface,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _Header(
                controller: controller,
                onStatus: computer == null
                    ? null
                    : () => showDeviceSwitcher(
                        context,
                        controller,
                        onPaste: _pasteLink,
                        onScan: _scan,
                      ),
                onSettings: computer == null
                    ? null
                    : () => showSettingsDialog(context, controller, computer),
              ),
              Expanded(
                child: controller.booting
                    ? const _CenteredState.boot()
                    : controller.pendingPairLink != null
                    ? _pairView(context)
                    : computer == null
                    ? _EmptyView(onScan: _scan, onPaste: _pasteLink)
                    : _content(context, computer),
              ),
              if (showContent)
                _Composer(
                  computer: computer,
                  message: _message,
                  selectedFile: _selectedFile,
                  progress: controller.progress,
                  onAttach: _pickFile,
                  onClearFile: () => setState(() => _selectedFile = null),
                  onSend: _send,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ComputerView computer) {
    final bool offline = !computer.connected && !computer.connecting;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: <Widget>[
              if (offline)
                DingBanner(
                  title: computer.replaced
                      ? '连接已转移到另一个设备'
                      : computer.manualDisconnect
                      ? '已断开“${computer.hostName}”'
                      : '连不上“${computer.hostName}”',
                  body: computer.replaced
                      ? '同一次配对只能在一台手机或一个页面上使用。'
                      : computer.manualDisconnect
                      ? '需要时点“重新连接”。'
                      : '请确认电脑已开机，DingDong 正在运行。',
                  action: DingButton(
                    label: computer.replaced ? '在此连接' : '重新连接',
                    style: DingButtonStyle.small,
                    onPressed: () => controller.sendForActive('reconnect'),
                  ),
                ),
              if (!controller.notificationsGranted)
                DingBanner(
                  accent: true,
                  image: 'assets/dingdong-mobile-alert-icon.png',
                  title: '让任务状态及时提醒',
                  body: 'Agent 完成或需要你处理时，收起 DingDong 也能收到通知。',
                  action: DingButton(
                    label: '开启',
                    style: DingButtonStyle.smallAccent,
                    onPressed: controller.enableNotifications,
                  ),
                )
              else if (!controller.batteryUnrestricted)
                DingBanner(
                  accent: true,
                  image: 'assets/dingdong-mobile-alert-icon.png',
                  title: '保持后台连接',
                  body: controller.isXiaomi
                      ? '允许后台运行，并在“自启动”里打开 DingDong，锁屏后提醒才不会断。'
                      : '允许后台运行，锁屏后提醒才不会断。',
                  action: DingButton(
                    label: '设置',
                    style: DingButtonStyle.smallAccent,
                    onPressed: () => showBackgroundHelp(context, controller),
                  ),
                ),
              _Tabs(
                selected: _tab,
                clipboardCount: computer.items.length,
                agentCount: computer.unseenCount,
                onSelect: _selectTab,
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pager,
            onPageChanged: (int page) {
              setState(() => _tab = page);
              _acknowledgeVisibleAgentEvents();
            },
            children: <Widget>[
              ClipboardPanel(controller: controller, computer: computer),
              AgentPanel(computer: computer),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pairView(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final String link = controller.pendingPairLink!;
    if (_pairNameFor != link) {
      _pairNameFor = link;
      _pairName.text = controller.deviceName;
    }
    final String host = _hostNameFromLink(link) ?? 'DingDong 电脑';
    final String? room = _roomFromLink(link);
    final bool existing = controller.computers.any(
      (ComputerView c) => c.room == room,
    );
    return CenteredScroll(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Center(
          child: DingMascot('assets/dingdong-thinking-icon.png', size: 112),
        ),
        const SizedBox(height: 19),
        const Center(child: Eyebrow('新的连接')),
        const SizedBox(height: 7),
        Text(
          existing ? '重新连接“$host”？' : '添加“$host”？',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            color: t.text,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '添加后会与已有电脑并列保存，各设备的剪贴板、文件和 Agent 提醒互不混合。'
          '通过端到端加密中继连接，中继不保存内容。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.55, color: t.textSecondary),
        ),
        const SizedBox(height: 24),
        Text(
          '这台手机的名称',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        DingTextField(controller: _pairName, maxLength: 32),
        const SizedBox(height: 12),
        DingButton(
          label: '连接',
          expand: true,
          onPressed: () => controller.confirmPairing(_pairName.text),
        ),
        const SizedBox(height: 8),
        DingButton(
          label: '取消',
          style: DingButtonStyle.quiet,
          expand: true,
          onPressed: controller.cancelPairing,
        ),
      ],
    );
  }

  static String? _roomFromLink(String link) {
    try {
      return DevicePairingPayload.parseInput(link).room;
    } on Object {
      return null;
    }
  }

  static String? _hostNameFromLink(String link) {
    try {
      return DevicePairingPayload.parseInput(link).hostName;
    } on Object {
      return null;
    }
  }

  static String _mimeFor(String? extension) =>
      switch (extension?.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'txt' || 'md' => 'text/plain',
        'zip' => 'application/zip',
        _ => 'application/octet-stream',
      };
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onStatus,
    required this.onSettings,
  });

  final CompanionController controller;
  final VoidCallback? onStatus;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final ComputerView? computer = controller.active;
    final int online = controller.computers
        .where((ComputerView c) => c.connected)
        .length;
    final String label = controller.booting
        ? '正在恢复设备'
        : computer == null
        ? '未连接电脑'
        : computer.replaced
        ? '${computer.hostName} · 已在其他地方连接'
        : computer.connected
        ? '${computer.hostName} · 在线'
        : computer.connecting
        ? '${computer.hostName} · 连接中'
        : '${computer.hostName} · 离线';
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              // The navy mascot needs its light tile in dark mode too.
              color: DingTokens.light.accentSoft,
              borderRadius: BorderRadius.circular(DingRadius.mascot),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/dingdong-icon.png',
              width: 38,
              height: 38,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DingDong',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.15,
                    letterSpacing: -0.35,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                Semantics(
                  button: onStatus != null,
                  label: '$label，$online 台在线，点击切换电脑',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onStatus,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                        bottom: 2,
                        right: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: online > 0 ? t.success : t.offlineDot,
                            ),
                          ),
                          if (controller.computers.length > 1) ...<Widget>[
                            const SizedBox(width: 4),
                            Text(
                              '$online/${controller.computers.length} 台在线',
                              style: TextStyle(
                                fontSize: 10,
                                color: t.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onSettings != null)
            DingIconButton(
              semanticLabel: '设备设置',
              asset: 'assets/symbols/settings.png',
              onPressed: onSettings!,
            ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.clipboardCount,
    required this.agentCount,
    required this.onSelect,
  });

  final int selected;
  final int clipboardCount;
  final int agentCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    Widget tab(int index, String icon, String label, int count) {
      final bool active = selected == index;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 44,
              decoration: BoxDecoration(
                color: active ? t.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(DingRadius.tab),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon.contains('/symbols/'))
                    DingSymbol(icon, size: 17)
                  else
                    DingMascot(icon, size: 19),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? t.accent : t.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: t.field,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: active ? t.accent : t.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: t.surfaceSoft,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          tab(0, 'assets/symbols/clipboard.png', '电脑剪贴板', clipboardCount),
          const SizedBox(width: 6),
          tab(
            1,
            'assets/dingdong-mobile-alert-icon.png',
            'Agent 提醒',
            agentCount,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.computer,
    required this.message,
    required this.selectedFile,
    required this.progress,
    required this.onAttach,
    required this.onClearFile,
    required this.onSend,
  });

  final ComputerView computer;
  final TextEditingController message;
  final PlatformFile? selectedFile;
  final ({String name, int sent, int size})? progress;
  final VoidCallback onAttach;
  final VoidCallback onClearFile;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final bool canSend =
        computer.connected &&
        !computer.sending &&
        (selectedFile != null || message.text.trim().isNotEmpty);
    final ({String name, int sent, int size})? transfer = progress;
    return Container(
      padding: EdgeInsets.fromLTRB(
        13,
        10,
        13,
        9 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: t.border),
          left: BorderSide(color: t.border),
          right: BorderSide(color: t.border),
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DingRadius.sheet),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: t.shadow.withValues(alpha: 0.09),
            blurRadius: 34,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (selectedFile != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.accentSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: <Widget>[
                  Image.asset('assets/symbols/path.png', width: 18, height: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transfer != null && transfer.size > 0
                          ? '${selectedFile!.name} · ${(transfer.sent * 100 / transfer.size).round()}%'
                          : selectedFile!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.accent,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: computer.sending ? null : onClearFile,
                    child: Text(
                      '移除',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Semantics(
                button: true,
                label: '选择文件',
                child: Material(
                  color: t.field,
                  borderRadius: BorderRadius.circular(DingRadius.button),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(DingRadius.button),
                    onTap: onAttach,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: DingSymbol(
                          'assets/symbols/path.png',
                          size: 18,
                          opacity: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: TextField(
                  controller: message,
                  minLines: 1,
                  maxLines: 5,
                  style: TextStyle(fontSize: 13, height: 1.45, color: t.text),
                  decoration: InputDecoration(
                    hintText: '输入或手动粘贴内容…',
                    hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: t.surfaceSoft,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DingRadius.button),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DingRadius.button),
                      borderSide: BorderSide(color: t.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              DingButton(
                label: computer.sending ? '发送中…' : '发送',
                style: DingButtonStyle.primary,
                onPressed: canSend ? onSend : null,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            computer.connected
                ? '发送到 ${computer.hostName}'
                : '${computer.hostName} 未连接，连上后才能发送',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState.boot();

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const DingMascot('assets/dingdong-thinking-icon.png', size: 72),
            const SizedBox(height: 16),
            Text(
              '正在恢复设备',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '正在读取已保存的电脑并恢复安全连接…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatefulWidget {
  const _EmptyView({required this.onScan, required this.onPaste});

  final VoidCallback onScan;
  final VoidCallback onPaste;

  @override
  State<_EmptyView> createState() => _EmptyViewState();
}

class _EmptyViewState extends State<_EmptyView>
    with SingleTickerProviderStateMixin {
  // The PWA's sleeping mascot: two frames swapping every 0.9 s with a 2 px
  // breathing float.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return CenteredScroll(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        AnimatedBuilder(
          animation: _breath,
          builder: (BuildContext context, Widget? child) {
            final double v = _breath.value;
            final double lift = -2 * (0.5 - (v - 0.5).abs()) * 2;
            return Transform.translate(
              offset: Offset(0, lift),
              child: Center(
                child: DingMascot(
                  v < 0.5
                      ? 'assets/dingdong-sleeping-icon.png'
                      : 'assets/dingdong-sleeping-icon-2.png',
                  size: 112,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 19),
        Text(
          '还没有连接电脑',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            color: t.text,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '在电脑 DingDong 的“连接设备”里打开二维码，用手机扫描即可连接。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.55, color: t.textSecondary),
        ),
        const SizedBox(height: 12),
        DingButton(label: '扫描二维码', expand: true, onPressed: widget.onScan),
        const SizedBox(height: 8),
        DingButton(
          label: '粘贴连接链接',
          style: DingButtonStyle.quiet,
          expand: true,
          onPressed: widget.onPaste,
        ),
      ],
    );
  }
}
