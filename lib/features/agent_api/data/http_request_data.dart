/// Framework-independent representation of one loopback HTTP request.
final class HttpRequestData {
  const HttpRequestData({
    required this.method,
    required this.uri,
    this.body = '',
  });

  final String method;
  final String uri;
  final String body;

  Uri get parsedUri => Uri.parse(uri);
}
