import '../test_support/integration_binding.dart';
import '../test_support/library_controls.dart';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/main.dart';
import 'package:quietake/vault/vault.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'harness.dart';

import '../test_support/fake_webdav_server.dart';
import '../test_support/fake_authenticator.dart';

/// NAS sync through the real UI against an in-process WebDAV server on
/// loopback: configure in Settings, test, save, sync, lose the local copy,
/// sync again and get it back.
void main() {
  initializeIntegrationBinding();

  late TestApp app;
  late Vault vault;
  late FakeWebDavServer dav;

  setUpAll(() async {
    app = await TestApp.unlocked();
    vault = app.vault;
    dav = await FakeWebDavServer.start();
    for (final f in await vault.list()) {
      await f.delete();
    }
    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/seed.bin')
      ..writeAsBytesSync(List.filled(70000, 7));
    await vault.ingestAs(f, '2026-03.seed.jpg');
  });

  tearDownAll(() async {
    await dav.close();
    await app.close();
  });

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(end)) {
        final r = find.byKey(Keys.settingsResult).evaluate().isEmpty
            ? 'absent'
            : tester.widget<Text>(find.byKey(Keys.settingsResult)).data;
        fail('timed out after $timeout; result=$r; server log=${dav.log}');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String text(WidgetTester tester, Key k) =>
      tester.widget<Text>(find.byKey(k)).data!;

  String backupLabel(WidgetTester tester) =>
      tester.widget<Tooltip>(find.byKey(Keys.captureBackup)).message!;

  /// Lets a page transition finish. iOS slides new routes in from the right
  /// over ~400 ms, so a tap right after the finder appears lands off-screen.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 500));

  /// Types into a field and checks the controller took it. On the iOS
  /// simulator a second entry into an already-filled obscured field is
  /// overwritten by the platform echoing the old value back, so fall back to
  /// the controller there; Android stays on the pure UI path.
  Future<void> enter(WidgetTester tester, Key k, String value) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    if (find.byKey(k).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(k), -100, scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.byKey(k));
    await tester.enterText(find.byKey(k), value);
    await tester.pump();
    final controller = tester.widget<TextField>(find.byKey(k)).controller!;
    if (controller.text != value) {
      debugPrint(
        'enterText into $k dropped on ${Platform.operatingSystem}; using controller',
      );
      controller.text = value;
      await tester.pump();
    }
    expect(controller.text, value);
  }

  /// Drops keyboard focus, lets layout settle, scrolls the target into view
  /// and taps it.
  Future<void> tap(WidgetTester tester, Key k) async {
    await revealLibraryControl(tester, k);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.ensureVisible(find.byKey(k));
    await tester.pump();
    await tester.tap(find.byKey(k));
    await tester.pump();
  }

  testWidgets('configure, sync up, sync down', (tester) async {
    await tester.pumpWidget(app.widget());
    await pumpUntil(
      tester,
      () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
    );
    await tap(tester, Keys.openGallery);
    await pumpUntil(
      tester,
      () => find.byKey(Keys.gallerySettings).evaluate().isNotEmpty,
    );

    // Settings: wrong password first, then the right one.
    await tap(tester, Keys.gallerySettings);
    await pumpUntil(
      tester,
      () => find.byKey(Keys.settingsUrl).evaluate().isNotEmpty,
    );
    await settle(tester);
    expect(find.byKey(Keys.settingsPrivacySection).hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(Keys.settingsPrivacySection)).dy,
      lessThan(tester.getTopLeft(find.byKey(Keys.settingsBackupSection)).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(Keys.settingsBackupSection)).dy,
      lessThan(tester.getTopLeft(find.byKey(Keys.settingsRecoverySection)).dy),
    );
    await tester.ensureVisible(find.byKey(Keys.backupOpen));
    expect(
      find.descendant(of: find.byKey(Keys.backupOpen), matching: find.text('Check saved backup')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byKey(Keys.settingsUrl)).decoration!.hintText,
      'https://nas.example.com/vault/',
    );
    await enter(tester, Keys.settingsUrl, dav.url.toString());
    await enter(tester, Keys.settingsUser, 'vaultapp');
    await enter(tester, Keys.settingsPass, 'wrong');
    await tap(tester, Keys.settingsTest);
    await pumpUntil(
      tester,
      () =>
          find.byKey(Keys.settingsResult).evaluate().isNotEmpty &&
          text(tester, Keys.settingsResult) != 'Testing connection…',
    );
    expect(text(tester, Keys.settingsResult), contains('HTTP 401'));

    await enter(tester, Keys.settingsPass, 'secret');
    await tap(tester, Keys.settingsTest);
    await pumpUntil(
      tester,
      () => text(tester, Keys.settingsResult).startsWith('Connected'),
    );
    expect(text(tester, Keys.settingsResult), 'Connected · 0 files');
    await tap(tester, Keys.settingsSave);
    await revealLibraryControl(tester, Keys.gallerySync);
    await pumpUntil(
      tester,
      () => find.byKey(Keys.gallerySync).evaluate().isNotEmpty,
    );
    await settle(tester);

    // Saving settings automatically backs up existing captures.
    await pumpUntil(
      tester,
      () =>
          find.byKey(Keys.gallerySyncResult).evaluate().isNotEmpty &&
          text(tester, Keys.gallerySyncResult) != 'Syncing with NAS…',
    );
    expect(
      text(tester, Keys.gallerySyncResult),
      allOf(startsWith('Synced:'), endsWith('1 on NAS')),
    );
    expect(dav.files.keys.toSet(), {
      '2026-03.seed.jpg.shtr',
      'quietake.catalog',
    });
    // Uploads stage under .quietake-upload-* and finish with one MOVE
    // (decision 039); nothing is PUT to the final name.
    expect(
      dav.log.where((line) => line.startsWith('PUT /vault/.quietake-upload-')),
      hasLength(2),
      reason: 'one staged upload for the capture and one for the catalog',
    );
    expect(dav.log.where((line) => line.startsWith('MOVE ')), hasLength(2));
    expect(dav.log, isNot(contains('PUT /vault/2026-03.seed.jpg.shtr')));
    final uploaded = dav.files['2026-03.seed.jpg.shtr']!.length;

    // Lose the local copy, sync down.
    final local = (await vault.list()).single;
    expect(await local.length(), uploaded);
    await local.delete();
    await tap(tester, Keys.gallerySync);
    await pumpUntil(
      tester,
      () =>
          !app.session.sync.isSyncing &&
          text(tester, Keys.gallerySyncResult).startsWith('Synced:'),
    );
    expect(
      text(tester, Keys.gallerySyncResult),
      allOf(startsWith('Synced:'), endsWith('1 on NAS')),
    );
    final back = (await vault.list()).single;
    expect(await back.length(), uploaded);
    expect(
      (await vault.readAll(back)).length,
      70000,
      reason: 'pulled container decrypts',
    );
    await pumpUntil(
      tester,
      () => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty,
    );
  });

  testWidgets('photo and video back up without tapping sync', (tester) async {
    await tester.pumpWidget(app.widget());
    await settle(tester);
    await pumpUntil(
      tester,
      () => find.byKey(Keys.captureBackup).evaluate().isNotEmpty,
    );
    final backup = tester.getRect(find.byKey(Keys.captureBackup));
    final cast = tester.getRect(find.byKey(Keys.captureCast));
    final shutter = tester.getRect(find.byKey(Keys.shutter));
    expect(backup.center.dx, lessThan(shutter.center.dx));
    expect(backup.top, closeTo(cast.top, 1));
    expect(backup.height, lessThanOrEqualTo(48));
    expect(
      find.descendant(
        of: find.byKey(Keys.captureBackup),
        matching: find.byIcon(Icons.cloud_done_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('Synced with NAS · not verified'), findsNothing);
    expect(backupLabel(tester), 'Synced with NAS · not verified');
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        find.bySemanticsLabel('Synced with NAS · not verified'),
        findsOneWidget,
      );
      await tap(tester, Keys.captureBackup);
      await pumpUntil(
        tester,
        () => find.text('Synced with NAS · not verified').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 3),
      );
      expect(find.text('Synced with NAS · not verified'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    } finally {
      semantics.dispose();
    }
    if ((await availableCameras()).isEmpty) {
      await pumpUntil(
        tester,
        () => find.text('No camera').evaluate().isNotEmpty,
      );
      return;
    }
    await pumpUntil(
      tester,
      () => find.byKey(Keys.preview).evaluate().isNotEmpty,
    );
    final before = dav.files.length;
    await tap(tester, Keys.shutter);
    await pumpUntil(
      tester,
      () =>
          dav.files.length == before + 1 &&
          backupLabel(tester) == 'Synced with NAS · not verified',
    );
    await tap(tester, Keys.videoToggle);
    await pumpUntil(
      tester,
      () => find.byKey(Keys.captureRecordingFrame).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 2));
    await tap(tester, Keys.videoToggle);
    await pumpUntil(
      tester,
      () =>
          dav.files.length == before + 2 &&
          backupLabel(tester) == 'Synced with NAS · not verified',
    );
    expect(
      dav.files.keys.every(
        (name) => name.endsWith('.shtr') || name == 'quietake.catalog',
      ),
      isTrue,
    );
    for (final file in await vault.list()) {
      expect(dav.files[file.uri.pathSegments.last], await file.readAsBytes());
      expect(
        await vault.readAll(file), isNotEmpty,
        reason: file.uri.pathSegments.last,
      );
    }
  });

  testWidgets('unlock retries a local capture without manual sync', (
    tester,
  ) async {
    const passcode = 'auto-sync-test-passcode';
    (await app.session.store.createWithPasscode(passcode)).dispose();
    final tmp = await getTemporaryDirectory();
    final plain = File('${tmp.path}/retry.jpg');
    await plain.writeAsBytes([255, 216, 255, 7]);
    final local = await vault.ingestAs(plain, '2099-retry.jpg');
    expect(dav.files.containsKey('2099-retry.jpg.shtr'), isFalse);
    await tester.pumpWidget(
      QuietakeApp(
        store: app.session.store,
        auth: FakeAuthenticator(isAvailable: false),
        castBackend: app.backend,
      ),
    );
    await pumpUntil(
      tester,
      () => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty,
    );
    await enter(tester, Keys.lockPasscode, passcode);
    await tap(tester, Keys.lockUnlock);
    await pumpUntil(
      tester,
      () =>
          dav.files.containsKey('2099-retry.jpg.shtr') &&
          find.byKey(Keys.captureBackup).evaluate().isNotEmpty &&
          backupLabel(tester) == 'Synced with NAS · not verified',
    );
    expect(dav.files['2099-retry.jpg.shtr'], await local.readAsBytes());
    expect(await plain.exists(), isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets(
    'disconnect preserves media and pending NAS deletions until reconnect',
    (tester) async {
      await app.session.sync.sync();
      final plain = await File(
        '${(await getTemporaryDirectory()).path}/disconnect.jpg',
      ).writeAsBytes([255, 216, 255, 7]);
      final deleted = await vault.ingestAs(plain, '2099-disconnect-delete.jpg');
      final deletedName = deleted.uri.pathSegments.last;
      dav.files[deletedName] = await deleted.readAsBytes();
      await vault.delete(deleted);
      final journal = await vault.deletedNames();
      final local = {
        for (final file in await vault.list())
          file.path: await file.readAsBytes(),
      };
      final remote = Map<String, List<int>>.from(dav.files);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'sync.url', value: 'https://old.example/vault/');
      await storage.write(key: 'sync.username', value: 'legacy-test');
      await storage.write(
        key: 'sync.password',
        value: 'synthetic-test-password',
      );
      await tester.pumpWidget(app.widget());
      await pumpUntil(
        tester,
        () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.openGallery);
      await pumpUntil(
        tester,
        () => find.byKey(Keys.gallerySettings).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.gallerySettings);
      await pumpUntil(
        tester,
        () => find.byKey(Keys.settingsDisconnect).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.settingsDisconnect);
      await pumpUntil(
        tester,
        () => find.byKey(Keys.disconnectCancel).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.disconnectCancel);
      await settle(tester);
      expect((await SyncSettings.load()).isConfigured, isTrue);
      expect(dav.files, remote);
      await tap(tester, Keys.settingsDisconnect);
      await pumpUntil(
        tester,
        () => find.byKey(Keys.disconnectConfirm).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.disconnectConfirm);
      await pumpUntil(
        tester,
        () => find.byKey(Keys.settingsUrl).evaluate().isEmpty,
      );
      await settle(tester);
      expect((await SyncSettings.load()).isConfigured, isFalse);
      for (final key in ['sync.url', 'sync.username', 'sync.password']) {
        expect(await storage.read(key: key), isNull);
      }
      expect(dav.files, remote);
      expect(await vault.deletedNames(), journal);
      for (final entry in local.entries) {
        expect(await File(entry.key).readAsBytes(), entry.value);
      }
      final requests = dav.log.length;
      await app.session.sync.sync();
      expect(dav.log.length, requests);
      await tap(tester, Keys.gallerySettings);
      await pumpUntil(
        tester,
        () => find.byKey(Keys.settingsUrl).evaluate().isNotEmpty,
      );
      await settle(tester);
      for (final key in [
        Keys.settingsUrl,
        Keys.settingsUser,
        Keys.settingsPass,
      ]) {
        expect(
          tester.widget<TextField>(find.byKey(key)).controller!.text,
          isEmpty,
        );
      }
      expect(find.byKey(Keys.settingsDisconnect), findsOneWidget);
      expect(find.text('Clear saved NAS details'), findsOneWidget);
      await enter(tester, Keys.settingsUrl, dav.url.toString());
      await enter(tester, Keys.settingsUser, 'vaultapp');
      await enter(tester, Keys.settingsPass, 'secret');
      await tap(tester, Keys.settingsSave);
      await pumpUntil(
        tester,
        () =>
            find.byKey(Keys.settingsUrl).evaluate().isEmpty &&
            !app.session.sync.isSyncing &&
            !dav.files.containsKey(deletedName),
      );
      expect(await vault.deletedNames(), journal);
      expect(await deleted.exists(), isFalse);
      expect(await plain.exists(), isFalse);
      for (final entry in local.entries) {
        expect(await File(entry.key).readAsBytes(), entry.value);
      }
    },
  );
}
