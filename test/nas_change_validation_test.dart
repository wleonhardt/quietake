import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/sync/nas_recovery_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  const phrase = 'correct horse battery staple';
  late Directory dir;
  late Session session;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-nas-change');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        dir,
      );
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, dir),
      );
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await session.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        home: NasRecoveryScreen(store: session.store, session: session),
      ),
    );
  }

  Future<void> fill(
    WidgetTester tester, {
    String pin = 'local-passcode',
    String passphrase = phrase,
    String confirm = phrase,
  }) async {
    await tester.enterText(find.byKey(Keys.nasPin), pin);
    await tester.enterText(find.byKey(Keys.nasPhrase), passphrase);
    await tester.enterText(find.byKey(Keys.nasPhraseConfirm), confirm);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(Keys.nasSave));
    await tester.tap(find.byKey(Keys.nasSave));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  String result(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(Keys.nasResult)).data!;

  testWidgets('a backup passphrase equal to the passcode is refused', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, pin: phrase);
    await save(tester);
    expect(
      result(tester),
      'Use a separate backup passphrase, not your local passcode.',
    );
  });

  testWidgets('mismatched passphrase confirmation is refused', (tester) async {
    await open(tester);
    await fill(tester, confirm: 'something else entirely here');
    await save(tester);
    expect(result(tester), 'Backup passphrases do not match.');
  });

  testWidgets('a too-short passphrase is refused', (tester) async {
    await open(tester);
    await fill(tester, passphrase: 'short', confirm: 'short');
    await save(tester);
    expect(find.byKey(Keys.nasChangeConfirm), findsNothing);
    expect(result(tester), isNotEmpty);
  });

  testWidgets('cancelling the confirmation makes no change', (tester) async {
    await open(tester);
    await fill(tester);
    await save(tester);
    expect(find.byKey(Keys.nasChangeConfirm), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.nasChangeConfirm), findsNothing);
    expect(find.text('Checking saved recovery on the backup server…'), findsNothing);
  });

  testWidgets('Disable asks for confirmation and Cancel makes no change', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(Keys.nasPin), 'local-passcode');
    await tester.ensureVisible(find.byKey(Keys.nasDisable));
    await tester.tap(find.byKey(Keys.nasDisable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Disable passphrase recovery?'), findsOneWidget);
    expect(find.byKey(Keys.nasDisableConfirm), findsOneWidget);
    expect(find.byKey(Keys.nasChangeConfirm), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.nasDisableConfirm), findsNothing);
    expect(find.text('Checking saved recovery on the backup server…'), findsNothing);
  });

  testWidgets('the show button reveals and hides the typed passphrase', (
    tester,
  ) async {
    await open(tester);
    bool hidden() =>
        tester.widget<TextField>(find.byKey(Keys.nasPhrase)).obscureText;
    expect(hidden(), isTrue);
    await tester.ensureVisible(find.byKey(Keys.nasVisibility));
    await tester.tap(find.byKey(Keys.nasVisibility));
    await tester.pump();
    expect(hidden(), isFalse);
    await tester.tap(find.byKey(Keys.nasVisibility));
    await tester.pump();
    expect(hidden(), isTrue);
  });

  testWidgets('Generate fills a new backup passphrase and clears its confirm', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byKey(Keys.nasPhraseConfirm), 'stale');
    await tester.ensureVisible(find.byKey(Keys.nasGenerate));
    await tester.runAsync(() => tester.tap(find.byKey(Keys.nasGenerate)));
    String phraseText() =>
        tester.widget<TextField>(find.byKey(Keys.nasPhrase)).controller!.text;
    for (var i = 0; i < 100 && phraseText().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(phraseText().split(' ').length, greaterThan(3));
    expect(
      tester
          .widget<TextField>(find.byKey(Keys.nasPhraseConfirm))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets(
    'a confirmed change without a saved NAS connection fails safely',
    (tester) async {
      await open(tester);
      await fill(tester);
      await save(tester);
      await tester.tap(find.byKey(Keys.nasChangeConfirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(result(tester), startsWith('Could not change recovery.'));
      expect(
        tester.widget<TextField>(find.byKey(Keys.nasPin)).controller!.text,
        isEmpty,
        reason: 'The typed passcode must be cleared after a failed attempt',
      );
      expect(
        tester.widget<TextField>(find.byKey(Keys.nasPhrase)).controller!.text,
        isEmpty,
      );
    },
  );
}
