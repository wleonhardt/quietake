import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

class _MemStorage extends FlutterSecureStoragePlatform {
  final map = <String, String>{};
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => map[key] = value;
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => map[key];
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => map.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => map.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      map.clear();
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(map);
}

class _BrokenStore extends MasterKeyStore {
  _BrokenStore(super.sodium, super.dir);
  @override
  Future<void> commitPasscode(SecureKey key, String passcode) async {
    throw const FileSystemException('disk full');
  }
}

void main() {
  late SodiumSumo sodium;
  late Directory dir;
  setUpAll(() async => sodium = await SodiumSumoInit.init());
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('quietake-setup');
    FlutterSecureStoragePlatform.instance = _MemStorage();
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
    await tester.enterText(find.byKey(Keys.setupConfirm), 'test-passcode');
    await tester.tap(find.byKey(Keys.setupSubmit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'setup persists the keyfile only after the recovery key is saved',
    (tester) async {
      final store = MasterKeyStore(sodium, dir);
      SecureKey? unlocked;
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(store: store, onUnlocked: (k) => unlocked = k),
        ),
      );
      await submit(tester);
      expect(find.byKey(Keys.recoveryKeyText), findsOneWidget);
      await tester.runAsync(() async {
        expect(await store.hasKeyfile, isFalse);
        expect(await store.hasCachedKey, isFalse);
      });
      await tester.tap(find.byKey(Keys.recoveryDone));
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && unlocked == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
        expect(unlocked, isNotNull);
        expect(await store.hasKeyfile, isTrue);
        final reopened = await store.unlockWithPasscode('test-passcode');
        expect(reopened.extractBytes(), unlocked!.extractBytes());
        reopened.dispose();
        unlocked!.dispose();
      });
    },
  );

  testWidgets('a failed commit shows a message and keeps setup open', (
    tester,
  ) async {
    final store = _BrokenStore(sodium, dir);
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(store: store, onUnlocked: (_) => fail('unlocked')),
      ),
    );
    await submit(tester);
    await tester.tap(find.byKey(Keys.recoveryDone));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Could not create the vault. Check storage and try again.'),
      findsOneWidget,
    );
    expect(find.byKey(Keys.setupSubmit), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
