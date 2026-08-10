import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:flutter/material.dart';

/// Persistent local-service status shown at the bottom of the callout.
class PopupFooter extends StatelessWidget {
  const PopupFooter({
    required this.agentBaseUri,
    required this.globalHotKey,
    super.key,
  });

  final Uri? agentBaseUri;
  final GlobalHotKey globalHotKey;

  @override
  Widget build(BuildContext context) {
    final TargetPlatform shortcutPlatform = Platform.isWindows
        ? TargetPlatform.windows
        : TargetPlatform.macOS;
    final String shortcut = globalHotKey.label(shortcutPlatform);
    final Uri? endpoint = agentBaseUri;
    final String apiStatus = endpoint == null
        ? context.localized('API status unverified', 'API 状态待确认')
        : context.localized(
            'API listening on ${endpoint.host}:${endpoint.port}',
            'API 正在监听 ${endpoint.host}:${endpoint.port}',
          );
    final String shortcutStatus = context.localized(
      '$shortcut ready',
      '$shortcut 就绪',
    );
    return Container(
      height: 39,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: PopupStyle.of(context).background.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: PopupStyle.of(context).border)),
      ),
      child: Text(
        '$apiStatus   ·   $shortcutStatus',
        maxLines: 1,
        style: TextStyle(
          color: PopupStyle.of(context).textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
