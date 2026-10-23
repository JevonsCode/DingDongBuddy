import 'dart:async';
import 'dart:math' as math;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Positions the toolbar/panel above or below the selection and keeps it inside
/// the monitor work area, including monitors with negative desktop coordinates.
Rect selectionOverlayBounds(Rect selection, Rect workArea, Size preferred) {
  final width = math.min(preferred.width, workArea.width);
  final height = math.min(preferred.height, workArea.height);
  final below = selection.bottom + 8;
  final y = below + height <= workArea.bottom
      ? below
      : selection.top - height - 8;
  return Rect.fromLTWH(
    selection.left.clamp(workArea.left, workArea.right - width),
    y.clamp(workArea.top, workArea.bottom - height),
    width,
    height,
  );
}

/// Dedicated child engine: receives ephemeral display state, never credentials.
class SelectionOverlayApp extends StatefulWidget {
  const SelectionOverlayApp({
    required this.windowController,
    required this.parentWindowId,
    @visibleForTesting this.waitForFirstRaster,
    super.key,
  });
  final WindowController windowController;
  final String parentWindowId;
  final Future<void> Function()? waitForFirstRaster;
  @override
  State<SelectionOverlayApp> createState() => _SelectionOverlayAppState();
}

class _SelectionOverlayAppState extends State<SelectionOverlayApp>
    with WindowListener, WidgetsBindingObserver {
  Map<String, Object?> _state = const {'active': false, 'version': -1};
  late final WindowController _parent = WindowController.fromWindowId(
    widget.parentWindowId,
  );
  double? _lastPixelRatio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ratio = View.of(context).devicePixelRatio;
      if (_lastPixelRatio != null &&
          ratio != _lastPixelRatio &&
          _state['active'] == true) {
        unawaited(_receive(_state));
      }
    });
  }

  Future<void> _initialize() async {
    try {
      // Flutter 3.44.6 can swap surface dimensions when a hidden native window
      // resizes an empty scene (FlutterWindowsView::OnEmptyFrameGenerated).
      // https://github.com/flutter/flutter/issues/187922
      // The opaque startup frame must reach the engine before even changing
      // frame decorations, which can also resize the client area.
      await _paintFrame();
      await (widget.waitForFirstRaster?.call() ??
          WidgetsBinding.instance.waitUntilFirstFrameRasterized);
      if (!mounted) return;
      await windowManager.ensureInitialized();
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setResizable(false);
      await windowManager.setPreventClose(true);
      await windowManager.setBackgroundColor(Colors.transparent);
      windowManager.addListener(this);
      await widget.windowController.setWindowMethodHandler((call) async {
        if (call.method == 'selection_state' && call.arguments is Map) {
          await _receive(Map<String, Object?>.from(call.arguments as Map));
        }
      });
      final state = await _parent.invokeMethod<Map>('selection_ready', {
        'windowId': widget.windowController.windowId,
      });
      if (state != null) await _receive(Map<String, Object?>.from(state));
    } catch (_) {
      await windowManager.hide();
    }
  }

  @override
  void onWindowClose() => unawaited(_action('dismiss'));

  Future<void> _paintFrame() async {
    final binding = WidgetsBinding.instance;
    final frame = binding.endOfFrame;
    // A reused hidden window cannot receive ordinary scheduled frames. Warm-up
    // rendering builds the new nonempty scene without showing or focusing it.
    if (!binding.framesEnabled) binding.scheduleWarmUpFrame();
    await frame;
  }

  Future<void> _receive(Map<String, Object?> state) async {
    if (!mounted ||
        (state['version'] as int? ?? 0) < (_state['version'] as int? ?? -1)) {
      return;
    }
    setState(() => _state = state);
    final version = state['version'];
    if (state['active'] != true) {
      await windowManager.hide();
      return;
    }
    final anchor = Map<String, Object?>.from(
      state['anchor'] as Map? ?? const {},
    );
    double number(String key, [double fallback = 0]) =>
        (anchor[key] as num?)?.toDouble() ?? fallback;
    _lastPixelRatio = View.of(context).devicePixelRatio;
    final scale = number('coordinateScale', 1) / _lastPixelRatio!;
    final selection = Rect.fromLTWH(
      number('x') * scale,
      number('y') * scale,
      number('width') * scale,
      number('height') * scale,
    );
    Rect workArea;
    if (number('workAreaWidth') > 0 && number('workAreaHeight') > 0) {
      workArea = Rect.fromLTWH(
        number('workAreaX') * scale,
        number('workAreaY') * scale,
        number('workAreaWidth') * scale,
        number('workAreaHeight') * scale,
      );
    } else {
      final displays = await screenRetriever.getAllDisplays();
      final areas = displays
          .map(
            (d) =>
                (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size),
          )
          .toList();
      workArea = areas.firstWhere(
        (r) => r.contains(selection.center),
        orElse: () =>
            areas.isEmpty ? const Rect.fromLTWH(0, 0, 1280, 720) : areas.first,
      );
    }
    if (!mounted || version != _state['version']) return;
    final expanded = (state['action'] as String? ?? '').isNotEmpty;
    // Build the newly active content before resizing a reused hidden window.
    await _paintFrame();
    if (!mounted || version != _state['version'] || _state['active'] != true) {
      return;
    }
    await windowManager.setBounds(
      selectionOverlayBounds(
        selection,
        workArea,
        expanded ? const Size(480, 460) : const Size(394, 58),
      ),
    );
    if (!mounted || version != _state['version'] || _state['active'] != true) {
      return;
    }
    await windowManager.show(inactive: true);
  }

  Future<void> _action(String action, [String? prompt]) async {
    final id = _state['selectionId'];
    try {
      // Initial selection never steals focus. An explicit button press may.
      if (action != 'dismiss' && action != 'copy') await windowManager.focus();
      final state = await _parent.invokeMethod<Map>('selection_action', {
        'selectionId': id,
        'action': action,
        'prompt': ?prompt,
      });
      if (state != null) await _receive(Map<String, Object?>.from(state));
    } catch (_) {
      if (mounted) {
        setState(() => _state = {..._state, 'busy': false, 'error': 'network'});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    unawaited(widget.windowController.setWindowMethodHandler(null));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.desktopPanelLight(),
    darkTheme: AppTheme.desktopPanelDark(),
    themeMode: switch (_state['themeMode']) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    },
    locale: Locale(_state['languageCode'] as String? ?? 'en'),
    supportedLocales: DingDongLocalizations.supportedLocales,
    localizationsDelegates: DingDongLocalizations.localizationsDelegates,
    home: SelectionOverlayBackground(
      child: _state['active'] != true
          ? null
          : CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    unawaited(_action('dismiss')),
              },
              child: Focus(
                autofocus: true,
                child: SelectionOverlayPanel(
                  key: ValueKey(_state['selectionId']),
                  state: _state,
                  onAction: _action,
                ),
              ),
            ),
    ),
  );
}

