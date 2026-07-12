import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publishes typed collection changes to current subscribers', () async {
    final DataRevisionBus bus = DataRevisionBus();
    final List<DataCollection> changes = <DataCollection>[];
    final subscription = bus.changes.listen(changes.add);

    bus.changed(DataCollection.library);
    bus.changed(DataCollection.clipboard);

    expect(changes, <DataCollection>[
      DataCollection.library,
      DataCollection.clipboard,
    ]);
    await subscription.cancel();
    await bus.dispose();
  });
}
