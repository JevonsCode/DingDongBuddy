import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/library/data/file_library_inbox.dart';
import 'package:dingdong/features/library/domain/library_share_gateway.dart';

const libraryShareTargetsMethod = 'library_share_targets';
const librarySendBundleMethod = 'library_send_bundle';
const libraryInboxChangedMethod = 'library_inbox_changed';

final class MultiWindowLibraryShareGateway implements LibraryShareGateway {
  const MultiWindowLibraryShareGateway(this.host, this.inbox);

  final WindowController host;
  final FileLibraryInbox inbox;

  @override
  Future<List<LibraryShareTarget>> targets() async {
    final response = await host.invokeMethod<List<Object?>>(
      libraryShareTargetsMethod,
    );
    return [
      for (final item in response ?? const [])
        if (item case {'id': final String id, 'name': final String name})
          (id: id, name: name),
    ];
  }

  @override
  Future<String> send(String targetId, String contents) async {
    return await host.invokeMethod<String>(librarySendBundleMethod, {
          'id': targetId,
          'contents': contents,
        }) ??
        'failed';
  }

  @override
  Future<List<ReceivedLibraryBundle>> received() => inbox.list();

  @override
  Future<String> read(String id) => inbox.read(id);

  @override
  Future<void> remove(String id) => inbox.remove(id);
}
