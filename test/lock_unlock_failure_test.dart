import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';

class _UnreadableStore extends MasterKeyStore {
  _UnreadableStore(SodiumSumo sodium) : super(sodium, Directory.systemTemp);
  @override
  Future<bool> get hasKeyfile async => true;
  @override
  Future<bool> get hasCachedKey async => false;
  @override
  Future<SecureKey> unlockWithPasscode(String passcode) =>
      throw const FileSystemException('keyfile unreadable');
}

void main() {
  late SodiumSumo sodium;
  setUpAll(() async => sodium = await SodiumSumoInit.init());

  testWidgets('an unreadable keyfile shows a retry message, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _UnreadableStore(sodium),
          auth: FakeAuthenticator(isAvailable: false),
          autoPrompt: false,
          onUnlocked: (_) => fail('unlock must not succeed'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byKey(Keys.lockPasscode), 'whatever');
    await tester.tap(find.byKey(Keys.lockUnlock));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Could not unlock. Try again or use your recovery key.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recovering from the lock screen hands the key to the app', (
    tester,
  ) async {
    SecureKey? unlocked;
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _UnreadableStore(sodium),
          auth: FakeAuthenticator(isAvailable: false),
          autoPrompt: false,
          onUnlocked: (key) => unlocked = key,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(Keys.lockRecovery));
    await tester.pumpAndSettle();
    final setup = tester.widget<SetupScreen>(find.byType(SetupScreen));
    expect(setup.restoringOnly, isTrue);
    setup.onUnlocked(sodium.crypto.secretBox.keygen());
    await tester.pumpAndSettle();
    expect(unlocked, isNotNull);
    expect(find.byType(SetupScreen), findsNothing);
    unlocked!.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