/// Keep every frame nonempty, including startup and cleared hidden windows.
/// The surface contains no selected text after the overlay is dismissed.
class SelectionOverlayBackground extends StatelessWidget {
  const SelectionOverlayBackground({this.child, super.key});
  final Widget? child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: SizedBox.expand(child: child),
  );
}

/// Pure presentation surface kept independent of desktop plugins for testing.
class SelectionOverlayPanel extends StatefulWidget {
  const SelectionOverlayPanel({
    required this.state,
    required this.onAction,
    super.key,
  });
  final Map<String, Object?> state;
  final Future<void> Function(String action, [String? prompt]) onAction;
  @override
  State<SelectionOverlayPanel> createState() => _SelectionOverlayPanelState();
}

class _SelectionOverlayPanelState extends State<SelectionOverlayPanel> {
  final _followUp = TextEditingController();
  bool get _zh => widget.state['languageCode'] == 'zh';
  String label(String zh, String en) => _zh
      ? zh
      : widget.state['languageCode'] == 'es'
      ? _spanish[en] ?? en
      : en;
  static const _spanish = <String, String>{
    'Copy': 'Copiar',
    'Translate': 'Traducir',
    'Explain': 'Explicar',
    'Polish': 'Mejorar',
    'Close': 'Cerrar',
    'Send selected text to your configured model when clicked':
        'Envía el texto seleccionado al modelo configurado al hacer clic',
    'Local model': 'Modelo local',
    'Configured cloud model': 'Modelo en la nube configurado',
    'Working…': 'Procesando…',
    'Cancel': 'Cancelar',
    'Retry': 'Reintentar',
    'Cancelled · Retry': 'Cancelado · Reintentar',
    'Copy result': 'Copiar resultado',
    'Ask a follow-up…': 'Haz otra pregunta…',
    'Send': 'Enviar',
    'Check the API key in selection plugin settings.':
        'Revisa la clave API en los ajustes del complemento de selección.',
    'Check the model and endpoint settings.':
        'Revisa los ajustes del modelo y del servidor.',
    'The model timed out. Try again.':
        'El modelo tardó demasiado. Inténtalo de nuevo.',
    'Rate limit reached. Try again shortly.':
        'Se alcanzó el límite de solicitudes. Inténtalo más tarde.',
    'Response too large. Select less text.':
        'La respuesta es demasiado larga. Selecciona menos texto.',
    'The model returned no text. Try again.':
        'El modelo no devolvió texto. Inténtalo de nuevo.',
    'Could not reach the model. Check the service and retry.':
        'No se pudo conectar al modelo. Revisa el servicio e inténtalo de nuevo.',
  };
  @override
  void dispose() {
    _followUp.dispose();
    super.dispose();
  }

