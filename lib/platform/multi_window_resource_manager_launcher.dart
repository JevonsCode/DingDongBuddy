import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';

const String resourceManagerWindowKind = 'resource-manager';

/// Cross-platform launcher for DingDong's dedicated resource manager window.
final class MultiWindowResourceManagerLauncher
    implements ResourceManagerLauncher {
  const MultiWindowResourceManagerLauncher({required this.parentWindowId});

  final String parentWindowId;

  @override
  Future<void> show({
    String? editingResourceId,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  }) async {
    final ResourceManagerDestination resolvedDestination =
        editingResourceId == null
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
        if (editingResourceId != null) {
          await controller.invokeMethod<void>('edit_resource', <String, String>{
            'id': editingResourceId,
          });
        }
        return;
      }
    }

    final Map<String, Object?> arguments = <String, Object?>{
      'kind': resourceManagerWindowKind,
      'parentWindowId': parentWindowId,
      'destination': resolvedDestination.name,
    };
    if (editingResourceId != null) {
      arguments['editingResourceId'] = editingResourceId;
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
