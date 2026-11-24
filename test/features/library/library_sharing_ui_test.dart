import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_share_gateway.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection actions export and send only the checked resource', (
    tester,
  ) async {
    final model = LibraryViewModel(
      InMemoryResourceStore([_prompt('selected'), _prompt('unchecked')]),
    );
    await model.load();
    final files = _Files();
    final sharing = _Sharing();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryScreen(
            viewModel: model,
            transferGateway: files,
            shareGateway: sharing,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('resource-select-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-export-selection')));
    await tester.pumpAndSettle();
    expect(LibraryBundle.preview(files.saved!).single.id, 'selected');

    await tester.tap(find.byKey(const Key('library-send-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-share-target-mac')));
    await tester.pumpAndSettle();
    expect(sharing.target, 'mac');
    expect(LibraryBundle.preview(sharing.sent!).single.id, 'selected');
    expect(tester.takeException(), isNull);
  });

  testWidgets('received bundles install only checked items after review', (
    tester,
  ) async {
    final localStore = InMemoryResourceStore();
    final updates = _Updates();
    final model = LibraryViewModel(localStore, updateFetcher: updates);
    await model.load();
    final sharing = _Sharing()
      ..incoming = LibraryBundle.encode([
        _prompt('install-first', url: 'https://example.test/first'),
        _prompt('leave-unchecked', url: 'https://example.test/second'),
      ], generatedAt: DateTime.utc(2026));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryScreen(viewModel: model, shareGateway: sharing),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-inbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-open-bundle-incoming')));
    await tester.pumpAndSettle();

    expect(find.text('Install selected (0)'), findsOneWidget);
    expect(find.text('https://example.test/second'), findsOneWidget);
    expect(await localStore.load(), isEmpty);
    expect(updates.fetched, isEmpty);
    await tester.tap(
      find.byKey(const Key('library-install-select-install-first')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-install-selection')));
    await tester.pumpAndSettle();

    expect(updates.fetched, [Uri.parse('https://example.test/first')]);
    expect((await localStore.load()).single.id, 'install-first');
    expect(tester.takeException(), isNull);
  });
}

Resource _prompt(String id, {String? url}) => Resource(
  id: id,
  type: ResourceType.prompt,
  title: id,
  content: 'Prompt content for $id',
  updateUrl: url,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final class _Sharing implements LibraryShareGateway {
  String? sent, target, incoming;

  @override
  Future<List<LibraryShareTarget>> targets() async => [
    (id: 'mac', name: 'Office Mac'),
  ];

  @override
  Future<String> send(String targetId, String contents) async {
    target = targetId;
    sent = contents;
    return 'completed';
  }

  @override
  Future<List<ReceivedLibraryBundle>> received() async => [
    if (incoming != null)
      (id: 'incoming', sender: 'Office Mac', receivedAt: DateTime.utc(2026)),
  ];

  @override
  Future<String> read(String id) async => incoming!;

  @override
  Future<void> remove(String id) async {
    incoming = null;
  }
}

final class _Files implements LibraryTransferGateway {
  String? saved;

  @override
  Future<String?> chooseImportJson() async => null;

  @override
  Future<String?> chooseImportDirectory() async => null;

  @override
  Future<String?> saveExport({required String contents}) async {
    saved = contents;
    return null;
  }
}

final class _Updates implements ResourceUpdateFetcher {
  final fetched = <Uri>[];

  @override
  Future<String> fetch(Uri uri) async {
    fetched.add(uri);
    return 'Fetched content for $uri';
  }
}
