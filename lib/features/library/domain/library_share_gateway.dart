/// Marker carried by the desktop file transfer protocol for resource bundles.
const libraryBundleTransferItemId = 'dingdong.resource-bundle.v1';
const libraryBundleTransferName = 'dingdong-resources.json';

typedef LibraryShareTarget = ({String id, String name});
typedef ReceivedLibraryBundle = ({
  String id,
  String sender,
  DateTime receivedAt,
});

abstract interface class LibraryShareGateway {
  Future<List<LibraryShareTarget>> targets();
  Future<String> send(String targetId, String contents);
  Future<List<ReceivedLibraryBundle>> received();
  Future<String> read(String id);
  Future<void> remove(String id);
}
