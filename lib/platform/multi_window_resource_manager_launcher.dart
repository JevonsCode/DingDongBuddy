import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';

const String resourceManagerWindowKind = 'resource-manager';

/// Cross-platform launcher for DingDong's dedicated resource manager window.
final class MultiWindowResourceManagerLauncher
    implements ResourceManagerLauncher, ClipboardCategoryManagerLauncher {
  const MultiWindowResourceManagerLauncher({required this.parentWindowId});

  final String parentWindowId;

  /// Reloads clipboard history in an already-open resource manager.
  Future<void> refreshClipboard() async {
    try {
      final List<WindowController> windows = await WindowController.getAll();
      for (final WindowController controller in windows) {
        final Map<String, Object?> arguments = _decode(controller.arguments);
        if (arguments['kind'] == resourceManagerWindowKind) {
          await controller.invokeMethod<void>('clipboard_changed');
          return;
        }
      }
    } on Object {
      // The resource manager may be closing while a clipboard capture lands.
    }
  }

  @override
  Future<void> show({
    String? editingResourceId,
    ResourceManagerCreateRequest? createRequest,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  }) => _show(
    editingResourceId: editingResourceId,
    createRequest: createRequest,
    destination: destination,
  );

  @override
  Future<void> showClipboardCategories() => _show(
    destination: ResourceManagerDestination.clipboard,
    openClipboardCategories: true,
  );

  Future<void> _show({
    String? editingResourceId,
    ResourceManagerCreateRequest? createRequest,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
    bool openClipboardCategories = false,
  }) async {
    final ResourceManagerDestination resolvedDestination =
        editingResourceId == null && createRequest == null
        ? destination
        : ResourceManagerDestination.resources;
    final List<WindowController> windows = await WindowController.getAll();
    for (final WindowController controller in windows) {
      final Map<String, Object?> arguments = _decode(controller.arguments);
      if (arguments['kind'] == resourceManagerWindowKind) {
        await controller.show();
        await controller.invokeMethod<void>(
          'window_focus',
          resolvedDestination.name,
        );
        if (openClipboardCategories) {
          await controller.invokeMethod<void>(manageClipboardCategoriesMethod);
        }
        if (editingResourceId != null) {
          await controller.invokeMethod<void>('edit_resource', <String, String>{
            'id': editingResourceId,
          });
        }
        if (createRequest != null) {
          await controller.invokeMethod<void>(
            'create_resource',
            createRequest.toJson(),
          );
        }
        return;
      }
    }

    final Map<String, Object?> arguments = <String, Object?>{
      'kind': resourceManagerWindowKind,
      'parentWindowId': parentWindowId,
      'destination': resolvedDestination.name,
      if (openClipboardCategories) 'openClipboardCategories': true,
    };
    if (editingResourceId != null) {
      arguments['editingResourceId'] = editingResourceId;
    }
    if (createRequest != null) {
      arguments['createRequest'] = createRequest.toJson();
    }
    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(arguments),
      ),
    );
  }
}

Map<String, Object?> decodeDesktopWindowArguments(String arguments) =>
    _decode(arguments);

Map<String, Object?> _decode(String arguments) {
  if (arguments.trim().isEmpty) {
    return const <String, Object?>{};
  }
  final Object? value = jsonDecode(arguments);
  return value is Map<String, Object?> ? value : const <String, Object?>{};
}
