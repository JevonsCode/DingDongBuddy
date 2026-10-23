import 'package:dingdong/features/plugins/domain/plugin_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'component versions compare numerically and do not offer downgrades',
    () {
      final source = PluginSource.screenshot;
      expect(
        source.compareMetadata({
          'latest': {'version': '14.16.0'},
        }),
        PluginUpstreamState.current,
      );
      expect(
        source.compareMetadata({
          'latest': {'version': '14.9.0'},
        }),
        PluginUpstreamState.current,
      );
      expect(
        source.compareMetadata({
          'latest': {'version': '15.0.0'},
        }),
        PluginUpstreamState.changed,
      );
      expect(
        () => source.compareMetadata({'latest': {}}),
        throwsFormatException,
      );
      expect(
        () => source.compareMetadata({
          'latest': {'version': '15.0.0-beta'},
        }),
        throwsFormatException,
      );
    },
  );

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
