import '../test_support/library_controls.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/sync/sync_settings.dart';

import '../test_support/fake_webdav_server.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> until(WidgetTester tester, bool Function() ready) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) fail('Library recovery deadline');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await revealLibraryControl(tester, key);
    await until(tester, () => find.byKey(key).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> seed(TestApp app) async {
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    final plain = await File(
      '${(await getTemporaryDirectory()).path}/library-photo.jpg',
    ).writeAsBytes(fixtureBytes('tiny.jpg'));
    await app.vault.ingestAs(plain, '2099-recovery.jpg');
  }

  testWidgets(
    'corrupt metadata preserves originals and retry restores organization',
    (tester) async {
      final app = await TestApp.unlocked();
      await seed(app);
      final id = await app.vault.catalog.createAlbum('Saved album');
      final intact = await app.vault.catalog.file.readAsBytes();
      await app.vault.catalog.file.writeAsBytes([1, 2, 3]);
      try {
        await tester.pumpWidget(app.widget());
        await tap(tester, Keys.openGallery);
        await until(
          tester,
          () => find.byKey(Keys.libraryRetry).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.galleryTile(0));
        await until(
          tester,
          () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
        );
        expect(
          tester.widget<IconButton>(find.byKey(Keys.viewerFavorite)).onPressed,
          isNull,
        );
        await until(
          tester,
          () =>
              ModalRoute.of(tester.element(find.byKey(Keys.viewerPhoto)))!
                  .animation!
                  .status ==
              AnimationStatus.completed,
        );
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        expect(await app.vault.catalog.file.readAsBytes(), [1, 2, 3]);
        await app.vault.catalog.file.writeAsBytes(intact);
        await tap(tester, Keys.libraryRetry);
        await until(
          tester,
          () => find.byKey(Keys.libraryRetry).evaluate().isEmpty,
        );
        expect(app.vault.catalog.albums, {id: 'Saved album'});
        expect(await app.vault.list(), hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        await app.close();
      }
    },
  );
  testWidgets(
    'automatic metadata backup queues newer edits and restores private library',
    (tester) async {
      final app = await TestApp.unlocked();
      final server = await FakeWebDavServer.start();
      TestApp? restored;
      var closed = false;
      Future<void> configure() => SyncSettings(
        url: server.url.toString(),
        username: server.username,
        password: server.password,
      ).save();
      try {
        await seed(app);
        await configure();
        await app.session.sync.sync();
        final started = Completer<void>();
        final release = Completer<void>();
        server.beforeRequest = (request) async {
          // The catalog publishes through a staged MOVE (decision 039).
          if (request.method == 'MOVE' &&
              request.headers
                      .value('Destination')
                      ?.endsWith(PrivateCatalog.fileName) ==
                  true &&
              !started.isCompleted) {
            started.complete();
            await release.future;
          }
        };
        final id = await app.vault.catalog.createAlbum('Before');
        await started.future.timeout(const Duration(seconds: 30));
        await app.vault.catalog.renameAlbum(id, 'After');
        await app.vault.catalog.organize(
          {'2099-recovery.jpg.shtr'},
          albumId: id,
          favorite: true,
        );
        release.complete();
        await until(tester, () => app.session.sync.state == SyncState.synced);
        // Catalog publishes through staged MOVEs (decision 039): one per pass.
        expect(
          server.log.where((e) => e.startsWith('MOVE ')).length,
          greaterThanOrEqualTo(2),
        );
        expect(
          server.files.keys,
          containsAll(['2099-recovery.jpg.shtr', PrivateCatalog.fileName]),
        );
        await app.close();
        closed = true;
        // Same recovery identity, empty development vault: no real NAS is involved.
        for (final entry in await app.vault.dir.list().toList()) {
          await entry.delete(recursive: true);
        }
        restored = await TestApp.unlocked();
        await configure();
        await restored.session.sync.sync();
        await tester.pumpWidget(restored.widget());
        await tap(tester, Keys.openGallery);
        await until(
          tester,
          () => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty,
        );
        expect(restored.vault.catalog.albums, {id: 'After'});
        expect(
          restored.vault.catalog.details('2099-recovery.jpg.shtr').favorite,
          isTrue,
        );
        await tap(tester, Keys.libraryFavorites);
        await tap(tester, Keys.galleryTile(0));
        await until(
          tester,
          () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
        );
        expect(
          tester.widget<IconButton>(find.byKey(Keys.viewerFavorite)).tooltip,
          'Remove favorite',
        );
        expect(
          await restored.vault.readAll((await restored.vault.list()).single),
          fixtureBytes('tiny.jpg'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        if (!closed) await app.close();
        await restored?.close();
        await server.close();
      }
    },
  );
}
