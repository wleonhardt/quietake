import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/recently_deleted_screen.dart';
import 'package:quietake/sync/sync_settings.dart';

import '../test_support/integration_binding.dart';
import '../test_support/fake_webdav_server.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  initializeIntegrationBinding();
  late TestApp app;
  late FakeWebDavServer server;

  Iterable<String> mediaOnNas() =>
      server.files.keys.where((name) => name.endsWith('.shtr'));

  setUpAll(() async {
    app = await TestApp.unlocked();
    // Reset only this development test sandbox, including prior deletion decisions.
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    server = await FakeWebDavServer.start();
    await SyncSettings(
      url: server.url.toString(),
      username: 'vaultapp',
      password: 'secret',
    ).save();
    final temp = await getTemporaryDirectory();
    for (final day in ['01', '02', '03']) {
      final plain = await File('${temp.path}/trash.jpg')
          .writeAsBytes(fixtureBytes('tiny.jpg'));
      await app.vault.ingestAs(plain, '2031-02-$day.trash.jpg');
    }
    await app.session.sync.sync();
    expect(mediaOnNas(), hasLength(3));
  });
  tearDownAll(() async {
    await app.close();
    await server.close();
  });

  Future<void> until(WidgetTester tester, bool Function() ready) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) fail('Checkpoint timed out');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await until(tester, () => find.byKey(key).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'Recently deleted keeps the NAS copy, restores, and Delete now removes it',
    (tester) async {
      final victim = (await app.vault.list()).first;
      final name = victim.uri.pathSegments.last;

      // Trash from the viewer.
      await tester.pumpWidget(app.widget());
      await tap(tester, Keys.openGallery);
      await tap(tester, Keys.galleryTile(0));
      await until(
        tester,
        () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.viewerDelete);
      await tap(tester, Keys.deleteTrash);
      await tester.pump(const Duration(seconds: 1));
      expect(await victim.exists(), isTrue);
      expect(await app.vault.list(), hasLength(2));
      expect(mediaOnNas(), hasLength(3));
      await app.session.sync.sync();
      expect(mediaOnNas(), hasLength(3));
      expect(await app.vault.list(), hasLength(2));

      // Restore from the screen.
      await tester.pumpWidget(
        MaterialApp(home: RecentlyDeletedScreen(session: app.session)),
      );
      await tap(tester, Keys.recentlyDeletedItem(name));
      await tap(tester, Keys.recentlyDeletedRestore(name));
      await until(
        tester,
        () => find.byKey(Keys.recentlyDeletedEmpty).evaluate().isNotEmpty,
      );
      expect(await app.vault.list(), hasLength(3));

      // Trash again, then Delete now.
      await app.session.sync.trash(victim);
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: RecentlyDeletedScreen(session: app.session),
        ),
      );
      await tap(tester, Keys.recentlyDeletedNow(name));
      await tap(tester, Keys.recentlyDeletedConfirm);
      await until(
        tester,
        () => find.byKey(Keys.recentlyDeletedEmpty).evaluate().isNotEmpty,
      );
      await until(tester, () => !app.session.sync.isSyncing);
      expect(await victim.exists(), isFalse);
      expect(mediaOnNas(), hasLength(2));
      expect(await app.vault.list(), hasLength(2));
    },
  );
}
