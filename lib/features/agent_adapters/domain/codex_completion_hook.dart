enum CodexCompletionHookReview {
  notChecked,
  unavailable,
  missing,
  mismatched,
  untrusted,
  modified,
  trusted,
  managed,
  failed,
}

final class CodexCompletionHookStatus {
  const CodexCompletionHookStatus({
    required this.review,
    required this.enabled,
    this.key,
    this.command,
    this.currentHash,
    this.detail,
  });

  const CodexCompletionHookStatus.notChecked()
    : review = CodexCompletionHookReview.notChecked,
      enabled = false,
      key = null,
      command = null,
      currentHash = null,
      detail = null;

  final CodexCompletionHookReview review;
  final bool enabled;
  final String? key;
  final String? command;
  final String? currentHash;
  final String? detail;

  bool get isOperational =>
      enabled &&
      (review == CodexCompletionHookReview.trusted ||
          review == CodexCompletionHookReview.managed);

  bool get canRepair =>
      key != null &&
      currentHash != null &&
      (review == CodexCompletionHookReview.untrusted ||
          review == CodexCompletionHookReview.modified ||
          review == CodexCompletionHookReview.trusted) &&
      !isOperational;
}

abstract interface class CodexCompletionHookGateway {
  Future<CodexCompletionHookStatus> inspect();

  Future<CodexCompletionHookStatus> repair({
    required String expectedKey,
    required String expectedHash,
  });
}
