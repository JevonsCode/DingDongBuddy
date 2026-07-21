import 'dart:io';

import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file store preserves group order across instances', () {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-group-order-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final File file = File('${directory.path}/clipboard-group-order.json');

    FileClipboardGroupOrderStore(
      file,
    ).save(const <String>['PageID', 'Query', 'iDev ID']);

    expect(FileClipboardGroupOrderStore(file).load(), <String>[
      'PageID',
      'Query',
      'iDev ID',
    ]);
  });

  test('malformed and duplicate values fail safely', () {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-group-order-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final File file = File('${directory.path}/clipboard-group-order.json');
    final FileClipboardGroupOrderStore store = FileClipboardGroupOrderStore(
      file,
    );

    expect(store.load(), isEmpty);
    file.writeAsStringSync('{"version":1,"groups":[" Query ","query",7]}');
    expect(store.load(), <String>['Query']);
    file.writeAsStringSync('{"legacy":true}');
    expect(store.load(), isEmpty);
  });
}
