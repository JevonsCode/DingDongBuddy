import 'dart:io';

import 'package:dingdong/features/jev/data/jev_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Jev uses native secure storage without touching a real API key',
    (tester) async {
      final vault = SecureJevVault(
        'dingdong.jev.test.${DateTime.now().microsecondsSinceEpoch}.$pid',
      );
      try {
        expect(await vault.read(), isNull);
        await vault.write('synthetic-native-storage-check-only');
        expect(await vault.read(), 'synthetic-native-storage-check-only');
        await vault.delete();
        expect(await vault.read(), isNull);
      } finally {
        await vault.delete();
      }
    },
  );
}
