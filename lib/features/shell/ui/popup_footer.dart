import 'dart:io';

import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:flutter/material.dart';

/// Persistent local-service status shown at the bottom of the callout.
class PopupFooter extends StatelessWidget {
  const PopupFooter({
    required this.apiPort,
    required this.globalHotKey,
    super.key,
  });

  final int apiPort;
  final GlobalHotKey globalHotKey;

  @override
  Widget build(BuildContext context) {
    final TargetPlatform shortcutPlatform = Platform.isWindows
        ? TargetPlatform.windows
        : TargetPlatform.macOS;
    final String shortcut = globalHotKey.label(shortcutPlatform);
    return Container(
      height: 39,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: PopupStyle.background.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: PopupStyle.border)),
      ),
      child: Text(
        'API 正在监听 127.0.0.1:$apiPort   ·   $shortcut 就绪',
        maxLines: 1,
        style: const TextStyle(
          color: PopupStyle.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
