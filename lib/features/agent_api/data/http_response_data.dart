/// Framework-independent loopback response used by contract tests and server IO.
final class HttpResponseData {
  const HttpResponseData({required this.statusCode, required this.json});

  final int statusCode;
  final Map<String, Object?> json;
}
