import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/auth/authenticator.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/main.dart';
import 'package:quietake/session.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/vault.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/privacy/screen_privacy.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/fake_authenticator.dart';

import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

class _CachedStore extends MasterKeyStore {
  _CachedStore(SodiumSumo sodium, this.key)
    : super(sodium, Directory.systemTemp);
  final SecureKey key;
  @override
  Future<bool> get hasCachedKey async => true;
  @override
  Future<bool> get hasKeyfile async => true;
  @override
  Future<SecureKey?> cachedKey() async => key.copy();
}

class _VanishedCacheStore extends _CachedStore {
  _VanishedCacheStore(super.sodium, super.key);
  @override
  Future<SecureKey?> cachedKey() async => null;
}

class _BrokenKeystore extends _CachedStore {
  _BrokenKeystore(super.sodium, super.key);
  @override
  Future<bool> get hasCachedKey async => throw StateError('keystore');
}

class _PasscodeStore extends _CachedStore {
  _PasscodeStore(super.sodium, super.key);
  final attempts = <Completer<SecureKey>>[];
  @override
  Future<SecureKey> createWithPasscode(String passcode) =>
      unlockWithPasscode(passcode);
  @override
  Future<SecureKey> restoreFromRecovery(
    String recovery,
    String passcode, {
    bool Function(SecureKey)? acceptsKey,
    Future<bool> Function(String fingerprint)? confirmFingerprint,
  }) => unlockWithPasscode(passcode);
  @override
  Future<SecureKey> unlockWithPasscode(String passcode) {
    final attempt = Completer<SecureKey>();
    attempts.add(attempt);
    return attempt.future;
  }
}