  void _send() {
    final text = _followUp.text.trim();
    if (text.isEmpty) return;
    _followUp.clear();
    unawaited(widget.onAction('follow_up', text));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final colors = Theme.of(context).colorScheme;
    final busy = state['busy'] == true;
    final result = state['result'] as String? ?? '';
    final expanded = (state['action'] as String? ?? '').isNotEmpty;
    final error = state['error'] as String?;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(expanded ? 16 : 24),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(expanded ? 16 : 24),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Row(
                      children: [
                        for (final item in <(String, IconData, String)>[
                          ('copy', Icons.copy_rounded, label('复制', 'Copy')),
                          (
                            'translate',
                            Icons.translate_rounded,
                            label('翻译', 'Translate'),
                          ),
                          (
                            'explain',
                            Icons.auto_awesome_outlined,
                            label('解释', 'Explain'),
                          ),
                          (
                            'polish',
                            Icons.edit_outlined,
                            label('润色', 'Polish'),
                          ),
                        ])
                          Expanded(
                            child: Tooltip(
                              message: item.$1 == 'copy'
                                  ? item.$3
                                  : label(
                                      '点击后将选中文本发送至已配置模型',
                                      'Send selected text to your configured model when clicked',
                                    ),
                              child: DesktopActionButton(
                                onPressed: busy
                                    ? null
                                    : () => unawaited(widget.onAction(item.$1)),
                                style: DesktopActionButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(item.$2, size: 15),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item.$3,
                                        maxLines: 1,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 30,
                          child: DesktopIconButton(
                            tooltip: label('关闭', 'Close'),
                            size: 30,
                            padding: EdgeInsets.zero,
                            iconSize: 17,
                            onPressed: () =>
                                unawaited(widget.onAction('dismiss')),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (expanded) ...[
                  Divider(height: 1, color: colors.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state['local'] == true
                                  ? Icons.computer
                                  : Icons.cloud_outlined,
                              size: 13,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                state['local'] == true
                                    ? label('本机模型', 'Local model')
                                    : label(
                                        '已配置的云端模型',
                                        'Configured cloud model',
                                      ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state['text'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: busy
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(label('正在处理…', 'Working…')),
                                  ),
                                  DesktopActionButton(
                                    onPressed: () =>
                                        unawaited(widget.onAction('cancel')),
                                    child: Text(label('取消', 'Cancel')),
                                  ),
                                ],
                              ),
                            )
                          : error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: colors.error,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _errorLabel(error),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  DesktopActionButton(
                                    onPressed: () =>
                                        unawaited(widget.onAction('retry')),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: Text(label('重试', 'Retry')),
                                  ),
                                ],
                              ),
                            )
                          : result.isEmpty
                          ? Center(
                              child: DesktopActionButton(
                                onPressed: () =>
                                    unawaited(widget.onAction('retry')),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: Text(
                                  label('已取消 · 重试', 'Cancelled · Retry'),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: SelectableText(
                                  result,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (result.isNotEmpty && !busy)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: DesktopActionButton(
                          onPressed: () =>
                              unawaited(widget.onAction('copy_result')),
                          icon: const Icon(Icons.copy, size: 14),
                          label: Text(label('复制结果', 'Copy result')),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: DesktopTextField(
                            controller: _followUp,
                            enabled: !busy && result.isNotEmpty,
                            maxLength: 4000,
                            maxLines: 1,
                            onSubmitted: (_) => _send(),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              counterText: '',
                              isDense: true,
                              hintText: label('继续提问…', 'Ask a follow-up…'),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        DesktopIconButton(
                          tooltip: label('发送', 'Send'),
                          backgroundColor: colors.surfaceContainerHigh,
                          onPressed: !busy && result.isNotEmpty ? _send : null,
                          icon: const Icon(Icons.arrow_upward, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _errorLabel(String code) => switch (code) {
    'token_required' || 'authentication' => label(
      '请在划词插件设置中检查 API 密钥。',
      'Check the API key in selection plugin settings.',
    ),
    'configuration' => label(
      '请检查模型及服务地址设置。',
      'Check the model and endpoint settings.',
    ),
    'timeout' => label('模型响应超时，请重试。', 'The model timed out. Try again.'),
    'rate_limit' => label(
      '请求过于频繁，请稍后重试。',
      'Rate limit reached. Try again shortly.',
    ),
    'response_too_large' => label(
      '模型回复过长，请缩短选中的文本。',
      'Response too large. Select less text.',
    ),
    'empty_response' => label(
      '模型未返回文本，请重试。',
      'The model returned no text. Try again.',
    ),
    _ => label(
      '无法连接模型，请检查服务后重试。',
      'Could not reach the model. Check the service and retry.',
    ),
  };
}
