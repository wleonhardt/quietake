import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/sync/sync_settings.dart';

import '../test_support/fake_webdav_server.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestApp app;
  late FakeWebDavServer dav;
  late File photo;
  late List<int> encrypted;

  setUp(() async {
    app = await TestApp.unlocked();
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    final source = await File(
      '${(await getTemporaryDirectory()).path}/backup-seed',
    ).writeAsBytes(fixtureBytes('tiny.jpg'));
    photo = await app.vault.ingestAs(source, 'backup.jpg');
    encrypted = await photo.readAsBytes();
    dav = await FakeWebDavServer.start();
    await SyncSettings(
      url: dav.url.toString(),
      username: dav.username,
      password: dav.password,
    ).save();
  });
  tearDown(() async {
    await app.close();
    await dav.close();
  });

  Future<void> until(WidgetTester tester, bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Backup UI checkpoint timed out');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byKey(key).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> open(WidgetTester tester) async {
    await app.session.sync.sync();
    await tester.pumpWidget(app.widget());
    await until(
      tester,
      () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
    );
    await tap(tester, Keys.openGallery);
    await until(
      tester,
      () => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty,
    );
    await tap(tester, Keys.gallerySettings);
    await until(
      tester,
      () => find.byKey(Keys.backupOpen).evaluate().isNotEmpty,
    );
    await tap(tester, Keys.backupOpen);
    await until(
      tester,
      () =>
          find.byKey(Keys.backupScreen).evaluate().isNotEmpty &&
          !app.session.sync.isSyncing,
    );
  }

  testWidgets(
    'saved backup check is read-only, reports scope and detects damaged bytes',
    (tester) async {
      try {
        await open(tester);
        expect(app.session.sync.label, contains('not verified'));
        dav.log.clear();
        await tap(tester, Keys.backupVerify);
        await until(tester, () => app.session.sync.verificationCurrent);
        expect(
          tester.widget<Text>(find.byKey(Keys.backupResult)).data,
          contains('Verified 1 capture and organization'),
        );
        expect(find.byKey(Keys.backupTime), findsOneWidget);
        expect(
          dav.log.every(
            (line) => line.startsWith('PROPFIND ') || line.startsWith('GET '),
          ),
          isTrue,
        );
        expect(await photo.readAsBytes(), encrypted);
        final bad = [...dav.files['backup.jpg.shtr']!];
        bad[bad.length - 1] ^= 1;
        dav.files['backup.jpg.shtr'] = bad;
        dav.log.clear();
        await tap(tester, Keys.backupVerify);
        await until(tester, () => !app.session.sync.isVerifying);
        expect(app.session.sync.verificationCurrent, isFalse);
        expect(
          tester.widget<Text>(find.byKey(Keys.backupResult)).data,
          contains('Could not verify'),
        );
        expect(dav.files['backup.jpg.shtr'], bad);
        expect(await photo.readAsBytes(), encrypted);
        expect(
          dav.log.every(
            (line) => line.startsWith('PROPFIND ') || line.startsWith('GET '),
          ),
          isTrue,
        );
        expect(
          (await app.vault.dir.list().toList()).whereType<Directory>(),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'manual lock protects active check; cancel and retry retain originals',
    (tester) async {
      (await app.session.store.createWithPasscode('backup-test-passcode'))
          .dispose();
      try {
        await open(tester);
        dav.stalledGets.add('backup.jpg.shtr');
        await tap(tester, Keys.backupVerify);
        await until(
          tester,
          () =>
              app.session.sync.isVerifying &&
              dav.log.any((line) => line == 'GET /vault/backup.jpg.shtr'),
        );
        await tap(tester, Keys.lockNow);
        await until(
          tester,
          () => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty,
        );
        expect(find.byKey(Keys.backupScreen), findsNothing);
        expect(app.session.sync.isVerifying, isTrue);
        await tap(tester, Keys.lockBiometric);
        await until(
          tester,
          () => find.byKey(Keys.backupScreen).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.backupCancel);
        await until(tester, () => !app.session.sync.isVerifying);
        expect(
          tester.widget<Text>(find.byKey(Keys.backupResult)).data,
          contains('cancelled'),
        );
        expect(await photo.readAsBytes(), encrypted);
        expect(dav.files['backup.jpg.shtr'], encrypted);
        dav.stalledGets.clear();
        await tap(tester, Keys.backupVerify);
        await until(tester, () => app.session.sync.verificationCurrent);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'wrong-key folder cannot upload, adopt media or claim verified backup',
    (tester) async {
      final key = app.vault.crypto.generateMasterKey();
      final file = File(
        '${(await getTemporaryDirectory()).path}/foreign-backup',
      );
      final sink = file.openWrite();
      try {
        await sink.addStream(
          app.vault.crypto.encrypt(Stream.value(fixtureBytes('tiny.jpg')), key),
        );
      } finally {
        await sink.close();
        key.dispose();
      }
      final foreign = await file.readAsBytes();
      await file.delete();
      dav.files['foreign.jpg.shtr'] = foreign;
      try {
        await open(tester);
        expect(dav.files, {'foreign.jpg.shtr': foreign});
        expect(await app.vault.list(), hasLength(1));
        expect(
          dav.log.where(
            (line) => line.startsWith('PUT ') || line.startsWith('DELETE '),
          ),
          isEmpty,
        );
        await tap(tester, Keys.backupVerify);
        await until(tester, () => !app.session.sync.isVerifying);
        expect(app.session.sync.verificationCurrent, isFalse);
        expect(await photo.readAsBytes(), encrypted);
        expect(dav.files, {'foreign.jpg.shtr': foreign});
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'authenticated missing media restores and unsaved connection is never checked',
    (tester) async {
      await app.session.sync.sync();
      await photo.delete();
      await app.session.sync.sync();
      expect(await photo.readAsBytes(), encrypted);
      expect(await app.vault.readAll(photo), fixtureBytes('tiny.jpg'));
      try {
        await tester.pumpWidget(app.widget());
        await until(
          tester,
          () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.openGallery);
        await until(
          tester,
          () => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.galleryTile(0));
        await until(
          tester,
          () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        await tap(tester, Keys.gallerySettings);
        await until(
          tester,
          () => find.byKey(Keys.settingsUrl).evaluate().isNotEmpty,
        );
        await tester.enterText(
          find.byKey(Keys.settingsUrl),
          'https://other.example.com/vault/',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));
        dav.log.clear();
        await tap(tester, Keys.backupOpen);
        expect(find.byKey(Keys.backupScreen), findsNothing);
        expect(
          tester.widget<Text>(find.byKey(Keys.settingsResult)).data,
          'Save connection changes before checking backup.',
        );
        expect(dav.log, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
