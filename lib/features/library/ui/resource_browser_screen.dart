import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/enabled_status_icon.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';

part 'resource_browser_cards.dart';
part 'resource_browser_filters.dart';

/// Resource browsing and quick actions inside the callout interface.
/// Full editing belongs to the separate resource manager window.
class ResourceBrowserScreen extends StatelessWidget {
  const ResourceBrowserScreen({
    required this.viewModel,
    this.resourceManagerLauncher,
    this.clipboardGateway,
    super.key,
  });

  final LibraryViewModel viewModel;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final ClipboardGateway? clipboardGateway;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.localized('Library', '资源库'),
                          style: const TextStyle(
                            color: PopupStyle.textPrimary,
                            fontSize: 17,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.localized(
                            'Curated content reusable by agents',
                            '整理后可被 Agent 复用的内容',
                          ),
                          style: const TextStyle(
                            color: PopupStyle.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('resource-manager-open'),
                    onPressed: resourceManagerLauncher == null
                        ? null
                        : () => resourceManagerLauncher!.show(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(96, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: PopupStyle.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: const PopupSymbolIcon(
                      'manage',
                      size: 17,
                      color: Colors.white,
                    ),
                    label: Text(
                      context.localized('Manage', '资源管理'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                height: 36,
                child: TextField(
                  key: const Key('resource-search'),
                  onChanged: viewModel.setQuery,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: context.localized(
                      'Search prompts, skills, MCP, knowledge',
                      '搜索提示词、Skills、MCP、知识库',
                    ),
                    hintStyle: const TextStyle(
                      color: PopupStyle.textSecondary,
                      fontSize: 12,
                    ),
                    prefixIcon: const SizedBox(
                      width: 40,
                      child: Center(
                        child: PopupSymbolIcon(
                          'search',
                          color: PopupStyle.textSecondary,
                          size: 19,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints.tightFor(
                      width: 40,
                    ),
                    fillColor: PopupStyle.surface,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            _TypeFilters(viewModel: viewModel),
            const SizedBox(height: 9),
            _GroupFilters(viewModel: viewModel),
            const SizedBox(height: 11),
            Expanded(
              child: _ResourceCards(
                viewModel: viewModel,
                clipboardGateway: clipboardGateway,
                launcher: resourceManagerLauncher,
              ),
            ),
          ],
        );
      },
    );
  }
}
