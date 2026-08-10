import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_choice_chip.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/enabled_status_icon.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/library/domain/resource_card_presentation.dart';
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
                    child: Text(
                      context.localized(
                        'Curated content reusable by agents',
                        '整理后可被 Agent 复用的内容',
                      ),
                      key: const Key('resource-library-context'),
                      style: TextStyle(
                        color: PopupStyle.of(context).textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DesktopActionButton(
                    key: const Key('resource-manager-open'),
                    onPressed: resourceManagerLauncher == null
                        ? null
                        : () => resourceManagerLauncher!.show(),
                    icon: PopupSymbolIcon(
                      'manage',
                      size: 17,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: context.localized('Manage', '资源管理'),
                    tone: DesktopActionTone.primary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: DesktopSearchField(
                key: const Key('resource-search'),
                onChanged: viewModel.setQuery,
                height: 38,
                hintText: context.localized(
                  'Search prompts, skills, and MCP',
                  '搜索提示词、Skills 和 MCP',
                ),
                clearTooltip: context.localized('Clear search', '清除搜索'),
                style: TextStyle(fontSize: 12),
                hintStyle: TextStyle(
                  color: PopupStyle.of(context).textSecondary,
                  fontSize: 12,
                ),
                searchIcon: PopupSymbolIcon(
                  'search',
                  color: PopupStyle.of(context).textSecondary,
                  size: 19,
                ),
                backgroundColor: PopupStyle.of(context).surface,
                borderColor: PopupStyle.of(context).border,
                focusBorderColor: PopupStyle.of(context).accent,
                foregroundColor: PopupStyle.of(context).textSecondary,
                borderRadius: 8,
              ),
            ),
            _TypeFilters(viewModel: viewModel),
            if (viewModel.groups.isNotEmpty) ...<Widget>[
              const SizedBox(height: 9),
              _GroupFilters(viewModel: viewModel),
            ],
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
