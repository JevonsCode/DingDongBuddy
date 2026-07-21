import 'package:dingdong/app/app_data_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resource library keeps the native macOS path and a Windows app-data path', () {
    expect(
      AppDataPaths.forPlatform(
        operatingSystem: 'macos',
        homeDirectory: '/Users/example',
      ).resourceLibraryFile.path,
      '/Users/example/Library/Application Support/DingDong/resource-library.json',
    );
    expect(
      AppDataPaths.forPlatform(
        operatingSystem: 'windows',
        homeDirectory: r'C:\Users\example',
        appDataDirectory: r'C:\Users\example\AppData\Roaming',
      ).resourceLibraryFile.path,
      r'C:\Users\example\AppData\Roaming\DingDong\resource-library.json',
    );
    expect(
      AppDataPaths.forPlatform(
        operatingSystem: 'macos',
        homeDirectory: '/Users/example',
      ).triggerGroupsFile.path,
      '/Users/example/Library/Application Support/DingDong/trigger-groups.json',
    );
    expect(
      AppDataPaths.forPlatform(
        operatingSystem: 'macos',
        homeDirectory: '/Users/example',
      ).clipboardCategoryRulesFile.path,
      '/Users/example/Library/Application Support/DingDong/clipboard-category-rules.json',
    );
    expect(
      AppDataPaths.forPlatform(
        operatingSystem: 'macos',
        homeDirectory: '/Users/example',
      ).clipboardGroupOrderFile.path,
      '/Users/example/Library/Application Support/DingDong/clipboard-group-order.json',
    );
    expect(
      AppDataPaths.forPlatform(
        operatingSystem: 'macos',
        homeDirectory: '/Users/example',
      ).agentActivityFile.path,
      '/Users/example/Library/Application Support/DingDong/agent-activity.json',
    );
  });
}
