import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_slider.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/platform/native_screenshot_plugin_gateway.dart';
import 'package:dingdong/platform/shared_preferences_backend.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:window_manager/window_manager.dart';

const screenshotEditorWindowKind =
    NativeScreenshotPluginGateway.editorWindowKind;

/// Auxiliary engine entry point. The screenshot never enters JSON arguments.
Future<void> runScreenshotEditorWindow(
  WindowController controller,
  Map<String, Object?> arguments,
) async {
  await prepareScreenshotEditorWindow();
  final settings = await SettingsRepository(SharedPreferencesBackend()).load();
  runApp(
    ScreenshotEditorWindow(
      controller: controller,
      initialSession: arguments['session']! as int,
      settings: settings,
    ),
  );
}

/// Paint before any native resizing: Flutter 3.44.6 swaps surface dimensions
/// when resizing an empty scene (FlutterWindowsView::OnEmptyFrameGenerated).
/// https://github.com/flutter/flutter/issues/187922
Future<void> prepareScreenshotEditorWindow({
  @visibleForTesting Future<void> Function()? waitForFirstRaster,
}) async {
  runApp(const ScreenshotEditorBackground());
  await WidgetsBinding.instance.endOfFrame;
  // Framework layout alone is insufficient: the engine must receive the
  // nonempty scene before the first native size change.
  await (waitForFirstRaster?.call() ??
      WidgetsBinding.instance.waitUntilFirstFrameRasterized);
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1120, 780),
      minimumSize: Size(760, 520),
      center: true,
      title: 'DingDong · Screenshot',
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    ),
  );
  await windowManager.setPreventClose(true);
}

/// Remains nonempty while loading, hidden, or clearing a capture for reuse.
class ScreenshotEditorBackground extends StatelessWidget {
  const ScreenshotEditorBackground({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF1D282E), child: SizedBox.expand());
}

class ScreenshotEditorWindow extends StatefulWidget {
  const ScreenshotEditorWindow({
    super.key,
    required this.controller,
    required this.initialSession,
    required this.settings,
    @visibleForTesting this.loadSettings,
  });
  final WindowController controller;
  final int initialSession;
  final AppSettings settings;
  final Future<AppSettings> Function()? loadSettings;
  @override
  State<ScreenshotEditorWindow> createState() => _ScreenshotEditorWindowState();
}

class _ScreenshotEditorWindowState extends State<ScreenshotEditorWindow>
    with WindowListener {
  Uint8List? _bytes;
  late AppSettings _settings;
  int _session = 0;
  int _loadRevision = 0;
  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    windowManager.addListener(this);
    unawaited(
      widget.controller.setWindowMethodHandler((call) async {
        if (call.method == 'load') await _load(call.arguments as int);
        if (call.method == 'dismiss') await _close();
      }),
    );
    unawaited(_load(widget.initialSession));
  }

  Future<void> _load(int session) async {
    final revision = ++_loadRevision;
    _session = session;
    if (mounted) setState(() => _bytes = null);
    try {
      final bytes = await NativeScreenshotPluginGateway.editorChannel
          .invokeMethod<Uint8List>('read', session);
      final settings =
          await (widget.loadSettings?.call() ??
              SettingsRepository(SharedPreferencesBackend()).load());
      if (!mounted || revision != _loadRevision) return;
      if (bytes == null || bytes.isEmpty) {
        await _close();
        return;
      }
      setState(() {
        _bytes = bytes;
        _settings = settings;
      });
      // Submit a fresh scene while hidden, before exposing the native window.
      // Warm-up frames do not depend on native vsync, including the interval
      // before a hidden window's lifecycle notification reaches Flutter.
      final binding = WidgetsBinding.instance;
      final frame = binding.endOfFrame;
      binding.scheduleWarmUpFrame();
      await frame;
      if (!mounted || revision != _loadRevision) return;
      await windowManager.show();
      if (!mounted || revision != _loadRevision) return;
      await windowManager.focus();
    } catch (_) {
      if (mounted && revision == _loadRevision) await _close();
    }
  }

  Future<void> _close() async {
    final session = _session;
    ++_loadRevision;
    // Release images and undo history even though the engine is reusable.
    if (mounted) setState(() => _bytes = null);
    await widget.controller.hide();
    try {
      await NativeScreenshotPluginGateway.editorChannel.invokeMethod<void>(
        'finish',
        session,
      );
    } catch (_) {
      /* The primary engine may already be exiting. */
    }
  }

  @override
  void onWindowClose() => unawaited(_close());
  @override
  void dispose() {
    windowManager.removeListener(this);
    unawaited(widget.controller.setWindowMethodHandler(null));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revision = _loadRevision;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.desktopPanelLight(),
      darkTheme: AppTheme.desktopPanelDark(),
      themeMode: switch (_settings.themeMode) {
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.system => ThemeMode.system,
      },
      locale: resolveAppLocale(_settings.language),
      supportedLocales: const [Locale('zh'), Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: _bytes == null
          ? const ScreenshotEditorBackground()
          : ScreenshotEditor(
              key: ValueKey(_session),
              bytes: _bytes!,
              language: resolveAppLocale(_settings.language).languageCode,
              onClose: _close,
              isCaptureCurrent: () => mounted && revision == _loadRevision,
            ),
    );
  }
}

