/// Framework-independent loopback response used by contract tests and server IO.
final class HttpResponseData {
  const HttpResponseData({required this.statusCode, required this.json});

  /// A `200` response carrying DingDong's standard `ok` envelope.
  HttpResponseData.ok(Map<String, Object?> values)
    : statusCode = 200,
      json = <String, Object?>{
        'status': 'ok',
        'service': 'DingDong',
        ...values,
      };

  /// An error response with DingDong's standard `{status, message}` body.
  HttpResponseData.error(this.statusCode, String message)
    : json = <String, Object?>{'status': 'error', 'message': message};

  HttpResponseData.badRequest(String message) : this.error(400, message);

  HttpResponseData.notFound(String message) : this.error(404, message);

  final int statusCode;
  final Map<String, Object?> json;
}

/// Parses the boolean spellings accepted by query parameters.
///
/// Returns `null` for a missing or unrecognized value so callers can reject
/// malformed input instead of silently treating it as `false`.
bool? parseQueryBool(String? value) => switch (value?.toLowerCase()) {
  'true' || '1' || 'yes' || 'on' => true,
  'false' || '0' || 'no' || 'off' => false,
  _ => null,
};
