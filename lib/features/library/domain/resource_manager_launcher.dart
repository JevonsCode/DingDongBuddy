import 'package:dingdong/core/models/resource.dart';

enum ResourceManagerDestination {
  resources,
  clipboard,
  recentAgents,
  agentAdapters,
  issues;

  static ResourceManagerDestination parse(Object? value) {
    return values.firstWhere(
      (ResourceManagerDestination destination) => destination.name == value,
      orElse: () => ResourceManagerDestination.resources,
    );
  }
}

/// Values needed to open the existing resource editor in creation mode.
///
/// This is intentionally a draft request rather than a [Resource]: opening a
/// clipboard item for review must not persist anything before the user saves it.
final class ResourceManagerCreateRequest {
  const ResourceManagerCreateRequest({
    required this.content,
    this.type = ResourceType.prompt,
    this.title,
  });

  final ResourceType type;
  final String? title;
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    if (title != null && title!.trim().isNotEmpty) 'title': title,
    'content': content,
  };

  static ResourceManagerCreateRequest? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final Object? content = value['content'];
    if (content is! String) {
      return null;
    }
    final String? typeName = value['type'] as String?;
    final ResourceType type = ResourceType.values.firstWhere(
      (ResourceType candidate) => candidate.name == typeName,
      orElse: () => ResourceType.prompt,
    );
    final Object? titleValue = value['title'];
    return ResourceManagerCreateRequest(
      type: type,
      title: titleValue is String && titleValue.trim().isNotEmpty
          ? titleValue
          : null,
      content: content,
    );
  }
}

/// Multi-window signal emitted after the resource manager commits a library
/// change to shared storage.
const String resourceLibraryChangedMethod = 'resource_library_changed';
const String manageClipboardCategoriesMethod = 'manage_clipboard_categories';

/// Opens the full resource management experience in its own desktop window.
abstract interface class ResourceManagerLauncher {
  Future<void> show({
    String? editingResourceId,
    ResourceManagerCreateRequest? createRequest,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  });
}

/// Optional deep-link capability for opening clipboard category management.
///
/// Callout launchers can wrap a regular [ResourceManagerLauncher] while still
/// preserving this richer route. Launchers without the capability gracefully
/// fall back to the clipboard workspace.
abstract interface class ClipboardCategoryManagerLauncher {
  Future<void> showClipboardCategories();
}

Future<void> showClipboardCategoryManager(
  ResourceManagerLauncher launcher,
) async {
  if (launcher case final ClipboardCategoryManagerLauncher categoryLauncher) {
    await categoryLauncher.showClipboardCategories();
    return;
  }
  await launcher.show(destination: ResourceManagerDestination.clipboard);
}
