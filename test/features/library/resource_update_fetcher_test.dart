import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GitHub blob links resolve to raw file content', () {
    final Uri result = normalizeResourceUpdateUri(
      Uri.parse('https://github.com/acme/prompts/blob/main/review.md'),
    );

    expect(
      result,
      Uri.parse(
        'https://raw.githubusercontent.com/acme/prompts/main/review.md',
      ),
    );
  });

  test('GitHub repository and folder links are rejected', () {
    expect(
      () => normalizeResourceUpdateUri(
        Uri.parse('https://github.com/acme/prompts'),
      ),
      throwsFormatException,
    );
  });
}
