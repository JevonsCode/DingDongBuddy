/// Returns [value] without surrounding whitespace, or `null` when nothing
/// remains.
String? trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
