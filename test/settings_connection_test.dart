import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/settings/backup_settings_screen.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/fake_webdav_server.dart';

void main() {
  late Directory dir;
  late Session session;
  late FakeWebDavServer server;

  Future<void> open(WidgetTester tester, {SyncSettings? initial}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // flutter_test answers every HTTP request with 400; use the real client.
    HttpOverrides.global = null;
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-settings-conn');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        Directory('${dir.path}/vault')..createSync(),
      );
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, dir),
      );
      server = await FakeWebDavServer.start();
      server.collectionExists = true;
      server.files['a.jpg.shtr'] = [1];
      server.files['b.jpg.shtr'] = [2];
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await session.close();
        await server.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BackupSettingsScreen(
          initial:
              initial ??
              SyncSettings(
                url: server.url.toString(),
                username: server.username,
                password: server.password,
              ),
          session: session,
        ),
      ),
    );
    await tester.pump();
  }

  Future<String> test(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(Keys.settingsTest));
    await tester.tap(find.byKey(Keys.settingsTest));
    await tester.pump();
    for (var i = 0; i < 100; i++) {
      final text = tester.widget<Text>(find.byKey(Keys.settingsResult)).data!;
      if (text != 'Testing connection…') return text;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    fail('connection test did not finish');
  }

  Future<void> type(WidgetTester tester, Key key, String value) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.enterText(find.byKey(key), value);
  }

  testWidgets('a reachable NAS reports its file count', (tester) async {
    await open(tester);
    expect(await test(tester), 'Connected · 2 files');
  });

  testWidgets('wrong credentials name the HTTP status, not the URL', (
    tester,
  ) async {
    await open(tester);
    await type(tester, Keys.settingsPass, 'wrong');
    final result = await test(tester);
    expect(result, contains('HTTP 401'));
    expect(result, isNot(contains('127.0.0.1')));
  });

  testWidgets('a plain HTTP remote host is refused with a clear reason', (
    tester,
  ) async {
    await open(tester);
    await type(tester, Keys.settingsUrl, 'http://nas.example/vault/');
    expect(await test(tester), 'Use an HTTPS WebDAV folder URL');
  });

  testWidgets('an unreachable NAS says to check the URL and Wi-Fi', (
    tester,
  ) async {
    await open(tester);
    await tester.runAsync(() => server.close());
    expect(await test(tester), contains('Could not reach NAS'));
  });

  testWidgets('checking a backup requires saving edited connection details', (
    tester,
  ) async {
    await open(tester);
    await type(tester, Keys.settingsUser, 'someone-else');
    await tester.ensureVisible(find.byKey(Keys.backupOpen));
    await tester.tap(find.byKey(Keys.backupOpen));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(Keys.settingsResult)).data,
      'Save connection changes before checking backup.',
    );
  });
}
