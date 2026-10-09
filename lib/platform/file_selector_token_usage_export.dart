import 'dart:convert';

import 'package:file_selector/file_selector.dart';

/// Uses the same native save dialog as library export; cancellation is silent.
Future<bool> saveTokenUsageCsv({
  required String contents,
  required String suggestedName,
  required String confirmButtonText,
  required String fileTypeLabel,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    confirmButtonText: confirmButtonText,
    acceptedTypeGroups: [
      XTypeGroup(
        label: fileTypeLabel,
        extensions: const ['csv'],
        mimeTypes: const ['text/csv'],
      ),
    ],
  );
  if (location == null) return false;
  await XFile.fromData(
    utf8.encode(contents),
    mimeType: 'text/csv',
    name: suggestedName,
  ).saveTo(location.path);
  return true;
}
