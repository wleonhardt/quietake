import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/settings/settings_screen.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/trash_setting.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Session session;

  Future<void> open(WidgetTester tester, {bool trashOne = false}) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-keep-deleted');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        dir,
      );
      final plain = await File('${dir.path}/input').writeAsBytes([1, 2, 3]);
      final file = await vault.ingestAs(plain, '2026-11-03T10-00-00.000Z.jpg');
      if (trashOne) await vault.trash(file);
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
        home: SettingsScreen(
          initial: const SyncSettings(url: '', username: '', password: ''),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('keeping deleted captures is on until the owner turns it off', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(Keys.settingsKeepDeleted));
    expect(
      tester.widget<SwitchListTile>(find.byKey(Keys.settingsKeepDeleted)).value,
      isTrue,
    );
    expect(await tester.runAsync(TrashSetting.load), isTrue);

    await tester.tap(find.byKey(Keys.settingsKeepDeleted));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byKey(Keys.settingsKeepDeleted)).value,
      isFalse,
    );
    expect(await tester.runAsync(TrashSetting.load), isFalse);
  });

  testWidgets('Storage counts captures in Recently deleted', (tester) async {
    await open(tester, trashOne: true);
    await tester.ensureVisible(find.byKey(Keys.settingsStorage));
    for (var i = 0; i < 100; i++) {
      final shown = tester.widget<Text>(find.byKey(Keys.settingsStorage)).data;
      if (shown != null && !shown.startsWith('Counting')) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    final text = tester.widget<Text>(find.byKey(Keys.settingsStorage)).data!;
    expect(text, contains('1 in Recently deleted'));
    expect(text, contains('30 days'));
  });
}
