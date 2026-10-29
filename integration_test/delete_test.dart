import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/sync/sync_settings.dart';

import '../test_support/fake_webdav_server.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestApp app;
  late FakeWebDavServer server;
  late SyncSettings settings;

  Iterable<String> mediaOnNas() =>
      server.files.keys.where((name) => name.endsWith('.shtr'));

  setUpAll(() async {
    app = await TestApp.unlocked();
    // Reset only this development test sandbox, including prior deletion decisions.
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    server = await FakeWebDavServer.start();
    settings = SyncSettings(
      url: server.url.toString(),
      username: 'vaultapp',
      password: 'secret',
    );
    await settings.save();
    final temp = await getTemporaryDirectory();
    for (final ext in ['jpg', 'mp4']) {
      final plain = await File('${temp.path}/delete.$ext')
          .writeAsBytes(fixtureBytes('tiny.$ext'));
      await app.vault.ingestAs(
        plain,
        '${ext == 'jpg' ? '2031-02' : '2031-01'}.delete.$ext',
      );
    }
    await app.session.sync.sync();
    expect(mediaOnNas(), hasLength(2));
  });
  tearDownAll(() async {
    await app.close();
    await server.close();
  });

  Future<void> until(WidgetTester tester, bool Function() ready) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Deletion checkpoint timed out');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await until(tester, () => find.byKey(key).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openGallery(WidgetTester tester) async {
    await tester.pumpWidget(app.widget());
    await tap(tester, Keys.openGallery);
    await until(
      tester,
      () => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty,
    );
  }

  const delete = Keys.viewerDelete;
  const confirm = Keys.deleteConfirm;
  const cancel = Keys.deleteCancel;

  testWidgets(
    'photo deletion requires confirmation and continues to the next item',
    (tester) async {
      final photo = (await app.vault.list()).first;
      await openGallery(tester);
      await tap(tester, Keys.galleryTile(0));
      await until(
        tester,
        () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
      );
      expect(find.byKey(delete), findsOneWidget);
      await tap(tester, delete);
      expect(find.text('Delete from phone and NAS?'), findsOneWidget);
      await tap(tester, cancel);
      expect(await app.vault.list(), hasLength(2));
      expect(mediaOnNas(), hasLength(2));
      expect(server.log.where((line) => line.startsWith('DELETE')), isEmpty);
      await tap(tester, delete);
      await tap(tester, confirm);
      await until(
        tester,
        () =>
            find.byKey(Keys.viewerPosition).evaluate().isNotEmpty &&
            tester.widget<Text>(find.byKey(Keys.viewerPosition)).data ==
                '1 / 1',
      );
      await until(tester, () => !app.session.sync.isSyncing);
      expect(await photo.exists(), isFalse);
      expect(await app.vault.list(), hasLength(1));
      expect(mediaOnNas(), hasLength(1));
      await app.session.sync.sync();
      expect(await app.vault.list(), hasLength(1));
      await tester.pageBack();
      await until(
        tester,
        () =>
            find.byKey(Keys.galleryTile(0)).hitTestable().evaluate().isNotEmpty,
      );
      expect(find.byKey(Keys.galleryTile(0)), findsOneWidget);
      expect(find.byKey(Keys.galleryTile(1)), findsNothing);
    },
  );

  testWidgets(
    'deleting the playing video stops casting and shows an empty vault',
    (tester) async {
      final video = (await app.vault.list()).single;
      await openGallery(tester);
      await tap(tester, Keys.galleryTile(0));
      await until(
        tester,
        () => find.byKey(Keys.viewerPlay).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.viewerCast);
      await tap(tester, Keys.castDevice(0));
      await until(tester, () => app.session.cast.isCasting);
      await tap(tester, delete);
      await tap(tester, confirm);
      await until(
        tester,
        () => find.byKey(Keys.galleryEmpty).evaluate().isNotEmpty,
      );
      await until(tester, () => !app.session.sync.isSyncing);
      expect(await video.exists(), isFalse);
      expect(await app.vault.list(), isEmpty);
      expect(server.files.keys, ['quietake.catalog']);
      expect(app.session.cast.isCasting, isFalse);
      expect(app.backend.connected, isNull);
      expect(app.session.cast.lastUrl, isNull);
    },
  );

  testWidgets(
    'offline NAS deletion stays pending and retries after reopening',
    (tester) async {
      final temp = await getTemporaryDirectory();
      final plain = await File('${temp.path}/offline.jpg')
          .writeAsBytes(fixtureBytes('tiny.jpg'));
      final photo = await app.vault.ingestAs(plain, '2032-offline.jpg');
      await app.session.sync.sync();
      await SyncSettings(
        url: settings.url,
        username: settings.username,
        password: 'wrong',
      ).save();
      await openGallery(tester);
      await tap(tester, Keys.galleryTile(0));
      await tap(tester, delete);
      await tap(tester, confirm);
      await until(
        tester,
        () => find.byKey(Keys.galleryEmpty).evaluate().isNotEmpty,
      );
      await until(tester, () => !app.session.sync.isSyncing);
      expect(app.session.sync.state, SyncState.pending);
      expect(app.session.sync.label, 'NAS update pending');
      expect(await photo.exists(), isFalse);
      expect(mediaOnNas(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await app.close();
      app = await TestApp.unlocked();
      await settings.save();
      await app.session.sync.sync();
      await tester.pumpWidget(app.widget());
      await tap(tester, Keys.openGallery);
      await until(
        tester,
        () => find.byKey(Keys.galleryEmpty).evaluate().isNotEmpty,
      );
      expect(app.session.sync.state, SyncState.synced);
      expect(server.files.keys, ['quietake.catalog']);
      expect(await app.vault.list(), isEmpty);
    },
  );

  testWidgets(
    'repeated deletion shows next, then previous, then empty gallery',
    (tester) async {
      final temp = await getTemporaryDirectory();
      for (var i = 0; i < 4; i++) {
        final plain = await File('${temp.path}/sequence.jpg')
            .writeAsBytes(fixtureBytes('tiny.jpg'));
        await app.vault.ingestAs(plain, '2040-0$i.jpg');
      }
      await app.session.sync.sync();
      final originals = await app.vault.list();
      await openGallery(tester);
      await tap(tester, Keys.galleryTile(1));
      for (final index in [1, 2, 3, 0]) {
        await tap(tester, delete);
        await tap(tester, confirm);
        await until(tester, () => !originals[index].existsSync());
        await until(tester, () => !app.session.sync.isSyncing);
        expect(await originals[index].exists(), isFalse);
        final remaining = await app.vault.list();
        expect(mediaOnNas(), hasLength(remaining.length));
        if (remaining.isNotEmpty) {
          final position =
              '${remaining.length > 1 ? 2 : 1} / ${remaining.length}';
          await until(
            tester,
            () =>
                find.byKey(Keys.viewerPosition).evaluate().isNotEmpty &&
                tester.widget<Text>(find.byKey(Keys.viewerPosition)).data ==
                    position &&
                tester.widget<IconButton>(find.byKey(delete)).onPressed != null,
          );
          expect(find.byKey(Keys.viewerPager), findsOneWidget);
          expect(
            tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
            position,
          );
        } else {
          await until(
            tester,
            () => find.byKey(Keys.galleryEmpty).evaluate().isNotEmpty,
          );
          expect(find.byKey(Keys.galleryEmpty), findsOneWidget);
        }
      }
      await app.session.sync.sync();
      expect(await app.vault.list(), isEmpty);
      expect(server.files.keys, ['quietake.catalog']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deletion follows confirmed capture while paging finishes', (
    tester,
  ) async {
    for (final file in await app.vault.list()) {
      await app.session.sync.delete(file);
    }
    await app.session.sync.sync();
    final temp = await getTemporaryDirectory();
    for (var i = 0; i < 2; i++) {
      final plain = await File('${temp.path}/paging-delete.jpg')
          .writeAsBytes(fixtureBytes('tiny.jpg'));
      await app.vault.ingestAs(plain, '2050-0$i.jpg');
    }
    final originals = await app.vault.list();
    await openGallery(tester);
    await tap(tester, Keys.galleryTile(0));
    final pager = tester
        .widget<PageView>(find.byKey(Keys.viewerPager))
        .controller!;
    await tester.tap(find.byKey(delete));
    await tester.pump(const Duration(milliseconds: 500));
    // Finish an already queued page movement behind the confirmation sheet.
    pager.jumpToPage(1);
    await tester.pump();
    await tap(tester, confirm);
    await until(
      tester,
      () =>
          find.byKey(Keys.viewerPosition).evaluate().isNotEmpty &&
          tester.widget<Text>(find.byKey(Keys.viewerPosition)).data ==
              '1 / 1' &&
          tester.widget<IconButton>(find.byKey(delete)).onPressed != null,
    );
    expect(await originals.first.exists(), isFalse);
    expect(await originals.last.exists(), isTrue);
    expect(tester.widget<Text>(find.byKey(Keys.viewerPosition)).data, '1 / 1');
    await tap(tester, delete);
    await tap(tester, confirm);
    await until(
      tester,
      () => find.byKey(Keys.galleryEmpty).evaluate().isNotEmpty,
    );
    expect(await originals.last.exists(), isFalse);
    expect(find.byKey(Keys.galleryEmpty), findsOneWidget);
  });
}
