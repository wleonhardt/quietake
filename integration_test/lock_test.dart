import '../test_support/integration_binding.dart';
import '../test_support/fixtures.dart';
import '../test_support/test_vault.dart';

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/main.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';
import '../test_support/fake_cast_backend.dart';

class _DelayedUnlockStore extends MasterKeyStore {
  _DelayedUnlockStore(this.source) : super(source.sodium, source.dir);
  final MasterKeyStore source;
  @override
  Future<SecureKey> restoreFromRecovery(
    String recovery,
    String passcode, {
    bool Function(SecureKey)? acceptsKey,
    Future<bool> Function(String fingerprint)? confirmFingerprint,
  }) async {
    final key = await source.restoreFromRecovery(
      recovery,
      passcode,
      acceptsKey: acceptsKey,
      confirmFingerprint: confirmFingerprint,
    );
    derived.complete();
    await release.future;
    return key;
  }

  final derived = Completer<void>();
  final release = Completer<void>();
  @override
  Future<SecureKey> unlockWithPasscode(String passcode) async {
    final key = await source.unlockWithPasscode(passcode);
    derived.complete();
    await release.future;
    return key;
  }
}

/// Setup, lock, biometric and passcode unlock, recovery export and restore,
/// all through the UI. Starts from a wiped key state and a vault that holds
/// one container, which must survive every step.
void main() {
  initializeIntegrationBinding();

  late MasterKeyStore store;
  late FakeAuthenticator auth;
  late FakeCastBackend backend;
  late String recoveryKey;

  setUpAll(() async {
    final sodium = await SodiumSumoInit.init();
    final docs = await getApplicationDocumentsDirectory();
    store = MasterKeyStore(sodium, docs);
    await store.clearCache();
    if (await store.hasKeyfile) await store.keyfile.delete();
    // A pre-passcode install: key in the keystore, one container on disk.
    final vault = await openTestVault();
    for (final f in await vault.list()) {
      await f.delete();
    }
    final tmp = await getTemporaryDirectory();
    final data = fixtureBytes('tiny.jpg');
    final f = File('${tmp.path}/legacy.jpg')..writeAsBytesSync(data);
    await vault.ingestAs(f, '2026-01.legacy.jpg');
    auth = FakeAuthenticator();
    backend = FakeCastBackend();
    // How long Argon2id (moderate) takes here; the first call also spawns the isolate.
    for (var i = 0; i < 2; i++) {
      final sw = Stopwatch()..start();
      (await store.createWithPasscode('timing')).dispose();
      debugPrint('KDF createWithPasscode #$i: ${sw.elapsedMilliseconds} ms');
    }
    await store.keyfile.delete(); // back to the pre-passcode state
  });

  bool has(Key k) => find.byKey(k).evaluate().isNotEmpty;
  String text(WidgetTester tester, Key k) =>
      tester.widget<Text>(find.byKey(k)).data!;

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(end)) {
        final err = has(Keys.setupError) ? text(tester, Keys.setupError) : '-';
        fail(
          'timed out after $timeout; keyfile=${store.keyfile.existsSync()} '
          'setup=${has(Keys.setupSubmit)} lock=${has(Keys.lockPasscode)} '
          'recovery=${has(Keys.recoveryKeyText)} gallery=${has(Keys.openGallery)} setupError=$err',
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 500));

  Future<void> enter(WidgetTester tester, Key k, String value) async {
    await tester.enterText(find.byKey(k), value);
    // Close the native input connection before checking for a stale IME echo.
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    final c = tester.widget<TextField>(find.byKey(k)).controller!;
    if (c.text != value) c.text = value;
    await tester.pump();
    expect(c.text == value, isTrue, reason: 'Test field $k lost entered text');
  }

  Future<void> tap(WidgetTester tester, Key k) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.ensureVisible(find.byKey(k));
    await tester.pump();
    await tester.tap(find.byKey(k));
    await tester.pump();
  }

  Widget app() => QuietakeApp(store: store, auth: auth, castBackend: backend);

  Future<void> expectLiveError(WidgetTester tester, Key key) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        tester.getSemantics(find.byKey(key)).flagsCollection.isLiveRegion,
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  }

  testWidgets('setup adopts the existing key and shows the recovery key', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpUntil(tester, () => has(Keys.setupPasscode));
    final filesBeforePolicy = await (await getApplicationDocumentsDirectory())
        .list()
        .map((file) => file.path)
        .toList();
    await tap(tester, Keys.setupPrivacyPolicy);
    await pumpUntil(
      tester,
      () => find.text('Your vault').evaluate().isNotEmpty,
    );
    expect(has(Keys.privacyPolicyPage), isTrue);
    expect(find.textContaining('Leonhardt Labs'), findsWidgets);
    expect(await store.hasKeyfile, isFalse);
    await tester.pageBack();
    await settle(tester);
    expect(has(Keys.setupPasscode), isTrue);
    expect(
      await (await getApplicationDocumentsDirectory())
          .list()
          .map((file) => file.path)
          .toList(),
      unorderedEquals(filesBeforePolicy),
    );
    await enter(tester, Keys.setupPasscode, 'hunter22');
    await enter(tester, Keys.setupConfirm, 'hunter2');
    await tap(tester, Keys.setupSubmit);
    await pumpUntil(tester, () => has(Keys.setupError));
    expect(text(tester, Keys.setupError), 'Passcodes do not match');
    await expectLiveError(tester, Keys.setupError);

    await enter(tester, Keys.setupConfirm, 'hunter22');
    await tap(tester, Keys.setupSubmit);
    await pumpUntil(tester, () => has(Keys.recoveryKeyText));
    await settle(tester);
    expect(find.textContaining('encrypted files'), findsOneWidget);
    expect(find.textContaining('enabled'), findsOneWidget);
    recoveryKey = tester
        .widget<SelectableText>(find.byKey(Keys.recoveryKeyText))
        .data!;
    expect(
      recoveryKey.replaceAll(' ', '').length,
      44,
      reason: '32 bytes of base64',
    );
    expect(find.byKey(Keys.recoveryFingerprint), findsOneWidget);
    await tap(tester, Keys.recoveryDone);
    await pumpUntil(tester, () => has(Keys.openGallery));
    expect(await store.hasKeyfile, isTrue);

    // The legacy container still decrypts under the adopted key.
    await tap(tester, Keys.openGallery);
    await pumpUntil(tester, () => has(Keys.galleryTile(0)));
    await settle(tester);
    await pumpUntil(
      tester,
      () => find
          .descendant(
            of: find.byKey(Keys.galleryTile(0)),
            matching: find.byKey(Keys.galleryPreview),
          )
          .evaluate()
          .isNotEmpty,
    );
  });

  testWidgets(
    'cold lock resumes with one biometric prompt and a working retry',
    (tester) async {
      auth.answer = false;
      await tester.pumpWidget(app());
      await pumpUntil(tester, () => has(Keys.lockBiometric));
      await settle(tester);
      final before = auth.reasons.length;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      // Coalesced lifecycle events must not depend on a background frame.
      // Resume before pumping so the old gate cannot authenticate while hidden.
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await pumpUntil(tester, () => auth.reasons.length > before);
      await settle(tester);
      expect(
        auth.reasons.length,
        before + 1,
        reason: 'Only the visible lock gate can prompt',
      );
      auth.answer = true;
      await tap(tester, Keys.lockBiometric);
      await pumpUntil(tester, () => has(Keys.openGallery));
    },
  );

  testWidgets('backgrounding locks; biometrics and passcode both unlock', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    // Cold start with a keyfile: the lock screen, and biometrics fire by themselves.
    await pumpUntil(
      tester,
      () => has(Keys.lockPasscode) || has(Keys.openGallery),
    );
    await pumpUntil(tester, () => has(Keys.openGallery));
    expect(auth.reasons, isNotEmpty);
    expect(auth.reasons, everyElement('Unlock Quietake'));

    // Going to the background locks the UI, session intact. The lock screen
    // prompts for biometrics on its own, so refuse before it appears.
    auth.answer = false;
    final prompts = auth.reasons.length;
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    for (final st in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await pumpUntil(tester, () => auth.reasons.length > prompts);
    await settle(tester);
    expect(
      has(Keys.lockPasscode),
      isTrue,
      reason: 'refused biometric keeps the lock',
    );

    // Passcode path: wrong, then right.
    await enter(tester, Keys.lockPasscode, 'nope');
    await tap(tester, Keys.lockUnlock);
    await pumpUntil(tester, () => has(Keys.lockError));
    expect(text(tester, Keys.lockError), 'wrong passcode');
    await expectLiveError(tester, Keys.lockError);
    await enter(tester, Keys.lockPasscode, 'hunter22');
    await tap(tester, Keys.lockUnlock);
    await pumpUntil(tester, () => has(Keys.openGallery));
    // A pushed gallery must be hidden by the lock and restored after unlock.
    await tap(tester, Keys.openGallery);
    await pumpUntil(tester, () => has(Keys.gallerySettings));
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    for (final st in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await tester.pump();
    expect(has(Keys.gallerySettings), isFalse);
    await pumpUntil(tester, () => has(Keys.lockPasscode));
    await enter(tester, Keys.lockPasscode, 'hunter22');
    await tap(tester, Keys.lockUnlock);
    await pumpUntil(tester, () => has(Keys.gallerySettings));
    auth.answer = true;
  });

  testWidgets('recovery key from settings matches; restore on a wiped phone', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpUntil(tester, () => has(Keys.openGallery));
    await tap(tester, Keys.openGallery);
    await pumpUntil(tester, () => has(Keys.gallerySettings));
    await settle(tester);
    await tap(tester, Keys.gallerySettings);
    await pumpUntil(tester, () => has(Keys.settingsUrl));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(Keys.settingsRecovery),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, Keys.settingsRecovery);
    await pumpUntil(tester, () => has(Keys.recoveryPrompt));
    await enter(tester, Keys.recoveryPrompt, 'hunter22');
    await tap(tester, Keys.recoveryPromptOk);
    await pumpUntil(tester, () => has(Keys.recoveryKeyText));
    expect(
      tester.widget<SelectableText>(find.byKey(Keys.recoveryKeyText)).data,
      recoveryKey,
    );

    // The recovery key route is protected too and resumes only after unlock.
    auth.answer = false;
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    for (final st in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await tester.pump();
    expect(has(Keys.recoveryKeyText), isFalse);
    await pumpUntil(tester, () => has(Keys.lockPasscode));
    await enter(tester, Keys.lockPasscode, 'hunter22');
    await tap(tester, Keys.lockUnlock);
    await pumpUntil(tester, () => has(Keys.recoveryKeyText));
    auth.answer = true;

    // New phone: no keyfile, no keystore entry, containers synced back from the NAS.
    await store.clearCache();
    await store.keyfile.delete();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await pumpUntil(tester, () => has(Keys.setupToggleRestore));
    await tap(tester, Keys.setupToggleRestore);
    await pumpUntil(tester, () => has(Keys.setupRecoveryKey));
    await enter(tester, Keys.setupRecoveryKey, 'not a key');
    await enter(tester, Keys.setupPasscode, 'newpass1');
    await enter(tester, Keys.setupConfirm, 'newpass1');
    await tap(tester, Keys.setupSubmit);
    await pumpUntil(tester, () => has(Keys.setupError));
    expect(text(tester, Keys.setupError), contains('recovery key'));
    await expectLiveError(tester, Keys.setupError);

    await enter(tester, Keys.setupRecoveryKey, recoveryKey);
    await tap(tester, Keys.setupSubmit);
    await pumpUntil(tester, () => has(Keys.openGallery));
    await tap(tester, Keys.openGallery);
    await pumpUntil(tester, () => has(Keys.galleryTile(0)));
    await settle(tester);
    await pumpUntil(
      tester,
      () => find
          .descendant(
            of: find.byKey(Keys.galleryTile(0)),
            matching: find.byKey(Keys.galleryPreview),
          )
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    // Restored key unlocks with the new passcode only.
    await expectLater(
      store.unlockWithPasscode('hunter22'),
      throwsA(isA<WrongPasscodeException>()),
    );
    (await store.unlockWithPasscode('newpass1')).dispose();
  });
  testWidgets(
    'forgotten passcode restores an existing vault without wiping media',
    (tester) async {
      auth.answer = false;
      await tester.pumpWidget(app());
      await pumpUntil(tester, () => has(Keys.lockRecovery));
      await tap(tester, Keys.lockRecovery);
      await pumpUntil(tester, () => has(Keys.setupRecoveryKey));
      expect(has(Keys.setupToggleRestore), isFalse);
      await enter(tester, Keys.setupRecoveryKey, recoveryKey);
      await enter(tester, Keys.setupPasscode, 'recovered1');
      await enter(tester, Keys.setupConfirm, 'recovered1');
      await tap(tester, Keys.setupSubmit);
      await pumpUntil(tester, () => has(Keys.openGallery));
      await tap(tester, Keys.openGallery);
      await pumpUntil(tester, () => has(Keys.galleryTile(0)));
      (await store.unlockWithPasscode('recovered1')).dispose();
    },
  );
  for (final restoring in [false, true]) {
    testWidgets(
      'backgrounding invalidates a pending real ${restoring ? 'restore' : 'passcode'} result',
      (tester) async {
        (await store.createWithPasscode('pending-passcode')).dispose();
        final delayed = _DelayedUnlockStore(store);
        var unlocked = false;
        final key = (await store.cachedKey())!;
        final recovery = store.exportRecovery(key);
        key.dispose();
        void onUnlocked(SecureKey key) {
          unlocked = true;
          key.dispose();
        }

        await tester.pumpWidget(
          MaterialApp(
            home: restoring
                ? SetupScreen(
                    store: delayed,
                    restoringOnly: true,
                    onUnlocked: onUnlocked,
                  )
                : LockScreen(
                    store: delayed,
                    auth: FakeAuthenticator(isAvailable: false),
                    onUnlocked: onUnlocked,
                  ),
          ),
        );
        await settle(tester);
        if (restoring) {
          await enter(tester, Keys.setupRecoveryKey, recovery);
          await enter(tester, Keys.setupPasscode, 'pending-passcode');
          await enter(tester, Keys.setupConfirm, 'pending-passcode');
        } else {
          await enter(tester, Keys.lockPasscode, 'pending-passcode');
        }
        await tap(tester, restoring ? Keys.setupSubmit : Keys.lockUnlock);
        await pumpUntil(tester, () => delayed.derived.isCompleted);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.runAsync(() async {
          delayed.release.complete();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        expect(unlocked, isFalse);
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await settle(tester);
        expect(
          find
              .byKey(restoring ? Keys.setupSubmit : Keys.lockUnlock)
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(restoring ? Keys.setupSubmit : Keys.lockUnlock),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
