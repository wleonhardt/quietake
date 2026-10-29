import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:quietake/privacy/privacy_controller.dart';

class _UnavailableStorage extends FlutterSecureStoragePlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => '1';
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    throw PlatformException(code: 'storage-unavailable');
  }
}

void main() {
  testWidgets('activity resets timeout and explicit lock stays locked', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    var locks = 0;
    final privacy = PrivacyController(onLock: () => locks++);
    addTearDown(privacy.dispose);
    privacy.setEnabled(true);
    await tester.pump(const Duration(minutes: 4));
    privacy.activity();
    await tester.pump(const Duration(minutes: 4));
    expect(locks, 0);
    await tester.pump(const Duration(minutes: 1));
    expect(locks, 1);
    await tester.pump(const Duration(minutes: 15));
    expect(locks, 1);
  });

  testWidgets(
    'recording/playback holds grant a fresh timeout after the last stops',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var locks = 0;
      final privacy = PrivacyController(onLock: () => locks++);
      addTearDown(privacy.dispose);
      privacy.setEnabled(true);
      final recording = Object(), playback = Object();
      privacy.hold(recording, true);
      privacy.hold(playback, true);
      await tester.pump(const Duration(minutes: 15));
      privacy.hold(recording, false);
      await tester.pump(const Duration(minutes: 15));
      expect(locks, 0);
      privacy.hold(playback, false);
      await tester.pump(const Duration(minutes: 4));
      expect(locks, 0);
      privacy.lock();
      expect(locks, 1);
      await tester.pump(const Duration(minutes: 10));
      expect(locks, 1);
    },
  );

  testWidgets(
    'timeout persists, off disables only idle, background/dispose cancel timers',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var locks = 0;
      final privacy = PrivacyController(onLock: () => locks++);
      privacy.setEnabled(true);
      await privacy.setMinutes(1);
      final loaded = PrivacyController(onLock: () {});
      await loaded.load();
      expect(loaded.minutes, 1);
      loaded.dispose();
      privacy.setEnabled(false);
      await tester.pump(const Duration(minutes: 15));
      expect(locks, 0);
      privacy.setEnabled(true);
      await privacy.setMinutes(0);
      await tester.pump(const Duration(minutes: 15));
      expect(locks, 0);
      privacy.lock();
      expect(locks, 1);
      privacy.setEnabled(true);
      await privacy.setMinutes(1);
      privacy.dispose();
      await tester.pump(const Duration(minutes: 2));
      expect(locks, 1);
    },
  );
  testWidgets(
    'failed preference save preserves the previously loaded timeout',
    (tester) async {
      final previousStorage = FlutterSecureStoragePlatform.instance;
      addTearDown(
        () => FlutterSecureStoragePlatform.instance = previousStorage,
      );
      FlutterSecureStoragePlatform.instance = _UnavailableStorage();
      var locks = 0;
      final privacy = PrivacyController(onLock: () => locks++);
      addTearDown(privacy.dispose);
      await privacy.load();
      privacy.setEnabled(true);
      await expectLater(
        privacy.setMinutes(15),
        throwsA(isA<PlatformException>()),
      );
      expect(privacy.minutes, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(locks, 1);
    },
  );
}
