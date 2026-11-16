import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/session.dart';
import 'package:quietake/settings/settings_screen.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

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
    SyncSettings initial = const SyncSettings(
      url: 'https://nas.example.com/vault/',
      username: 'u',
      password: 'p',
    ),
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
      );
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
    await tester.tap(find.byKey(const Key('test.open')));
    await tester.pumpAndSettle();
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
    expect(find.byKey(Keys.recoveryKeyText), findsNothing);
  });

  testWidgets('the right passcode shows the recovery key', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Show recovery key'));
    await tester.tap(find.text('Show recovery key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.recoveryPrompt), _passcode);
    await tester.tap(find.byKey(Keys.recoveryPromptOk));
    await until(tester, find.byKey(Keys.recoveryKeyText));
    expect(find.byKey(Keys.recoveryKeyText), findsOneWidget);
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
}