class _PendingAuth implements Authenticator {
  final prompts = <Completer<bool>>[];
  int cancels = 0;
  @override
  String? lastError;
  @override
  Future<bool> get available async => true;
  @override
  Future<bool> authenticate(String reason) {
    final prompt = Completer<bool>();
    prompts.add(prompt);
    return prompt.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  late SodiumSumo sodium;
  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  testWidgets('a vanished biometric cache falls back to the passcode', (
    tester,
  ) async {
    final key = sodium.crypto.secretBox.keygen();
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _VanishedCacheStore(sodium, key),
          auth: FakeAuthenticator(),
          autoPrompt: false,
          onUnlocked: (_) => fail('nothing to unlock with'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(Keys.lockBiometric));
    await tester.pump();
    expect(find.byKey(Keys.lockBiometric), findsNothing);
    expect(
      find.text('Biometric unlock is unavailable. Use your passcode.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    key.dispose();
  });

  testWidgets('an unreadable keystore hides biometrics without an error', (
    tester,
  ) async {
    final key = sodium.crypto.secretBox.keygen();
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _BrokenKeystore(sodium, key),
          auth: FakeAuthenticator(),
          onUnlocked: (_) => fail('nothing to unlock with'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(Keys.lockBiometric), findsNothing);
    expect(find.byKey(Keys.lockUnlock), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    key.dispose();
  });

  testWidgets(
    'passcode completed after backgrounding requires a fresh unlock',
    (tester) async {
      final key = sodium.crypto.secretBox.keygen();
      final store = _PasscodeStore(sodium, key);
      var unlocked = 0;
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(
            store: store,
            auth: FakeAuthenticator(isAvailable: false),
            onUnlocked: (key) {
              unlocked++;
              key.dispose();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byKey(Keys.lockPasscode), 'test-passcode');
      await tester.tap(find.byKey(Keys.lockUnlock));
      await tester.pump();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      store.attempts.single.complete(key.copy());
      await tester.pump();
      expect(unlocked, 0, reason: 'A background result must not lift the lock');
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      await tester.tap(find.byKey(Keys.lockUnlock));
      await tester.pump();
      store.attempts.last.complete(key.copy());
      await tester.pump();
      expect(unlocked, 1);
      await tester.pumpWidget(const SizedBox());
      key.dispose();
    },
  );

  testWidgets('damaged keyfile offers recovery without an uncaught error', (
    tester,
  ) async {
    final key = sodium.crypto.secretBox.keygen();
    final store = _PasscodeStore(sodium, key);
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: store,
          auth: FakeAuthenticator(isAvailable: false),
          onUnlocked: (key) => key.dispose(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(Keys.lockUnlock));
    await tester.pump();
    store.attempts.single.completeError(
      const FormatException('damaged keyfile'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(Keys.lockError), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byKey(Keys.lockRecovery)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    key.dispose();
  });

  // Setup persists nothing before the recovery key is confirmed (decision 038),
  // so only restore has an interruptible credential step; see
  // setup_screen_test.dart for the setup order.
  for (final restoring in [true]) {
    testWidgets(
      'interrupted ${restoring ? 'restore' : 'setup'} requires a fresh attempt',
      (tester) async {
        final key = sodium.crypto.secretBox.keygen();
        final store = _PasscodeStore(sodium, key);
        var unlocked = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: SetupScreen(
              store: store,
              restoringOnly: restoring,
              onUnlocked: (key) {
                unlocked++;
                key.dispose();
              },
            ),
          ),
        );
        await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
        await tester.enterText(find.byKey(Keys.setupConfirm), 'test-passcode');
        await tester.ensureVisible(find.byKey(Keys.setupSubmit));
        await tester.tap(find.byKey(Keys.setupSubmit));
        await tester.pump();
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        store.attempts.single.complete(key.copy());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(unlocked, 0);
        expect(find.byKey(Keys.recoveryKeyText).evaluate().length, 0);
        await tester.tap(find.byKey(Keys.setupSubmit));
        await tester.pump();
        store.attempts.last.complete(key.copy());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        if (!restoring) {
          await tester.tap(find.byKey(Keys.recoveryDone));
          await tester.pump();
        }
        expect(unlocked, 1);
        await tester.pumpWidget(const SizedBox());
        key.dispose();
      },
    );
  }

  for (final mode in ['background', 'duplicate', 'fresh-unlock']) {
    testWidgets(
      'session opening handles $mode without losing lock or resources',
      (tester) async {
        final key = sodium.crypto.secretBox.keygen();
        final path = Completer<String>();
        var opens = 0;
        late Directory dir;
        await tester.runAsync(() async {
          dir = await Directory.systemTemp.createTemp('quietake-start-race');
        });
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) {
            opens++;
            return path.future;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          QuietakeApp(
            store: _CachedStore(sodium, key),
            auth: FakeAuthenticator(isAvailable: false),
            castBackend: FakeCastBackend(),
          ),
        );
        await tester.pump();
        await tester.pump();
        tester
            .widget<LockScreen>(find.byType(LockScreen))
            .onUnlocked(key.copy());
        if (mode == 'duplicate') {
          tester
              .widget<LockScreen>(find.byType(LockScreen))
              .onUnlocked(key.copy());
        }
        await tester.pump();
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        if (mode == 'fresh-unlock') {
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.pump();
          tester
              .widget<LockScreen>(find.byType(LockScreen))
              .onUnlocked(key.copy());
          await tester.pump();
        }
        expect(
          opens,
          1,
          reason: 'Only one session may own the opening key/server',
        );
        await tester.runAsync(() async {
          path.complete(dir.path);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        if (mode != 'fresh-unlock') {
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(Keys.lockUnlock).hitTestable(),
          mode == 'fresh-unlock' ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(Keys.openGallery).hitTestable(),
          mode == 'fresh-unlock' ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await dir.delete(recursive: true);
        });
        key.dispose();
      },
    );
  }
  testWidgets('a background lock waits for resume before prompting', (
    tester,
  ) async {
    final key = sodium.crypto.secretBox.keygen();
    final auth = _PendingAuth();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          store: _CachedStore(sodium, key),
          auth: auth,
          onUnlocked: (key) => key.dispose(),
        ),
      ),
    );
    await tester.pump();
    expect(auth.prompts, isEmpty);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(auth.prompts, hasLength(1));
    auth.prompts.single.complete(false);
    await tester.pumpWidget(const SizedBox());
    key.dispose();
  });

  testWidgets(
    'paused prompt cannot block retry or unlock from a stale result',
    (tester) async {
      final key = sodium.crypto.secretBox.keygen();
      final auth = _PendingAuth();
      var unlocked = 0;
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(
            store: _CachedStore(sodium, key),
            auth: auth,
            onUnlocked: (key) {
              unlocked++;
              key.dispose();
            },
          ),
        ),
      );
      await tester.pump();
      expect(auth.prompts, hasLength(1));
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(auth.cancels, 1);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      await tester.tap(find.byKey(Keys.lockBiometric));
      await tester.pump();
      expect(auth.prompts, hasLength(2));
      auth.prompts.first.complete(true);
      await tester.pump();
      expect(unlocked, 0);
      auth.prompts[1].complete(false);
      await tester.pump();
      await tester.tap(find.byKey(Keys.lockBiometric));
      await tester.pump();
      expect(auth.prompts, hasLength(3));
      auth.prompts.last.complete(true);
      await tester.pump();
      expect(unlocked, 1);
      await tester.pumpWidget(const SizedBox());
      key.dispose();
    },
  );
  for (final coalesced in [false, true]) {
    testWidgets(
      'only the visible lock gate may start biometrics after cold-start backgrounding; coalesced=$coalesced',
      (tester) async {
        final key = sodium.crypto.secretBox.keygen();
        final auth = _PendingAuth();
        await tester.pumpWidget(
          QuietakeApp(
            store: _CachedStore(sodium, key),
            auth: auth,
            castBackend: FakeCastBackend(),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(auth.prompts, hasLength(1));
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        if (!coalesced) await tester.pump();
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        await tester.pump();
        expect(
          auth.prompts,
          hasLength(2),
          reason:
              'The hidden home lock must not compete with the visible overlay',
        );
        for (final prompt in auth.prompts) {
          if (!prompt.isCompleted) prompt.complete(false);
        }
        await tester.pumpWidget(const SizedBox());
        key.dispose();
      },
    );
  }
  testWidgets(
    'deliberate locks wait for explicit biometrics across backgrounding',
    (tester) async {
      final key = sodium.crypto.secretBox.keygen();
      final auth = FakeAuthenticator();
      var unlocked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreen(
            store: _CachedStore(sodium, key),
            auth: auth,
            autoPrompt: false,
            onUnlocked: (value) {
              unlocked++;
              value.dispose();
            },
          ),
        ),
      );
      await tester.pump();
      expect(auth.reasons, isEmpty);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(auth.reasons, isEmpty);
      await tester.tap(find.byKey(Keys.lockBiometric));
      await tester.pump();
      expect(unlocked, 1);
      await tester.pumpWidget(const SizedBox());
      key.dispose();
    },
  );
  for (final coalesced in [false, true]) {
    testWidgets(
      'capture protection invalidates pending biometrics (coalesced: $coalesced)',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final key = sodium.crypto.secretBox.keygen();
        final auth = _PendingAuth();
        final backend = FakeCastBackend();
        late Directory dir;
        late Session session;
        await tester.runAsync(() async {
          dir = await Directory.systemTemp.createTemp('quietake-privacy-gate');
          final vault = Vault(VaultCrypto(sodium), key.copy(), dir);
          session = Session(
            vault: vault,
            server: await MediaServer.start(vault),
            cast: CastController(vault, backend),
            store: _CachedStore(sodium, key),
          );
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.runAsync(() async {
            await session.close();
            await dir.delete(recursive: true);
          });
          key.dispose();
        });
        await tester.pumpWidget(
          QuietakeApp(
            store: session.store,
            auth: auth,
            castBackend: backend,
            session: session,
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(Keys.lockNow));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        await tester.tap(find.byKey(Keys.lockBiometric));
        await tester.pump();
        expect(auth.prompts, hasLength(1));
        var generation = 0;
        void captured(bool value) => ui.channelBuffers.push(
          ScreenPrivacy.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('state', {
              'captured': value,
              'generation': ++generation,
            }),
          ),
          (_) {},
        );
        captured(true);
        if (coalesced) {
          await tester.idle();
        } else {
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
        }
        captured(false);
        if (coalesced) {
          await tester.idle();
        } else {
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
        }
        auth.prompts.first.complete(true);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.byKey(Keys.lockPasscode), findsOneWidget);
        expect(auth.prompts, hasLength(1));
        await tester.tap(find.byKey(Keys.lockBiometric));
        await tester.pump();
        expect(auth.prompts, hasLength(2));
        auth.prompts.last.complete(true);
        if (coalesced) {
          await tester.idle();
          captured(true);
          await tester.idle();
          captured(false);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(find.byKey(Keys.lockPasscode), findsOneWidget);
          await tester.tap(find.byKey(Keys.lockBiometric));
          await tester.pump();
          expect(auth.prompts, hasLength(3));
          auth.prompts.last.complete(true);
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.byKey(Keys.openGallery), findsOneWidget);
      },
    );
  }
  testWidgets(
    'capture interrupts initial biometric authentication before session opening',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final key = sodium.crypto.secretBox.keygen();
      final auth = _PendingAuth();
      var opens = 0;
      const path = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(path, (_) {
        opens++;
        return Completer<String>().future;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          path,
          null,
        );
        key.dispose();
      });
      await tester.pumpWidget(
        QuietakeApp(
          store: _CachedStore(sodium, key),
          auth: auth,
          castBackend: FakeCastBackend(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(auth.prompts, hasLength(1));
      void captured(bool value) => ui.channelBuffers.push(
        ScreenPrivacy.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('state', {'captured': value, 'generation': value ? 1 : 2}),
        ),
        (_) {},
      );
      captured(true);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      captured(false);
      await tester.pump();
      auth.prompts.first.complete(true);
      await tester.pump();
      await tester.pump();
      expect(
        opens,
        0,
        reason: 'An interrupted initial prompt must not start a vault session',
      );
      expect(find.byKey(Keys.lockPasscode).hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