/// DingDong desktop chrome around pro_image_editor 14.16.0 (BSD-3-Clause),
/// https://github.com/hm21/pro_image_editor. Uses public extension APIs only.
class ScreenshotEditor extends StatefulWidget {
  const ScreenshotEditor({
    super.key,
    required this.bytes,
    required this.onClose,
    this.language = 'en',
    this.copyImage,
    this.saveImage,
    this.selectSavePath,
    this.isCaptureCurrent,
    @visibleForTesting this.captureImage,
  });
  final Uint8List bytes;
  final Future<void> Function() onClose;
  final String language;
  final Future<void> Function(Uint8List)? copyImage;
  final Future<bool> Function(Uint8List)? saveImage;
  final Future<String?> Function()? selectSavePath;
  // Invalidated synchronously by the host, before a scheduled widget teardown.
  final bool Function()? isCaptureCurrent;
  final Future<Uint8List> Function()? captureImage;
  @override
  State<ScreenshotEditor> createState() => _ScreenshotEditorState();
}

class _ScreenshotEditorState extends State<ScreenshotEditor> {
  final _editorKey = GlobalKey<ProImageEditorState>();
  bool _busy = false;
  String? _error;
  bool get _captureIsCurrent =>
      mounted && (widget.isCaptureCurrent?.call() ?? true);
  String t(String en, String zh, String es) => switch (widget.language) {
    'zh' => zh,
    'es' => es,
    _ => en,
  };
  String get _cancel => t('Cancel', '取消', 'Cancelar');
  String get _done => t('Apply', '应用', 'Aplicar');
  String get _undo => t('Undo', '撤销', 'Deshacer');
  String get _redo => t('Redo', '重做', 'Rehacer');

