import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Validated clipboard content and the QR data generated from it.
final class ClipboardQrData {
  const ClipboardQrData({required this.payload, required this.qrCode});

  final String payload;
  final QrCode qrCode;
}

/// Returns QR-ready content only when it can be rendered successfully.
///
/// File and image records contain local paths rather than portable file data,
/// so they intentionally do not expose QR sharing. Sensitive text is treated
/// the same as any other text because displaying the code is an explicit user
/// action.
ClipboardQrData? clipboardQrData(ClipboardRecord record) {
  if (record.kind == ClipboardKind.file ||
      record.kind == ClipboardKind.image ||
      record.content.trim().isEmpty) {
    return null;
  }

  final QrCode? qrCode = QrValidator.validate(
    data: record.content,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
  ).qrCode;
  if (qrCode == null) {
    return null;
  }
  try {
    // qr_flutter 4.1 validates the chosen version before its data cache is
    // materialized. Building the portable image here guarantees the payload
    // really fits before the UI advertises the action.
    QrImage(qrCode);
    return ClipboardQrData(payload: record.content, qrCode: qrCode);
  } on InputTooLongException {
    return null;
  } on Exception {
    return null;
  }
}
