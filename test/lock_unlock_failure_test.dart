import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';

class _CachedKeyStore extends _UnreadableStore {
  _CachedKeyStore(super.sodium);
  @override
  Future<bool> get hasCachedKey async => true;
}

class _RefusingAuth extends FakeAuthenticator {
  _RefusingAuth() : super(answer: false);
  @override
  Future<bool> authenticate(String reason) async {
    lastError = 'Too many attempts. Try again later.';
    return super.authenticate(reason);
  }
}

class _WrongPasscodeStore extends _UnreadableStore {
  _WrongPasscodeStore(super.sodium);
  int tries = 0;
  @override
  Future<SecureKey> unlockWithPasscode(String passcode) {
    tries++;
    throw WrongPasscodeException();
  }
}

class _LockedStore extends _UnreadableStore {
  _LockedStore(super.sodium);
  @override
  Future<SecureKey> unlockWithPasscode(String passcode) =>
      throw PasscodeLockedException(
        const Duration(seconds: 29, milliseconds: 500),
      );
}

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

  testWidgets('a refused biometric prompt shows the reason and keeps retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _CachedKeyStore(sodium),
          auth: _RefusingAuth(),
          autoPrompt: false,
          onUnlocked: (_) => fail('a refused prompt must not unlock'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(Keys.lockBiometric));
    await tester.pump();
    expect(find.text('Too many attempts. Try again later.'), findsOneWidget);
    expect(find.byKey(Keys.lockBiometric), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a wrong passcode submitted from the keyboard shows its message',
    (tester) async {
      final store = _WrongPasscodeStore(sodium);
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(
            store: store,
            auth: FakeAuthenticator(isAvailable: false),
            autoPrompt: false,
            onUnlocked: (_) => fail('a wrong passcode must not unlock'),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byKey(Keys.lockPasscode), 'nope');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(store.tries, 1);
      expect(find.text(WrongPasscodeException().toString()), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('with the plain icon on, the lock screen shows no name or logo', (
    tester,
  ) async {
    const appearance = MethodChannel('quietake/appearance');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      appearance,
      (call) async => call.method == 'neutral' ? true : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        appearance,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _LockedStore(sodium),
          auth: FakeAuthenticator(isAvailable: false),
          autoPrompt: false,
          onUnlocked: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Quietake'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(Keys.lockPasscode), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a locked passcode shows how long to wait', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _LockedStore(sodium),
          auth: FakeAuthenticator(isAvailable: false),
          autoPrompt: false,
          onUnlocked: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byKey(Keys.lockPasscode), 'whatever');
    await tester.tap(find.byKey(Keys.lockUnlock));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Too many wrong passcodes. Try again in 30 seconds.'),
      findsOneWidget,
    );
    // Under the field, above the button.
    expect(
      tester.getTopLeft(find.byKey(Keys.lockError)).dy,
      lessThan(tester.getTopLeft(find.byKey(Keys.lockUnlock)).dy),
    );
    expect(
      tester.widget<TextField>(find.byKey(Keys.lockPasscode)).obscureText,
      isTrue,
    );
    await tester.tap(find.byKey(Keys.lockShowPasscode));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(Keys.lockPasscode)).obscureText,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
