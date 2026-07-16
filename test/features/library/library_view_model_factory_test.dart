import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/ui/library_view_model_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop library models always include online update support', () {
    final model = createDesktopLibraryViewModel(InMemoryResourceStore());

    expect(model.updateFetcher, isA<HttpResourceUpdateFetcher>());
  });
}