  Future<String?> _selectSavePath() async {
    final location = await getSaveLocation(
      suggestedName:
          'DingDong-${DateTime.now().toIso8601String().replaceAll(':', '-')}.png',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PNG', extensions: ['png']),
      ],
    );
    return location?.path;
  }

  Future<bool> _save(Uint8List bytes) async {
    final capture = widget.bytes;
    final path = await (widget.selectSavePath ?? _selectSavePath)();
    // The native picker can outlive a disabled plugin or a replaced capture.
    // Check after the await so a stale dialog can never write the old image.
    if (!_captureIsCurrent ||
        !identical(widget.bytes, capture) ||
        path == null) {
      return false;
    }
    await XFile.fromData(bytes, mimeType: 'image/png').saveTo(path);
    return true;
  }

  Future<void> _export({required bool save}) async {
    if (!_captureIsCurrent || _busy || _editorKey.currentState == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final png =
          await (widget.captureImage?.call() ??
              _editorKey.currentState!.captureEditorImage());
      if (png.isEmpty) throw StateError('Empty editor output');
      if (!_captureIsCurrent) return;
      if (save) {
        final saved = await (widget.saveImage ?? _save)(png);
        if (!saved) return;
      } else {
        await (widget.copyImage ?? Pasteboard.writeImage)(png);
      }
      if (_captureIsCurrent) await widget.onClose();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t(
            'Could not export. Your edits are still here. Please try again.',
            '导出失败，编辑内容仍保留，请重试。',
            'No se pudo exportar. Los cambios siguen aquí. Inténtalo de nuevo.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _action(
    IconData icon,
    String text,
    VoidCallback? action, {
    bool selected = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: DesktopActionButton(
      onPressed: _busy ? null : action,
      style: selected
          ? DesktopActionButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            )
          : null,
      icon: Icon(icon, size: 18),
      label: Text(text),
    ),
  );

  PreferredSizeWidget _mainBar(ProImageEditorState editor) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 58,
    titleSpacing: 12,
    title: Row(
      children: [
        const Icon(Icons.screenshot_monitor_outlined, size: 22),
        const SizedBox(width: 10),
        Text(
          t('Screenshot', '截图编辑', 'Captura'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 14),
        DesktopIconButton(
          tooltip: '$_undo · Ctrl+Z',
          onPressed: !_busy && editor.canUndo ? editor.undoAction : null,
          icon: const Icon(Icons.undo, size: 19),
        ),
        DesktopIconButton(
          tooltip: '$_redo · Ctrl+Y',
          onPressed: !_busy && editor.canRedo ? editor.redoAction : null,
          icon: const Icon(Icons.redo, size: 19),
        ),
      ],
    ),
    actions: [
      _action(Icons.close, _cancel, () => unawaited(widget.onClose())),
      _action(
        Icons.save_alt,
        t('Save as', '另存为', 'Guardar como'),
        () => unawaited(_export(save: true)),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 6, right: 14),
        child: DesktopActionButton(
          tone: DesktopActionTone.primary,
          onPressed: _busy ? null : () => unawaited(_export(save: false)),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.copy, size: 17),
          label: Text(t('Copy image', '复制图片', 'Copiar imagen')),
        ),
      ),
    ],
  );

  Widget _tools(ProImageEditorState editor, Key key) => Container(
    key: key,
    height: 76,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _action(
              Icons.draw_outlined,
              t('Annotate / redact', '标注 / 遮挡', 'Anotar / ocultar'),
              editor.openPaintEditor,
            ),
            const SizedBox(width: 12),
            _action(
              Icons.text_fields,
              t('Text', '文字', 'Texto'),
              editor.openTextEditor,
            ),
          ],
        ),
        Text(
          t(
            'Drag layers to position · Wheel to zoom · Ctrl+C copy · Ctrl+S save',
            '拖动图层调整位置 · 滚轮缩放 · Ctrl+C 复制 · Ctrl+S 保存',
            'Arrastra las capas · Rueda para zoom · Ctrl+C copiar · Ctrl+S guardar',
          ),
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  PreferredSizeWidget _paintBar(PaintEditorState editor) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 58,
    titleSpacing: 8,
    title: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (mode, icon, title) in <(PaintMode, IconData, String)>[
            (PaintMode.arrow, Icons.north_east, t('Arrow', '箭头', 'Flecha')),
            (
              PaintMode.rect,
              Icons.crop_square,
              t('Rectangle', '矩形', 'Rectángulo'),
            ),
            (
              PaintMode.circle,
              Icons.circle_outlined,
              t('Ellipse', '椭圆', 'Elipse'),
            ),
            (PaintMode.freeStyle, Icons.edit_outlined, t('Pen', '画笔', 'Lápiz')),
            (PaintMode.pixelate, Icons.grid_on, t('Mosaic', '马赛克', 'Mosaico')),
            (PaintMode.blur, Icons.blur_on, t('Blur', '模糊', 'Difuminar')),
          ])
            _action(
              icon,
              title,
              () => editor.setMode(mode),
              selected: editor.paintMode == mode,
            ),
        ],
      ),
    ),
    actions: [
      DesktopIconButton(
        tooltip: _undo,
        onPressed: editor.undoAction,
        icon: const Icon(Icons.undo, size: 19),
      ),
      DesktopIconButton(
        tooltip: _redo,
        onPressed: editor.redoAction,
        icon: const Icon(Icons.redo, size: 19),
      ),
      _action(Icons.close, _cancel, () => Navigator.of(editor.context).pop()),
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: DesktopActionButton(
          tone: DesktopActionTone.primary,
          onPressed: editor.done,
          icon: const Icon(Icons.check, size: 17),
          label: Text(_done),
        ),
      ),
    ],
  );

  Widget _paintOptions(PaintEditorState editor) => Container(
    height: 56,
    color: Theme.of(context).colorScheme.surface,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final color in const [
          Color(0xFFEE505A),
          Color(0xFFFFB740),
          Color(0xFF3BC486),
          Color(0xFF409BEE),
          Colors.white,
          Colors.black,
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: InkWell(
              onTap: () => editor.setColor(color),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: editor.activeColor == color
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    width: editor.activeColor == color ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: 22),
        Text(t('Stroke', '线宽', 'Grosor'), style: const TextStyle(fontSize: 12)),
        SizedBox(
          width: 160,
          child: DesktopSlider(
            value: editor.strokeWidth.clamp(1, 24),
            min: 1,
            max: 24,
            divisions: 23,

            onChanged: editor.setStrokeWidth,
          ),
        ),
      ],
    ),
  );

  I18n _i18n() => I18n(
    cancel: _cancel,
    done: _done,
    undo: _undo,
    redo: _redo,
    remove: t('Remove', '删除', 'Eliminar'),
    doneLoadingMsg: t('Exporting image…', '正在导出图片…', 'Exportando imagen…'),
    textEditor: I18nTextEditor(
      inputHintText: t('Enter text', '输入文字', 'Escribe texto'),
      bottomNavigationBarText: t('Text', '文字', 'Texto'),
      back: _cancel,
      done: _done,
      textAlign: t('Align text', '文字对齐', 'Alinear texto'),
      fontScale: t('Text size', '字号', 'Tamaño'),
      backgroundMode: t('Background', '背景', 'Fondo'),
    ),
    paintEditor: I18nPaintEditor(
      done: _done,
      back: _cancel,
      cancel: _cancel,
      undo: _undo,
      redo: _redo,
      color: t('Color', '颜色', 'Color'),
      strokeWidth: t('Stroke', '线宽', 'Grosor'),
      fill: t('Fill', '填充', 'Relleno'),
      opacity: t('Opacity', '透明度', 'Opacidad'),
    ),
    various: I18nVarious(loadingDialogMsg: t('Loading…', '加载中…', 'Cargando…')),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
          if (!(_editorKey.currentState?.isSubEditorOpen ?? true)) {
            unawaited(_export(save: false));
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!(_editorKey.currentState?.isSubEditorOpen ?? true)) {
            unawaited(_export(save: true));
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            if (_error != null)
              Material(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [Expanded(child: Text(_error!))]),
                ),
              ),
            Expanded(
              child: ProImageEditor.memory(
                widget.bytes,
                key: _editorKey,
                callbacks: ProImageEditorCallbacks(
                  onCloseEditor: (_) => widget.onClose(),
                ),
                configs: ProImageEditorConfigs(
                  i18n: _i18n(),
                  imageGeneration: screenshotImageGeneration,
                  mainEditor: MainEditorConfigs(
                    enableSubEditorPage: true,
                    tools: const [SubEditorMode.paint, SubEditorMode.text],
                    style: MainEditorStyle(
                      background: colors.surfaceContainerLow,
                    ),
                    widgets: MainEditorWidgets(
                      appBar: (editor, stream) => ReactiveAppbar(
                        stream: stream,
                        appbarSize: const Size.fromHeight(58),
                        builder: (_) => _mainBar(editor),
                      ),
                      bottomBar: (editor, stream, key) => ReactiveWidget(
                        stream: stream,
                        builder: (_) => _tools(editor, key),
                      ),
                      closeWarningDialog: (_) async => true,
                    ),
                  ),
                  paintEditor: PaintEditorConfigs(
                    initialPaintMode: PaintMode.arrow,
                    tools: const [
                      PaintMode.arrow,
                      PaintMode.rect,
                      PaintMode.circle,
                      PaintMode.freeStyle,
                      PaintMode.pixelate,
                      PaintMode.blur,
                    ],
                    style: PaintEditorStyle(
                      background: colors.surfaceContainerLow,
                      initialStrokeWidth: 3,
                      initialColor: const Color(0xFFEE505A),
                    ),
                    widgets: PaintEditorWidgets(
                      colorPicker: (_, stream, _, _) => ReactiveWidget(
                        stream: stream,
                        builder: (_) => const SizedBox.shrink(),
                      ),
                      appBar: (editor, stream) => ReactiveAppbar(
                        stream: stream,
                        appbarSize: const Size.fromHeight(58),
                        builder: (_) => _paintBar(editor),
                      ),
                      bottomBar: (editor, stream) => ReactiveWidget(
                        stream: stream,
                        builder: (_) => Material(child: _paintOptions(editor)),
                      ),
                    ),
                  ),
                  textEditor: TextEditorConfigs(
                    style: TextEditorStyle(
                      background: colors.surfaceContainerLow,
                      appBarBackground: colors.surface,
                      appBarColor: colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The library defaults to JPEG and a 2000px limit. Screenshots need PNG and
/// original physical dimensions, regardless of editor window size or DPI.
const screenshotImageGeneration = ImageGenerationConfigs(
  outputFormat: OutputFormat.png,
  maxOutputSize: Size.infinite,
  cropToImageBounds: true,
  enableBackgroundGeneration: false,
);
