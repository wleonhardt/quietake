import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/sync/nas_recovery_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const phrase = 'correct horse battery staple';
  late Directory dir;
  late SodiumSumo sodium;
  var restored = false;

  setUpAll(() async => sodium = await SodiumSumoInit.init());
  setUp(() async {
    restored = false;
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('quietake-nas-restore');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: NasRecoveryScreen(
          store: MasterKeyStore(sodium, dir),
          onRestored: () => restored = true,
        ),
      ),
    );
  }

  Future<void> fill(
    WidgetTester tester, {
    String url = 'https://nas.example/vault/',
    String user = 'user',
    String password = 'secret',
    String pin = 'newpass',
    String confirm = 'newpass',
    String passphrase = phrase,
  }) async {
    for (final (key, value) in [
      (Keys.nasUrl, url),
      (Keys.nasUser, user),
      (Keys.nasPassword, password),
      (Keys.nasPin, pin),
      (Keys.nasPinConfirm, confirm),
      (Keys.nasPhrase, passphrase),
    ]) {
      await tester.enterText(find.byKey(key), value);
    }
  }

  Future<String> start(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(Keys.nasStartRestore));
    await tester.tap(find.byKey(Keys.nasStartRestore));
    await tester.pump();
    return tester.widget<Text>(find.byKey(Keys.nasResult)).data!;
  }

  testWidgets('a weak backup passphrase is explained before any network use', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, passphrase: 'short');
    expect(await start(tester), contains('at least 24 characters'));
    expect(restored, isFalse);
  });

  testWidgets('the phone passcode cannot double as the backup passphrase', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, pin: phrase, confirm: phrase);
    expect(await start(tester), contains('separate backup passphrase'));
  });

  testWidgets('a short or unconfirmed new passcode is refused', (tester) async {
    await open(tester);
    await fill(tester, pin: 'abc', confirm: 'abc');
    expect(await start(tester), contains('at least six characters'));
    await fill(tester, pin: 'newpass', confirm: 'different');
    expect(await start(tester), contains('confirm a new passcode'));
  });

  testWidgets('missing NAS details are requested', (tester) async {
    await open(tester);
    await fill(tester, user: '');
    expect(await start(tester), contains('Enter your saved NAS folder'));
  });

  testWidgets('a plain HTTP remote URL is refused', (tester) async {
    await open(tester);
    await fill(tester, url: 'http://nas.example/vault/');
    expect(await start(tester), 'Use an HTTPS WebDAV folder URL');
    expect(restored, isFalse);
  });
}
