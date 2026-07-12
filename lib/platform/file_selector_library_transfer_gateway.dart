import 'dart:convert';

import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:file_selector/file_selector.dart';

/// Flutter-official desktop file dialogs for resource import and export.
final class FileSelectorLibraryTransferGateway
    implements LibraryTransferGateway {
  static const XTypeGroup _json = XTypeGroup(
    label: 'JSON',
    extensions: <String>['json'],
    mimeTypes: <String>['application/json'],
  );

  @override
  Future<String?> chooseImportDirectory() {
    return getDirectoryPath(confirmButtonText: 'Import this folder');
  }

  @override
  Future<String?> chooseImportJson() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_json],
      confirmButtonText: 'Import',
    );
    return file?.readAsString();
  }

  @override
  Future<String?> saveExport({required String contents}) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: 'dingdong-library.json',
      acceptedTypeGroups: const <XTypeGroup>[_json],
      confirmButtonText: 'Export',
    );
    if (location == null) {
      return null;
    }
    final XFile file = XFile.fromData(
      utf8.encode(contents),
      mimeType: 'application/json',
      name: 'dingdong-library.json',
    );
    await file.saveTo(location.path);
    return location.path;
  }
}
