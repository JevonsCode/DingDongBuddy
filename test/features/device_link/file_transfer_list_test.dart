import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/domain/file_transfer.dart';
import 'package:dingdong/features/device_link/ui/file_transfer_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'progress remains readable at narrow widths and controls the correct transfer',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(380, 650);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['TRANSFER_UI_PREVIEW'] == '1') {
        await tester.runAsync(() async {
          for (final name in ['.AppleSystemUIFont', 'Roboto', 'Ahem']) {
            final font = FontLoader(name)
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    File(
                      '/System/Library/Fonts/STHeiti Light.ttc',
                    ).readAsBytesSync(),
                  ),
                ),
              );
            await font.load();
          }
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      final model = _Transfers();
      addTearDown(model.dispose);
      for (final locale in [
        const Locale('zh'),
        const Locale('en'),
        const Locale('es'),
      ]) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('preview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.desktopPanelLight(),
              locale: locale,
              supportedLocales: DingDongLocalizations.supportedLocales,
              localizationsDelegates:
                  DingDongLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('DingDong · UI test fixture'),
                        const SizedBox(height: 24),
                        FileTransferList(controller: model),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('42%'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
        if (locale.languageCode == 'zh') {
          await tester.tap(find.text('暂停'));
          expect(model.lastControl, 'sending:pause');
          await tester.tap(find.text('继续'));
          expect(model.lastControl, 'waiting:resume');
          if (Platform.environment['TRANSFER_UI_PREVIEW'] == '1') {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('preview')),
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '/tmp/jvs-a-transfer-desktop.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    },
  );
}

class _Transfers extends ChangeNotifier
    implements DeviceLinkManagement, FileTransferManagement {
  String? lastControl;
  @override
  List<LinkedDevice> get devices => [];
  @override
  final List<FileTransfer> fileTransfers = [
    FileTransfer(
      id: 'sending',
      deviceId: '我的手机',
      name: '项目素材与设计文档（测试样本）.zip',
      size: 100000000,
      bytes: 42000000,
      sending: true,
      status: 'transferring',
    )..bytesPerSecond = 2500000,
    FileTransfer(
      id: 'waiting',
      deviceId: '我的手机',
      name: '演示视频（测试样本）.mp4',
      size: 200000000,
      bytes: 70000000,
      sending: false,
      status: 'waiting',
      detail: 'waiting_lan',
    ),
    FileTransfer(
      id: 'complete',
      deviceId: '我的手机',
      name: '会议资料（测试样本）.pdf',
      size: 3000000,
      bytes: 3000000,
      sending: true,
      status: 'completed',
    ),
  ];
  @override
  Future<void> controlFileTransfer(
    String id,
    String deviceId,
    String action,
  ) async {
    lastControl = '$id:$action';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
