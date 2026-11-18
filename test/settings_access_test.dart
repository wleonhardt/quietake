import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/backup/portable_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_policy_screen.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/session.dart';
import 'package:quietake/settings/settings_screen.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/fake_webdav_server.dart';

const _passcode = 'test-passcode';

class _FailingStorage extends FlutterSecureStoragePlatform {
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw PlatformException(code: 'unavailable');
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw PlatformException(code: 'unavailable');
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => throw PlatformException(code: 'unavailable');
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => throw PlatformException(code: 'unavailable');
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      throw PlatformException(code: 'unavailable');
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => throw PlatformException(code: 'unavailable');
}

void main() {
  late Directory dir;
  late Session session;
  late PrivacyController privacy;

  Future<void> open(
    WidgetTester tester, {
    int captures = 0,
    SyncSettings initial = const SyncSettings(
      url: 'https://nas.example.com/vault/',
      username: 'u',
      password: 'p',
    ),
    Locale? locale,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-settings-access');
      final store = MasterKeyStore(sodium, dir);
      final key = await store.prepareKey();
      await store.commitPasscode(key, _passcode);
      final vault = Vault(
        VaultCrypto(sodium),
        key,
        Directory('${dir.path}/vault')..createSync(),
      );
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: store,
        randomRemoteNames: false,
      );
      for (var i = 0; i < captures; i++) {
        final input = await File('test_fixtures/tiny.jpg')
            .copy('${dir.path}/in$i.jpg');
        await vault.ingestAs(input, 'p$i.jpg');
      }
    });
    privacy = PrivacyController(onLock: () {});
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      privacy.dispose();
      await tester.runAsync(() async {
        await session.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            PrivacyScope(controller: privacy, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('test.open'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SettingsScreen(initial: initial, session: session),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    // The screen starts file IO while building, so run the push in the real zone.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('test.open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> until(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Storage says an empty vault holds nothing yet', (tester) async {
    await open(tester);
    await until(tester, find.textContaining('on this phone'));
    expect(find.text('No captures on this phone yet.'), findsOneWidget);
  });

  testWidgets('Storage counts captures and their encrypted size', (
    tester,
  ) async {
    await open(tester, captures: 2);
    await until(tester, find.textContaining('on this phone'));
    final text = tester.widget<Text>(find.byKey(Keys.settingsStorage)).data!;
    expect(text, startsWith('2 captures, '));
    expect(text, endsWith(' encrypted on this phone.'));
    expect(text, matches(RegExp(r'^2 captures, \d+(\.\d)? (bytes|KB|MB) enc')));
  });

  testWidgets('Settings follow the device language', (tester) async {
    await open(tester, captures: 2, locale: const Locale('fr'));
    await until(tester, find.textContaining('sur ce téléphone'));
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Confidentialité et accès'), findsOneWidget);
    expect(find.text('Tester la connexion'), findsOneWidget);
    final text = tester.widget<Text>(find.byKey(Keys.settingsStorage)).data!;
    expect(text, startsWith('2 captures, '));
    expect(text, endsWith(' chiffrés sur ce téléphone.'));
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('choosing an idle timeout saves it', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.idleTimeout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 minutes').last);
    await settle(tester);
    expect(privacy.minutes, 15);
  });

  testWidgets('a wrong passcode does not show the recovery key', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.text('Show recovery key'));
    await tester.tap(find.text('Show recovery key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.recoveryPrompt), 'wrong-passcode');
    await tester.tap(find.byKey(Keys.recoveryPromptOk));
    await until(tester, find.text('Wrong passcode. Try again.'));
    expect(find.text('Wrong passcode. Try again.'), findsOneWidget);
    // The message belongs under the button that caused it, not in Backup.
    expect(find.byKey(Keys.settingsRecoveryResult), findsOneWidget);
    expect(find.byKey(Keys.settingsResult), findsNothing);
    expect(find.byKey(Keys.recoveryKeyText), findsNothing);
  });

  testWidgets(
    'the passcode prompt clears the typed passcode when the app pauses',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('Show recovery key'));
      await tester.tap(find.text('Show recovery key'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Keys.recoveryPrompt), 'secret value');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(Keys.recoveryPrompt))
            .controller!
            .text,
        '',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  Future<void> openRecoveryCheck(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(Keys.settingsRecoveryCheck));
    await tester.tap(find.byKey(Keys.settingsRecoveryCheck));
    await tester.pumpAndSettle();
  }

  Future<String> checkRecovery(WidgetTester tester, String typed) async {
    await tester.enterText(find.byKey(Keys.recoveryCheckField), typed);
    await tester.tap(find.byKey(Keys.recoveryCheckOk));
    await tester.pumpAndSettle();
    return tester.widget<Text>(find.byKey(Keys.recoveryCheckResult)).data!;
  }

  testWidgets(
    'Check my recovery key accepts the saved key and rejects others',
    (tester) async {
      await open(tester);
      final saved = session.store.exportRecovery(
        session.vault.masterKeyForTests,
      );
      await openRecoveryCheck(tester);
      expect(await checkRecovery(tester, 'not a key'), contains('not a valid'));
      final other = session.store.exportRecovery(
        session.store.sodium.crypto.secretBox.keygen(),
      );
      expect(await checkRecovery(tester, other), contains('does not match'));
      expect(await checkRecovery(tester, saved), contains('matches'));
      expect(await checkRecovery(tester, saved), isNot(contains('does not')));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(Keys.recoveryCheckField), findsNothing);
    },
  );

  testWidgets('the recovery key check remembers when the key last matched', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(Keys.settingsRecoveryCheck));
    expect(
      tester.widget<Text>(find.byKey(Keys.recoveryCheckStatus)).data,
      contains('Never checked'),
    );
    final saved = session.store.exportRecovery(session.vault.masterKeyForTests);
    await openRecoveryCheck(tester);
    await checkRecovery(tester, 'not a key');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(Keys.recoveryCheckStatus)).data,
      contains('Never checked'),
    );
    await openRecoveryCheck(tester);
    await checkRecovery(tester, saved);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    final status = tester
        .widget<Text>(find.byKey(Keys.recoveryCheckStatus))
        .data!;
    expect(status, contains('Last matched'));
    expect(status, isNot(contains('again')));
    expect(await session.store.loadRecoveryChecked(), isNotNull);
  });

  testWidgets('an old recovery key check asks for another one', (tester) async {
    await open(tester);
    final old = DateTime.now().subtract(const Duration(days: 120));
    FlutterSecureStorage.setMockInitialValues({
      'quietake.recovery_checked': old.toUtc().toIso8601String(),
    });
    await tester.ensureVisible(find.byKey(Keys.settingsRecoveryCheck));
    await openRecoveryCheck(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    final status = tester
        .widget<Text>(find.byKey(Keys.recoveryCheckStatus))
        .data!;
    expect(status, contains('Last matched'));
    expect(status, contains('Check again'));
  });

  testWidgets('the recovery key check clears the typed key when closed', (
    tester,
  ) async {
    await open(tester);
    await openRecoveryCheck(tester);
    await tester.enterText(find.byKey(Keys.recoveryCheckField), 'secret text');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await openRecoveryCheck(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(Keys.recoveryCheckField))
          .controller!
          .text,
      '',
    );
  });

  testWidgets(
    'the recovery key check clears the typed key when the app pauses',
    (tester) async {
      await open(tester);
      await openRecoveryCheck(tester);
      await tester.enterText(
        find.byKey(Keys.recoveryCheckField),
        'secret text',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(Keys.recoveryCheckField))
            .controller!
            .text,
        '',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets('the recovery key check follows the device language', (
    tester,
  ) async {
    await open(tester, locale: const Locale('de'));
    await openRecoveryCheck(tester);
    expect(await checkRecovery(tester, 'kein Schlüssel'), contains('gültig'));
    expect(find.text('Schließen'), findsOneWidget);
  });

  testWidgets(
    'fingerprint or face unlock is off until the passcode turns it on',
    (tester) async {
      await open(tester);
      Future<bool> cached() async =>
          (await tester.runAsync(() => session.store.hasCachedKey))!;
      Finder tile(bool on) => find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.key == Keys.settingsBiometric &&
            w.value == on,
      );
      Future<void> turnOn(String passcode) async {
        await tester.ensureVisible(find.byKey(Keys.settingsBiometric));
        await tester.tap(find.byKey(Keys.settingsBiometric));
        await tester.pumpAndSettle();
        expect(find.text('Turn on'), findsOneWidget);
        await tester.enterText(find.byKey(Keys.recoveryPrompt), passcode);
        await tester.tap(find.byKey(Keys.recoveryPromptOk));
      }

      await until(tester, tile(false));
      expect(tile(false), findsOneWidget);
      expect(await cached(), isFalse);

      await turnOn('not-the-passcode');
      await until(tester, find.text('Wrong passcode. Try again.'));
      expect(find.text('Wrong passcode. Try again.'), findsOneWidget);
      expect(tile(false), findsOneWidget);
      expect(await cached(), isFalse);

      await turnOn(_passcode);
      await until(tester, tile(true));
      expect(tile(true), findsOneWidget);
      expect(find.text('Wrong passcode. Try again.'), findsNothing);
      expect(await cached(), isTrue);

      // Turning it off needs no passcode and removes the copy of the key.
      await tester.tap(find.byKey(Keys.settingsBiometric));
      await until(tester, tile(false));
      expect(tile(false), findsOneWidget);
      expect(await cached(), isFalse);
    },
  );

  testWidgets('the right passcode shows the recovery key', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Show recovery key'));
    await tester.tap(find.text('Show recovery key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.recoveryPrompt), _passcode);
    await tester.tap(find.byKey(Keys.recoveryPromptOk));
    await until(tester, find.byKey(Keys.recoveryKeyText));
    expect(find.byKey(Keys.recoveryKeyText), findsOneWidget);
    await tester.ensureVisible(find.byKey(Keys.recoveryDone));
    await tester.tap(find.byKey(Keys.recoveryDone));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.settingsChangePasscode), findsOneWidget);
  });

  testWidgets('changing the passcode returns with a confirmation', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(Keys.settingsChangePasscode));
    await tester.tap(find.byKey(Keys.settingsChangePasscode));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.currentPasscode), _passcode);
    await tester.enterText(find.byKey(Keys.newPasscode), 'replacement-pass');
    await tester.enterText(
      find.byKey(Keys.confirmPasscode),
      'replacement-pass',
    );
    await tester.tap(find.byKey(Keys.changePasscodeSubmit));
    await until(tester, find.text('Passcode changed'));
    expect(find.text('Passcode changed'), findsOneWidget);
    expect(find.byKey(Keys.changePasscodeSubmit), findsNothing);
    await tester.runAsync(() async {
      final key = await session.store.unlockWithPasscode('replacement-pass');
      key.dispose();
    });
  });

  testWidgets('cancelling disconnect keeps the screen open', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(Keys.settingsDisconnect));
    await tester.tap(find.byKey(Keys.settingsDisconnect));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect NAS backup?'), findsOneWidget);
    await tester.tap(find.byKey(Keys.disconnectCancel));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.settingsChangePasscode), findsOneWidget);
  });

  testWidgets('confirming disconnect leaves the screen', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(Keys.settingsDisconnect));
    await tester.tap(find.byKey(Keys.settingsDisconnect));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Keys.disconnectConfirm));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.settingsChangePasscode), findsNothing);
    expect(find.byKey(const Key('test.open')), findsOneWidget);
  });

  void failSecureStorage() {
    FlutterSecureStoragePlatform.instance = _FailingStorage();
  }

  testWidgets('a failed save reports it and keeps the screen open', (
    tester,
  ) async {
    await open(tester);
    failSecureStorage();
    await tester.ensureVisible(find.byKey(Keys.settingsSave));
    await tester.runAsync(() => tester.tap(find.byKey(Keys.settingsSave)));
    await until(
      tester,
      find.text('Could not save connection details. Try again.'),
    );
    expect(find.byKey(Keys.settingsChangePasscode), findsOneWidget);
  });

  testWidgets('a failed idle timeout save reports it and keeps the old value', (
    tester,
  ) async {
    await open(tester);
    final before = privacy.minutes;
    failSecureStorage();
    await tester.tap(find.byKey(Keys.idleTimeout));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('15 minutes').last));
    await until(
      tester,
      find.text('Could not save privacy settings. Try again.'),
    );
    expect(privacy.minutes, before);
  });

  testWidgets('a failed disconnect reports it and keeps the screen open', (
    tester,
  ) async {
    await open(tester);
    failSecureStorage();
    await tester.ensureVisible(find.byKey(Keys.settingsDisconnect));
    await tester.tap(find.byKey(Keys.settingsDisconnect));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => tester.tap(find.byKey(Keys.disconnectConfirm)));
    await until(
      tester,
      find.text('Could not disconnect NAS backup. Try again.'),
    );
    expect(find.byKey(Keys.settingsChangePasscode), findsOneWidget);
  });

  testWidgets('saving with empty connection details explains what is missing', (
    tester,
  ) async {
    await open(
      tester,
      initial: const SyncSettings(url: '', username: '', password: ''),
    );
    await tester.ensureVisible(find.byKey(Keys.settingsSave));
    await tester.runAsync(() => tester.tap(find.byKey(Keys.settingsSave)));
    await until(tester, find.text('Enter a folder URL, username and password'));
    expect(find.byKey(Keys.settingsChangePasscode), findsOneWidget);
  });

  testWidgets('cancelling the recovery prompt never reads the key', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.text('Show recovery key'));
    await tester.tap(find.text('Show recovery key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.recoveryPrompt), _passcode);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.recoveryPrompt), findsNothing);
    expect(find.byKey(Keys.recoveryKeyText), findsNothing);
  });

  testWidgets('an unreadable keyfile reports it instead of a wrong passcode', (
    tester,
  ) async {
    await open(tester);
    await tester.runAsync(
      () => File('${dir.path}/vault.keyfile.json').delete(),
    );
    await tester.ensureVisible(find.text('Show recovery key'));
    await tester.tap(find.text('Show recovery key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.recoveryPrompt), _passcode);
    await tester.tap(find.byKey(Keys.recoveryPromptOk));
    await until(
      tester,
      find.text('Could not read the recovery key. Try again.'),
    );
    expect(find.byKey(Keys.recoveryKeyText), findsNothing);
  });

  for (final entry in {
    'Portable encrypted backup': () => find.byType(PortableScreen),
    'Privacy policy': () => find.byType(PrivacyPolicyScreen),
    'Licenses': () => find.byType(LicensePage),
  }.entries) {
    testWidgets('${entry.key} opens from Settings', (tester) async {
      await open(tester);
      final row = find.text(entry.key);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(entry.value(), findsOneWidget);
    });
  }

  group('plain launcher icon', () {
    const channel = MethodChannel('quietake/appearance');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    testWidgets('the row is hidden where the platform cannot switch', (
      tester,
    ) async {
      await open(tester);
      await settle(tester);
      expect(find.byKey(Keys.settingsPlainIcon), findsNothing);
    });

    testWidgets('the switch changes the icon and shows the honest warning', (
      tester,
    ) async {
      var neutral = false;
      final calls = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'neutral') return neutral;
        calls.add(call.arguments);
        neutral = call.arguments == true;
        return null;
      });
      await open(tester);
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(Keys.settingsPlainIcon),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('does not hide Quietake'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byKey(Keys.settingsPlainIcon)).value,
        isFalse,
      );
      await tester.tap(find.byKey(Keys.settingsPlainIcon));
      await settle(tester);
      expect(calls, [true]);
      expect(
        tester.widget<SwitchListTile>(find.byKey(Keys.settingsPlainIcon)).value,
        isTrue,
      );
    });

    testWidgets('a failed switch keeps the old state and says so', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'neutral') return false;
        throw PlatformException(code: 'failed');
      });
      await open(tester);
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(Keys.settingsPlainIcon),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(Keys.settingsPlainIcon));
      await settle(tester);
      expect(
        tester.widget<SwitchListTile>(find.byKey(Keys.settingsPlainIcon)).value,
        isFalse,
      );
      expect(find.text('Could not change the app icon.'), findsOneWidget);
    });
  });

  group('rename NAS files', () {
    testWidgets('the action is disabled until a NAS is saved', (tester) async {
      await open(
        tester,
        initial: const SyncSettings(url: '', username: '', password: ''),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(Keys.settingsRenameRemote),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(Keys.settingsRenameRemote))
            .onPressed,
        isNull,
      );
    });

    testWidgets('previews, asks, renames and reports', (tester) async {
      // Widget tests answer every HTTP request with 400 unless overrides are off.
      HttpOverrides.global = null;
      await open(tester, captures: 1);
      late FakeWebDavServer server;
      await tester.runAsync(() async {
        server = await FakeWebDavServer.start();
        FlutterSecureStorage.setMockInitialValues({
          'sync.url': server.url.toString(),
          'sync.username': 'vaultapp',
          'sync.password': 'secret',
        });
        await session.sync.sync();
      });
      addTearDown(() => tester.runAsync(server.close));
      expect(server.files.keys, contains('p0.jpg.shtr'));
      await tester.scrollUntilVisible(
        find.byKey(Keys.settingsRenameRemote),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(Keys.settingsRenameRemote));
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byKey(Keys.renameRemoteConfirm).evaluate().isNotEmpty) break;
        }
      });
      expect(find.textContaining('1 encrypted files'), findsOneWidget);
      expect(server.files.keys, contains('p0.jpg.shtr'));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(Keys.renameRemoteConfirm));
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.text('Renamed 1 files on the NAS.').evaluate().isNotEmpty) {
            break;
          }
        }
      });
      expect(find.text('Renamed 1 files on the NAS.'), findsOneWidget);
      expect(server.files.keys, isNot(contains('p0.jpg.shtr')));
    });
  });
}
