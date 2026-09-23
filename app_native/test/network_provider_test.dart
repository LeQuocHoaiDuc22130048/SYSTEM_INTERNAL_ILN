import 'package:flutter_test/flutter_test.dart';
import 'package:system_internal_likenew/utils/network_provider.dart';

void main() {
  test('network checks recover after a checker failure', () async {
    var calls = 0;
    final provider = NetworkProvider(
      autoPoll: false,
      checker: () async {
        calls++;
        if (calls == 1) throw StateError('temporary failure');
        return false;
      },
    );

    await expectLater(provider.checkNow(), throwsStateError);
    expect(await provider.checkNow(), isFalse);
    expect(calls, 2);

    provider.dispose();
  });
}
