import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/debouncer.dart';

void main() {
  group('Debouncer Tests', () {
    test('coalesces rapid consecutive calls into a single execution', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var executions = 0;
      String? lastValue;

      debouncer.run(() {
        executions++;
        lastValue = 'a';
      });
      debouncer.run(() {
        executions++;
        lastValue = 'ab';
      });
      debouncer.run(() {
        executions++;
        lastValue = 'abc';
      });

      expect(executions, 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(executions, 1);
      expect(lastValue, 'abc');
      debouncer.dispose();
    });

    test('cancel prevents pending callback from running', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var executed = false;

      debouncer.run(() => executed = true);
      debouncer.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(executed, isFalse);
      debouncer.dispose();
    });
  });
}
