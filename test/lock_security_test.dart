import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/core/lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await LockService().removePin();
  });

  group('LockService Security & Cooldown Synchronization Tests', () {
    test('LockService constants have correct security parameters', () {
      expect(LockService.maxFailedAttempts, 5);
      expect(LockService.cooldownDurationSeconds, 30);
    });

    test('Initial state is not blocked and has zero failed attempts', () {
      final service = LockService();
      expect(service.isPinBlocked, isFalse);
      expect(service.remainingBlockedSeconds, 0);
      expect(service.failedAttempts, 0);
    });

    test('verifyPin with correct PIN resets failed attempts to zero', () async {
      final service = LockService();
      await service.savePin('1234');

      // 2 failed attempts
      expect(await service.verifyPin('0000'), isFalse);
      expect(await service.verifyPin('1111'), isFalse);
      expect(service.failedAttempts, 2);
      expect(service.isPinBlocked, isFalse);

      // Successful attempt
      expect(await service.verifyPin('1234'), isTrue);
      expect(service.failedAttempts, 0);
      expect(service.isPinBlocked, isFalse);
    });

    test('5 consecutive failed attempts trigger security cooldown', () async {
      final service = LockService();
      await service.savePin('5678');

      for (int i = 1; i <= 4; i++) {
        expect(await service.verifyPin('0000'), isFalse);
        expect(service.failedAttempts, i);
        expect(service.isPinBlocked, isFalse);
      }

      // 5th failed attempt triggers lock
      expect(await service.verifyPin('0000'), isFalse);
      expect(service.failedAttempts, 5);
      expect(service.isPinBlocked, isTrue);
      expect(service.remainingBlockedSeconds, greaterThan(0));
      expect(service.remainingBlockedSeconds, lessThanOrEqualTo(30));

      // 6th attempt while blocked is immediately rejected without waiting
      expect(await service.verifyPin('5678'), isFalse);
    });

    test('removePin resets attempts, blocks, and removes stored PIN', () async {
      final service = LockService();
      await service.savePin('9999');

      for (int i = 0; i < 5; i++) {
        await service.verifyPin('0000');
      }
      expect(service.isPinBlocked, isTrue);

      await service.removePin();
      expect(service.isPinBlocked, isFalse);
      expect(service.failedAttempts, 0);
      expect(service.remainingBlockedSeconds, 0);
      expect(await service.hasPin(), isFalse);
    });
  });
}
