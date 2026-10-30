import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/sync/backup_screen.dart';
import 'package:quietake/session.dart';
import 'package:quietake/settings/settings_screen.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  for (final mode in ['cancel', 'confirm', 'cleanup']) {
    final confirm = mode != 'cancel';
    final configured = mode != 'cleanup';
    testWidgets('NAS $mode fits large text and preserves captures', (
      tester,
    ) async {
      tester.view.physicalSize = confirm
          ? const Size(740, 360)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final privacy = PrivacyController(onLock: () {})..minutes = 0;
      addTearDown(privacy.dispose);
      FlutterSecureStorage.setMockInitialValues({
        'sync.url': 'https://old.example/vault/',
        'sync.username': 'legacy-user',
        'sync.password': 'synthetic-test-password',
        'unrelated': 'preserve-me',
      });
      final settings = configured
          ? const SyncSettings(
              url: 'https://nas.example/vault/',
              username: 'test',
              password: 'synthetic',
            )
          : const SyncSettings(url: '', username: '', password: '');
      await settings.save();
      late Directory dir;
      late Session session;
      late File capture;
      await tester.runAsync(() async {
        final sodium = await SodiumSumoInit.init();
        dir = await Directory.systemTemp.createTemp('quietake-settings');
        final vault = Vault(
          VaultCrypto(sodium),
          sodium.crypto.secretBox.keygen(),
          dir,
        );
        final plain = await File('${dir.path}/input').writeAsBytes([1, 2, 3]);
        capture = await vault.ingestAs(plain, 'photo.jpg');
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
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: quietakeTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: PrivacyScope(controller: privacy, child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SettingsScreen(initial: settings, session: session),
                    ),
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        expect(find.text('Privacy & access').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.byKey(Keys.idleTimeout));
        await tester.tap(find.byKey(Keys.idleTimeout));
        await tester.pumpAndSettle();
        await tester.tap(find.text('15 minutes').last);
        await tester.pumpAndSettle();
        expect(privacy.minutes, 15);
        expect(tester.takeException(), isNull);

        expect(
          tester
              .getSemantics(find.text('Privacy & access'))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        await tester.ensureVisible(find.byKey(Keys.settingsChangePasscode));
        expect(
          find.byKey(Keys.settingsChangePasscode).hitTestable(),
          findsOneWidget,
        );
        final privacyY = tester.getTopLeft(find.text('Privacy & access')).dy;
        final backupY = tester.getTopLeft(find.text('Backup')).dy;
        final recoveryY = tester.getTopLeft(find.text('Recovery & export')).dy;
        expect(privacyY, lessThan(backupY));
        expect(backupY, lessThan(recoveryY));
        for (final heading in ['Backup', 'Recovery & export']) {
          await tester.ensureVisible(find.text(heading));
          expect(
            tester
                .getSemantics(find.text(heading))
                .getSemanticsData()
                .flagsCollection
                .isHeader,
            isTrue,
          );
        }
        await tester.ensureVisible(find.byKey(Keys.settingsUser));
        expect(tester.getSize(find.byKey(Keys.settingsSave)).width,
          tester.getSize(find.byKey(Keys.settingsTest)).width);
        expect(tester.getSize(find.byKey(Keys.settingsSave)).width,
          tester.getSize(find.byKey(Keys.settingsUrl)).width);
        expect(
          tester.getSize(find.byKey(Keys.settingsUrl)).width,
          lessThanOrEqualTo(600),
        );
        expect(
          tester.getTopLeft(find.byKey(Keys.settingsUser)).dy -
              tester.getBottomLeft(find.byKey(Keys.settingsUrl)).dy,
          greaterThanOrEqualTo(16),
        );
        expect(
          tester.getTopLeft(find.byKey(Keys.settingsPass)).dy -
              tester.getBottomLeft(find.byKey(Keys.settingsUser)).dy,
          greaterThanOrEqualTo(16),
        );
        final backup = find.byKey(Keys.backupOpen);
        await tester.ensureVisible(backup);
        expect(
          find.descendant(
            of: backup,
            matching: find.text('Check saved backup'),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<OutlinedButton>(backup).onPressed != null,
          configured,
        );
        for (final guideline in [
          androidTapTargetGuideline,
          iOSTapTargetGuideline,
          labeledTapTargetGuideline,
          textContrastGuideline,
        ]) {
          await expectLater(tester, meetsGuideline(guideline));
        }
        if (configured) {
          await tester.tap(backup);
          await tester.pumpAndSettle();
          expect(find.byType(BackupScreen), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        for (final key in [
          Keys.settingsRecovery,
          Keys.nasRecoveryOpen,
          Keys.portableExportOpen,
        ]) {
          await tester.ensureVisible(find.byKey(key));
          expect(find.byKey(key).hitTestable(), findsOneWidget);
        }
        if (!configured) {
          final licenses = find.byKey(Keys.settingsLicenses);
          expect(licenses, findsOneWidget);
          await tester.ensureVisible(licenses);
          await tester.tap(licenses);
          await tester.pumpAndSettle();
          expect(find.byType(LicensePage), findsOneWidget);
          final effLicense = find.widgetWithText(ListTile, 'EFF Long Wordlist');
          await tester.scrollUntilVisible(
            effLicense,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(effLicense, findsOneWidget);
          await tester.tap(effLicense);
          await tester.pumpAndSettle();
          expect(find.textContaining('CC BY 4.0'), findsWidgets);
          expect((await SyncSettings.load()).isConfigured, isFalse);
          await tester.pageBack();
          await tester.pumpAndSettle();
          if (find.byType(SettingsScreen).evaluate().isEmpty) {
            await tester.pageBack();
            await tester.pumpAndSettle();
          }
          expect(find.byType(SettingsScreen), findsOneWidget);
        }
        final disconnect = find.text(
          configured ? 'Disconnect NAS backup' : 'Clear saved NAS details',
        );
        await tester.scrollUntilVisible(
          disconnect,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(disconnect, findsOneWidget);
        await tester.ensureVisible(disconnect);
        await tester.tap(disconnect);
        await tester.pumpAndSettle();
        expect(find.textContaining('Pending NAS deletions'), findsOneWidget);
        await tester.tap(
          find.text(
            confirm ? (configured ? 'Disconnect' : 'Clear details') : 'Cancel',
          ),
        );
        await tester.pumpAndSettle();
        expect((await SyncSettings.load()).isConfigured, !confirm);
        final storage = await const FlutterSecureStorage().readAll();
        expect(storage['unrelated'], 'preserve-me');
        expect(storage.containsKey('sync.password'), !confirm);
        await tester.runAsync(() async {
          expect(await session.vault.readAll(capture), [1, 2, 3]);
        });
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
