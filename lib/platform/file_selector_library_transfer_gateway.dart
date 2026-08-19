import 'dart:convert';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';

/// Flutter-official desktop file dialogs for resource import and export.
final class FileSelectorLibraryTransferGateway
    implements LibraryTransferGateway {
  FileSelectorLibraryTransferGateway([this._localizations]);

  final DingDongLocalizations Function()? _localizations;

  DingDongLocalizations get _strings =>
      _localizations?.call() ?? lookupDingDongLocalizations(const Locale('en'));

  XTypeGroup _json(DingDongLocalizations strings) => XTypeGroup(
    label: strings.jsonFiles,
    extensions: const <String>['json'],
    mimeTypes: const <String>['application/json'],
  );

  @override
  Future<String?> chooseImportDirectory() {
    return getDirectoryPath(confirmButtonText: _strings.importThisFolder);
  }

  @override
  Future<String?> chooseImportJson() async {
    final DingDongLocalizations strings = _strings;
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_json(strings)],
      confirmButtonText: strings.importAction,
    );
    return file?.readAsString();
  }

  @override
  Future<String?> saveExport({required String contents}) async {
    final DingDongLocalizations strings = _strings;
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: 'dingdong-library.json',
      acceptedTypeGroups: <XTypeGroup>[_json(strings)],
      confirmButtonText: strings.exportAction,
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
