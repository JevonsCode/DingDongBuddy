/// Native file-dialog boundary for directory imports and JSON exports.
abstract interface class LibraryTransferGateway {
  Future<String?> chooseImportDirectory();

  Future<String?> saveExport({required String contents});
}
