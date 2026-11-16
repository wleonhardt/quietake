import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/session.dart';
import 'package:quietake/sync/backup_screen.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Session session;
  late PrivacyController privacy;

  Future<void> open(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-backup-screen');
      final store = MasterKeyStore(sodium, dir);
      final key = await store.prepareKey();
      await store.commitPasscode(key, 'test-passcode');
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
  }

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          PrivacyScope(controller: privacy, child: child!),
      home: BackupScreen(session: session),
    ),
  );

  testWidgets('a fresh screen offers a check and shows no check time', (
    tester,
  ) async {
    await open(tester);
    await show(tester);
    expect(find.byKey(Keys.backupVerify), findsOneWidget);
    expect(find.byKey(Keys.backupCancel), findsNothing);
    expect(find.byKey(Keys.backupTime), findsNothing);
  });

  for (final current in [true, false]) {
    testWidgets('a finished check shows its time; current=$current', (
      tester,
    ) async {
      await open(tester);
      session.sync.lastVerification = BackupVerificationReport(
        media: 2,
        catalog: true,
        checkedAt: DateTime(2026, 11, 1, 9, 30),
      );
      session.sync.verificationCurrent = current;
      await show(tester);
      final text = tester.widget<Text>(find.byKey(Keys.backupTime)).data!;
      expect(text, startsWith('Checked '));
      expect(
        text,
        endsWith(
          current ? 'Nothing changed since' : 'Changed since; check again',
        ),
      );
    });
  }

  testWidgets('a configured backup not checked for 30 days gets a reminder', (
    tester,
  ) async {
    await open(tester);
    await show(tester);
    expect(find.byKey(Keys.backupStale), findsNothing);
    session.sync.state = SyncState.synced;
    session.sync.lastVerifiedAt = DateTime.now().subtract(
      const Duration(days: 45),
    );
    session.sync.notifyListeners();
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(Keys.backupStale)).data,
      contains('45 days ago'),
    );
    session.sync.lastVerifiedAt = DateTime.now();
    session.sync.notifyListeners();
    await tester.pump();
    expect(find.byKey(Keys.backupStale), findsNothing);
  });
}
