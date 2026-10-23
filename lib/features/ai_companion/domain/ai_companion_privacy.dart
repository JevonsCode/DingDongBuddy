/// Conservative checks for routing input and structured provider responses.
/// Raw resource bodies and clipboard contents are not routing inputs.
final class AiCompanionPrivacy {
  const AiCompanionPrivacy();

  bool isSafeText(String text, {String? providerKey}) {
    if (providerKey != null &&
        providerKey.isNotEmpty &&
        text.contains(providerKey)) {
      return false;
    }
    if (text.contains('\u0000') || text.contains('\u001b')) return false;
    return !_blocked.any((pattern) => pattern.hasMatch(text));
  }

  /// Routing accepts explicit task references, but fails closed on credentials.
  bool isSafeRoutingInput(String text, {String? providerKey}) =>
      !text.contains('\u0000') &&
      !text.contains('\u001b') &&
      !(providerKey != null &&
          providerKey.isNotEmpty &&
          text.contains(providerKey)) &&
      !_routingCredential.hasMatch(text) &&
      !_blocked.take(8).any((pattern) => pattern.hasMatch(text));

  static final RegExp _routingCredential = RegExp(
    r'''(?:api[ _-]?key|access[ _-]?key|client[ _-]?secret|password|passwd|secret|token|authorization|cookie|密码|密钥|令牌)\s*["']?\s*[:=：]\s*["']?\s*\S+''',
    caseSensitive: false,
  );

  static final List<RegExp> _blocked = <RegExp>[
    RegExp(
      r'(?:api[ _-]?key|access[ _-]?key|client[ _-]?secret|password|passwd|pwd|secret|token|authorization|cookie|密码|口令|密钥|令牌|凭据)\s*[=:：]\s*\S+',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:password|passwd|secret|api[ _-]?key|access[ _-]?token|密码|口令|密钥|令牌)\s*(?:is\s+|为|是)\s*\S+',
      caseSensitive: false,
    ),
    RegExp(r'\b(?:bearer|basic)\s+[A-Za-z0-9+/_.=-]+', caseSensitive: false),
    RegExp(r'-----BEGIN [A-Z ]*(?:PRIVATE KEY|CERTIFICATE)-----'),
    RegExp(
      r'\b(?:sk-(?:proj-)?|gh[pousr]_|github_pat_|xox[baprs]-|AKIA|ASIA|AIza)[A-Za-z0-9_-]{8,}',
    ),
    RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    // Long opaque strings include unlabelled keys, encoded files and hashes.
    RegExp(r'[A-Za-z0-9_+/=-]{32,}'),
    RegExp(
      r'\b(?=[A-Za-z0-9!@#$%^&*_-]{12,}\b)(?=[A-Za-z0-9!@#$%^&*_-]*[a-z])(?=[A-Za-z0-9!@#$%^&*_-]*[A-Z])(?=[A-Za-z0-9!@#$%^&*_-]*[0-9])[A-Za-z0-9!@#$%^&*_-]+',
    ),
    // Analysis output must not introduce file uploads or private references.
    RegExp(
      r'(?:[A-Za-z]:[\\/]|\\\\[^\s]+\\|(?:^|\s)/(?:[^\s/]+/)+[^\s]*|(?:file|data):|https?://)',
      caseSensitive: false,
    ),
    RegExp(r'(?:^|\s)(?:~/|\.{1,2}[\\/])|!\['),
    RegExp(
      r'[^\s]+\.(?:png|jpe?g|gif|webp|heic|svg|pdf|docx?|xlsx?|pptx?|zip|7z|tar|gz|pem|key|env|txt|csv|json|ya?ml|sqlite|db)(?:\b|$)',
      caseSensitive: false,
    ),
  ];
}
