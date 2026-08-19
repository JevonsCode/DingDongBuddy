import 'dart:io';

import 'package:dingdong/features/settings/data/io_system_data_location_gateway.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('opens the DingDong-owned image cache on macOS', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'dingdong-location-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    String? executable;
    List<String>? arguments;
    final IoSystemDataLocationGateway gateway = IoSystemDataLocationGateway(
      root,
      operatingSystem: () => 'macos',
      launcher: (String value, List<String> values) async {
        executable = value;
        arguments = values;
      },
    );

    await gateway.open(SystemDataCategory.clipboardImages);

    final String expected = path.join(root.path, 'Clipboard Images');
    expect(Directory(expected).existsSync(), isTrue);
    expect(executable, 'open');
    expect(arguments, <String>[expected]);
  });

  test('text and file records open the app data folder', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'dingdong-location-root-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    final List<List<String>> launches = <List<String>>[];
    final IoSystemDataLocationGateway gateway = IoSystemDataLocationGateway(
      root,
      operatingSystem: () => 'windows',
      launcher: (String executable, List<String> arguments) async {
        launches.add(<String>[executable, ...arguments]);
      },
    );

    await gateway.open(SystemDataCategory.clipboardText);
    await gateway.open(SystemDataCategory.clipboardFiles);

    expect(launches, <List<String>>[
      <String>['explorer.exe', root.path],
      <String>['explorer.exe', root.path],
    ]);
  });
}
