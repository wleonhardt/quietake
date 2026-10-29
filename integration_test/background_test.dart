import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/sync/background_uploads.dart';
import 'package:quietake/sync/sync_settings.dart';

import '../test_support/fake_webdav_server.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'background opt-in stores encrypted credentials and disconnect clears them',
    (tester) async {
      if (!Platform.isAndroid) return;
      final app = await TestApp.unlocked();
      final background = BackgroundUploads();
      await background.reset();
      final dav = await FakeWebDavServer.start();
      try {
        for (final entry in await app.vault.dir.list().toList()) {
          await entry.delete(recursive: true);
        }
        (await app.session.store.restoreFromRecovery(
          app.session.store.exportRecovery(app.vault.masterKeyForTests),
          'background-fixture-passcode',
        )).dispose();
        final input = await File(
          '${(await getTemporaryDirectory()).path}/background.jpg',
        ).writeAsBytes(fixtureBytes('tiny.jpg'));
        final capture = await app.vault.ingestAs(input, 'background.jpg');
        final encrypted = await capture.readAsBytes();
        await SyncSettings(
          url: dav.url.toString(),
          username: dav.username,
          password: dav.password,
        ).save();
        await tester.pumpWidget(app.widget());
        Future<void> tap(Key key) async {
          await tester.pump(const Duration(milliseconds: 500));
          await tester.scrollUntilVisible(
            find.byKey(key),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.byKey(key));
          await tester.pump(const Duration(milliseconds: 500));
        }

        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.byKey(Keys.openGallery));
        final galleryBy = DateTime.now().add(const Duration(seconds: 20));
        while (find.byKey(Keys.gallerySettings).evaluate().isEmpty ||
            tester
                    .widget<IconButton>(find.byKey(Keys.gallerySettings))
                    .onPressed ==
                null) {
          if (DateTime.now().isAfter(galleryBy)) {
            final status = find.byKey(Keys.status).evaluate().isEmpty
                ? null
                : tester.widget<Text>(find.byKey(Keys.status)).data;
            fail(
              'Gallery startup deadline; lock=${find.byKey(Keys.lockUnlock).evaluate().isNotEmpty}; status=$status',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(Keys.gallerySettings));
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(Keys.backgroundUploads))
              .value,
          isFalse,
        );
        await tap(Keys.backgroundUploads);
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(Keys.backgroundMobileData))
              .value,
          isFalse,
        );
        await tap(Keys.settingsSave);
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (app.session.sync.isSyncing ||
            !dav.files.containsKey('quietake.catalog')) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Background enrollment deadline');
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await app.session.sync.sync();
        final config = File(
          '${app.session.store.dir.parent.path}/no_backup/background-backup/connection.enc',
        );
        expect(await config.exists(), isTrue);
        final bytes = await config.readAsBytes();
        expect(
          String.fromCharCodes(bytes),
          isNot(contains(dav.url.toString())),
        );
        expect(String.fromCharCodes(bytes), isNot(contains(dav.password)));
        final settings = await SyncSettings.load();
        expect(settings.backgroundUploads, isTrue);
        expect(settings.mobileData, isFalse);
        await tester.tap(find.byKey(Keys.gallerySettings));
        await tap(Keys.backgroundMobileData);
        await tap(Keys.settingsSave);
        await app.session.sync.sync();
        expect((await SyncSettings.load()).mobileData, isTrue);
        await tester.tap(find.byKey(Keys.gallerySettings));
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(Keys.backgroundMobileData))
              .value,
          isTrue,
        );
        expect(await capture.readAsBytes(), encrypted);
        expect(await app.vault.readAll(capture), fixtureBytes('tiny.jpg'));
        await app.session.sync.disconnect();
        expect(await config.exists(), isFalse);
        expect(await background.status(), 'disabled');
        expect((await SyncSettings.load()).backgroundUploads, isFalse);
        expect(await capture.readAsBytes(), encrypted);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await app.close();
        await background.reset();
        await dav.close();
      }
    },
    skip: !Platform.isAndroid,
  );
}
