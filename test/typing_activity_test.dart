import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/portable_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/sync/nas_recovery_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Directory dir;
  late SodiumSumo sodium;
  var locked = 0;

  setUpAll(() async => sodium = await SodiumSumoInit.init());
  setUp(() async {
    locked = 0;
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('quietake-typing');
  });
  tearDown(() => dir.delete(recursive: true));

  // Soft-keyboard typing sends no pointer or hardware key events, so the
  // text fields themselves must keep the idle timer from locking mid-entry.
  Future<void> typeForLongerThanTimeout(
    WidgetTester tester,
    Widget screen,
    List<Key> fields,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final privacy = PrivacyController(
      onLock: () => locked++,
      timeoutOverride: const Duration(milliseconds: 300),
    );
    addTearDown(privacy.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScope(controller: privacy, child: screen),
      ),
    );
    privacy.setEnabled(true);
    var typed = 0;
    for (final key in fields) {
      await tester.pump(const Duration(milliseconds: 200));
      // A changed value is what a keystroke produces; identical text is not an edit.
      await tester.enterText(find.byKey(key), 'typing ${typed++}');
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(locked, 0, reason: 'typing counts as activity');
    await tester.pump(const Duration(milliseconds: 400));
    expect(locked, 1, reason: 'the timer still locks once typing stops');
  }

  testWidgets('typing in NAS recovery keeps the idle lock from firing', (
    tester,
  ) async {
    await typeForLongerThanTimeout(
      tester,
      NasRecoveryScreen(store: MasterKeyStore(sodium, dir)),
      [Keys.nasUrl, Keys.nasUser, Keys.nasPassword, Keys.nasPin],
    );
  });

  testWidgets('typing in portable backup keeps the idle lock from firing', (
    tester,
  ) async {
    await typeForLongerThanTimeout(
      tester,
      PortableScreen(store: MasterKeyStore(sodium, dir)),
      [Keys.portablePasscode, Keys.portablePasscode, Keys.portablePasscode],
    );
  });
}
