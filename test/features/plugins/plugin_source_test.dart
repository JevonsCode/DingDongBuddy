import 'package:dingdong/features/plugins/domain/plugin_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native changes are signalled without claiming a compatible release',
    () {
      final source = PluginSource.selection;
      expect(
        source.compareMetadata({'sha': source.version}),
        PluginUpstreamState.current,
      );
      expect(
        source.compareMetadata({
          'sha': '0000000000000000000000000000000000000000',
        }),
        PluginUpstreamState.changed,
      );
      expect(
        () => source.compareMetadata({'message': 'rate limited'}),
        throwsFormatException,
      );
      expect(
        () => source.compareMetadata({'sha': 'bad'}),
        throwsFormatException,
      );
    },
  );
}
