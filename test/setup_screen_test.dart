import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/portable_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/sync/nas_recovery_screen.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/backup_passphrase.dart';
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

class _BrokenRestoreStore extends MasterKeyStore {
  _BrokenRestoreStore(super.sodium, super.dir);
  @override
  Future<SecureKey> restoreFromRecovery(
    String recovery,
    String passcode, {
    bool Function(SecureKey key)? acceptsKey,
    Future<bool> Function(String fingerprint)? confirmFingerprint,
  }) async => throw const FileSystemException('disk full');
}

class _PendingRestoreStore extends MasterKeyStore {
  _PendingRestoreStore(super.sodium, super.dir);
  final pending = Completer<SecureKey>();
  @override
  Future<SecureKey> restoreFromRecovery(
    String recovery,
    String passcode, {
    bool Function(SecureKey key)? acceptsKey,
    Future<bool> Function(String fingerprint)? confirmFingerprint,
  }) => pending.future;
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
  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    // Setup shows the key as words; load the list outside the fake clock.
    TestWidgetsFlutterBinding.ensureInitialized();
    await BackupPassphrase.words();
  });
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
    // The word list was loaded outside the fake clock; let it be handed over.
    await tester.runAsync(BackupPassphrase.words);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('setup and recovery key screens follow the device language', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          store: MasterKeyStore(sodium, dir),
          onUnlocked: (_) => fail('unlocked'),
        ),
      ),
    );
    expect(find.text('Establece un código de acceso'), findsOneWidget);
    expect(find.text('Al menos 6 caracteres'), findsOneWidget);
    await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
    await tester.enterText(find.byKey(Keys.setupConfirm), 'otro-codigo');
    await tester.tap(find.byKey(Keys.setupSubmit));
    await tester.pump();
    expect(find.text('Los códigos de acceso no coinciden'), findsOneWidget);
    expect(find.text('Set a passcode'), findsNothing);
  });

  testWidgets('privacy policy is readable before creating a vault', (
    tester,
  ) async {
    final store = MasterKeyStore(sodium, dir);
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(store: store, onUnlocked: (_) => fail('unlocked')),
      ),
    );
    await tester.enterText(
      find.byKey(Keys.setupPasscode),
      'unfinished-passcode',
    );
    final policy = find.widgetWithText(TextButton, 'Privacy policy');
    expect(policy, findsOneWidget);
    await tester.ensureVisible(policy);
    await tester.tap(policy);
    await tester.pumpAndSettle();
    expect(find.textContaining('Leonhardt Labs'), findsWidgets);
    expect(find.text('Your vault'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await store.hasKeyfile, isFalse);
      expect(await store.hasCachedKey, isFalse);
    });
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(Keys.setupPasscode)).controller!.text,
      'unfinished-passcode',
    );
    expect(tester.takeException(), isNull);
  });

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
      await tester.ensureVisible(find.byKey(Keys.recoveryDone));
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

  testWidgets('a new vault starts without a saved backup server', (
    tester,
  ) async {
    // Left by an earlier install: the iOS keychain outlives an uninstall.
    await tester.runAsync(
      () => const SyncSettings(
        url: 'https://nas.example.com/vault/',
        username: 'old-user',
        password: 'old-password',
      ).save(),
    );
    final store = MasterKeyStore(sodium, dir);
    SecureKey? unlocked;
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(store: store, onUnlocked: (k) => unlocked = k),
      ),
    );
    await submit(tester);
    await tester.ensureVisible(find.byKey(Keys.recoveryDone));
    await tester.tap(find.byKey(Keys.recoveryDone));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && unlocked == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      expect(unlocked, isNotNull);
      unlocked!.dispose();
      expect((await SyncSettings.load()).isConfigured, isFalse);
    });
  });

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
    await tester.ensureVisible(find.byKey(Keys.recoveryDone));
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

  Future<void> pumpSetup(
    WidgetTester tester,
    MasterKeyStore store, {
    void Function(SecureKey)? onUnlocked,
  }) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          store: store,
          onUnlocked: onUnlocked ?? (_) => fail('unlocked'),
        ),
      ),
    );
  }

  testWidgets('a short or mismatched passcode is rejected before any work', (
    tester,
  ) async {
    final store = MasterKeyStore(sodium, dir);
    await pumpSetup(tester, store);
    await tester.enterText(find.byKey(Keys.setupPasscode), 'short');
    await tester.enterText(find.byKey(Keys.setupConfirm), 'short');
    await tester.tap(find.byKey(Keys.setupSubmit));
    await tester.pump();
    expect(find.text('Passcode needs at least 6 characters'), findsOneWidget);
    await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
    await tester.enterText(find.byKey(Keys.setupConfirm), 'other-passcode');
    await tester.tap(find.byKey(Keys.setupSubmit));
    await tester.pump();
    expect(find.text('Passcodes do not match'), findsOneWidget);
    expect(find.byKey(Keys.recoveryKeyText), findsNothing);
    // The message sits with the fields, above the button, not under the links.
    expect(
      tester.getTopLeft(find.byKey(Keys.setupError)).dy,
      lessThan(tester.getTopLeft(find.byKey(Keys.setupSubmit)).dy),
    );
  });

  testWidgets('the passcode can be shown while typing and hidden again', (
    tester,
  ) async {
    await pumpSetup(tester, MasterKeyStore(sodium, dir));
    bool hidden(Key key) =>
        tester.widget<TextField>(find.byKey(key)).obscureText;
    expect(hidden(Keys.setupPasscode) && hidden(Keys.setupConfirm), isTrue);
    await tester.tap(find.byKey(Keys.setupShowPasscode));
    await tester.pump();
    expect(hidden(Keys.setupPasscode) || hidden(Keys.setupConfirm), isFalse);
    expect(find.byTooltip('Hide passcode'), findsOneWidget);
    await tester.tap(find.byKey(Keys.setupShowPasscode));
    await tester.pump();
    expect(hidden(Keys.setupPasscode) && hidden(Keys.setupConfirm), isTrue);
  });

  testWidgets('the restore toggle switches forms and back', (tester) async {
    final store = MasterKeyStore(sodium, dir);
    await pumpSetup(tester, store);
    expect(find.byKey(Keys.setupRecoveryKey), findsNothing);
    await tester.tap(find.byKey(Keys.setupToggleRestore));
    await tester.pump();
    expect(find.byKey(Keys.setupRecoveryKey), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    await tester.tap(find.byKey(Keys.setupToggleRestore));
    await tester.pump();
    expect(find.byKey(Keys.setupRecoveryKey), findsNothing);
    expect(find.text('Create vault'), findsOneWidget);
  });

  testWidgets('a malformed recovery key shows an error and stays open', (
    tester,
  ) async {
    final store = MasterKeyStore(sodium, dir);
    await pumpSetup(tester, store);
    await tester.tap(find.byKey(Keys.setupToggleRestore));
    await tester.pump();
    await tester.enterText(find.byKey(Keys.setupRecoveryKey), 'not a key');
    await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
    await tester.enterText(find.byKey(Keys.setupConfirm), 'test-passcode');
    await tester.tap(find.byKey(Keys.setupSubmit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.setupError), findsOneWidget);
    expect(find.byKey(Keys.setupSubmit), findsOneWidget);
    await tester.runAsync(() async => expect(await store.hasKeyfile, isFalse));
  });

  testWidgets('typed words can be shown, and a wrong word is named', (
    tester,
  ) async {
    final store = MasterKeyStore(sodium, dir);
    await pumpSetup(tester, store);
    await tester.tap(find.byKey(Keys.setupToggleRestore));
    await tester.pump();
    TextField field() =>
        tester.widget<TextField>(find.byKey(Keys.setupRecoveryKey));
    expect(field().obscureText, isTrue);
    await tester.tap(find.byKey(Keys.recoveryFieldShow));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(field().maxLines, 4);
    await tester.enterText(
      find.byKey(Keys.setupRecoveryKey),
      'abacus quietake ${List.filled(19, 'abacus').join(' ')}',
    );
    await submit(tester);
    expect(
      find.text('Word 2 is not in the word list. Check its spelling.'),
      findsOneWidget,
    );
    await tester.runAsync(() async => expect(await store.hasKeyfile, isFalse));
  });

  testWidgets('a storage failure while restoring shows a retry message', (
    tester,
  ) async {
    await pumpSetup(tester, _BrokenRestoreStore(sodium, dir));
    await tester.tap(find.byKey(Keys.setupToggleRestore));
    await tester.pump();
    await tester.enterText(find.byKey(Keys.setupRecoveryKey), 'any key');
    await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
    await tester.enterText(find.byKey(Keys.setupConfirm), 'test-passcode');
    await tester.tap(find.byKey(Keys.setupSubmit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Could not restore the vault. Check storage and try again.'),
      findsOneWidget,
    );
    expect(find.byKey(Keys.setupSubmit), findsOneWidget);
  });

  group('restoring into an empty vault asks for fingerprint confirmation', () {
    Future<String> recoveryKey(WidgetTester tester, MasterKeyStore store) =>
        tester
            .runAsync(() async {
              final key = await store.prepareKey();
              final r = store.exportRecovery(key);
              key.dispose();
              return r;
            })
            .then((r) => r!);

    Future<void> restore(WidgetTester tester, String recovery) async {
      await tester.tap(find.byKey(Keys.setupToggleRestore));
      await tester.pump();
      await tester.enterText(find.byKey(Keys.setupRecoveryKey), recovery);
      await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
      await tester.enterText(find.byKey(Keys.setupConfirm), 'test-passcode');
      await tester.tap(find.byKey(Keys.setupSubmit));
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byKey(Keys.setupFingerprint).evaluate().isNotEmpty) break;
        }
      });
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('rejecting the fingerprint saves nothing', (tester) async {
      final store = MasterKeyStore(sodium, dir);
      await pumpSetup(tester, store);
      await restore(tester, await recoveryKey(tester, store));
      expect(find.byKey(Keys.setupFingerprint), findsOneWidget);
      await tester.tap(find.byKey(Keys.setupFingerprintReject));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(Keys.setupFingerprint), findsNothing);
      expect(find.byKey(Keys.setupError), findsOneWidget);
      await tester.runAsync(
        () async => expect(await store.hasKeyfile, isFalse),
      );
    });

    testWidgets('confirming the fingerprint unlocks and persists', (
      tester,
    ) async {
      final store = MasterKeyStore(sodium, dir);
      SecureKey? unlocked;
      await pumpSetup(tester, store, onUnlocked: (k) => unlocked = k);
      await restore(tester, await recoveryKey(tester, store));
      await tester.tap(find.byKey(Keys.setupFingerprintConfirm));
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && unlocked == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
        expect(unlocked, isNotNull);
        expect(await store.hasKeyfile, isTrue);
        unlocked!.dispose();
      });
    });
  });

  testWidgets('restore entry points open the ZIP and NAS restore screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MasterKeyStore(sodium, dir);
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          store: store,
          onUnlocked: (_) => fail('unlocked'),
          onRestored: () => fail('restored'),
        ),
      ),
    );
    await tester.tap(find.byKey(Keys.portableRestoreOpen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PortableScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(PortableScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.nasRestoreOpen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NasRecoveryScreen), findsOneWidget);
  });

  testWidgets(
    'a finished ZIP or NAS restore closes its screen and tells Setup',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MasterKeyStore(sodium, dir);
      var restored = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(
            store: store,
            onUnlocked: (_) => fail('unlocked'),
            onRestored: () => restored++,
          ),
        ),
      );
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tester.tap(find.byKey(Keys.portableRestoreOpen));
      await settle();
      tester.widget<PortableScreen>(find.byType(PortableScreen)).onRestored!();
      await settle();
      expect(restored, 1);
      expect(find.byType(PortableScreen), findsNothing);

      await tester.tap(find.byKey(Keys.nasRestoreOpen));
      await settle();
      tester
          .widget<NasRecoveryScreen>(find.byType(NasRecoveryScreen))
          .onRestored!();
      await settle();
      expect(restored, 2);
      expect(find.byType(NasRecoveryScreen), findsNothing);
    },
  );

  testWidgets('a restore that finishes after the app was paused is discarded', (
    tester,
  ) async {
    final store = _PendingRestoreStore(sodium, dir);
    var unlocked = 0;
    await pumpSetup(tester, store, onUnlocked: (_) => unlocked++);
    await tester.tap(find.byKey(Keys.setupToggleRestore));
    await tester.pump();
    await tester.enterText(find.byKey(Keys.setupRecoveryKey), 'any key');
    await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
    await tester.enterText(find.byKey(Keys.setupConfirm), 'test-passcode');
    await tester.tap(find.byKey(Keys.setupSubmit));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    store.pending.complete(sodium.crypto.secretBox.keygen());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(unlocked, 0, reason: 'a backgrounded restore must not unlock');
    expect(find.byKey(Keys.setupSubmit), findsOneWidget);
  });
}
