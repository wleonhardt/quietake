import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/albums_screen.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Session session;
  late List<String> ids;

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'condition never became true');
  }

  Future<void> open(
    WidgetTester tester, {
    List<String> tags = const [],
    List<List<int>> captures = const [],
    bool vaultMissing = false,
    double textScale = 1,
    Size size = const Size(800, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-albums');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        dir,
      );
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, dir),
      );
      ids = [for (final t in tags) await vault.catalog.createAlbum(t)];
      for (var i = 0; i < captures.length; i++) {
        final source = await File('${dir.path}/input').writeAsBytes([1, 2, 3]);
        final file = await vault.ingestAs(source, 'c$i.jpg');
        await vault.catalog.organize(
          {file.uri.pathSegments.last},
          tagIds: {for (final t in captures[i]) ids[t]},
        );
      }
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await session.close();

        await dir.delete(recursive: true);
      });
    });
    if (vaultMissing) {
      await tester.runAsync(() => dir.rename('${dir.path}-moved'));
    }
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: AlbumsScreen(session: session),
        ),
      );
    });
    if (vaultMissing) return;
    await until(
      tester,
      () => find.byKey(Keys.libraryUntagged).evaluate().isNotEmpty,
    );
  }

  Future<void> menu(WidgetTester tester, String id, String label) async {
    await tester.tap(find.byKey(Keys.albumMenu(id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a vault that cannot be counted offers Retry and recovers', (
    tester,
  ) async {
    await open(tester, tags: ['Trips'], vaultMissing: true);
    final retry = find.text('Could not count captures. Retry');
    await until(tester, () => retry.evaluate().isNotEmpty);
    await tester.runAsync(
      () => Directory('${dir.path}-moved').rename(dir.path),
    );
    await tester.runAsync(() => tester.tap(retry));
    await until(
      tester,
      () => find.byKey(Keys.libraryUntagged).evaluate().isNotEmpty,
    );
    expect(retry, findsNothing);
  });

  testWidgets('tags stay usable at large text on a narrow screen', (
    tester,
  ) async {
    await open(
      tester,
      tags: ['A tag with a rather long name', 'Trips'],
      textScale: 2,
      size: const Size(320, 640),
    );
    expect(find.text('A tag with a rather long name'), findsOneWidget);
    await tester.tap(find.byKey(Keys.albumMenu(ids[0])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rename'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty library offers to create the first tag', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('No tags yet'), findsOneWidget);
    await tester.tap(find.byKey(Keys.albumCreateFirst));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byKey(Keys.libraryName), 'Travel');
    await tester.runAsync(() => tester.tap(find.byKey(Keys.librarySave)));
    await until(tester, () => session.vault.catalog.albums.length == 1);
    expect(session.vault.catalog.albums.values.single, 'Travel');
  });

  testWidgets('searching with no match offers to create that name', (
    tester,
  ) async {
    await open(tester, tags: ['Family']);
    await tester.enterText(find.byKey(Keys.tagSearch), 'Zoo');
    await tester.pump();
    expect(find.text('No matching tags'), findsOneWidget);
    expect(find.text("Create 'Zoo'"), findsOneWidget);
  });

  testWidgets('cancelling tag deletion keeps the tag', (tester) async {
    await open(tester, tags: ['Family']);
    await menu(tester, ids.single, 'Delete tag');
    expect(find.text('Delete tag?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(session.vault.catalog.albums.length, 1);
  });

  testWidgets('tags can be sorted by capture count and back by name', (
    tester,
  ) async {
    await open(
      tester,
      tags: ['Alpha', 'Mid', 'Zulu'],
      captures: [
        [2],
        [2],
        [0],
      ],
    );
    double top(String tag) => tester.getTopLeft(find.text(tag)).dy;
    expect(top('Alpha') < top('Mid') && top('Mid') < top('Zulu'), isTrue);

    await tester.tap(find.byKey(Keys.albumSort));
    await tester.pump();
    expect(top('Zulu') < top('Alpha') && top('Alpha') < top('Mid'), isTrue);
    expect(find.byTooltip('Sort by name'), findsOneWidget);

    await tester.tap(find.byKey(Keys.albumSort));
    await tester.pump();
    expect(top('Alpha') < top('Mid') && top('Mid') < top('Zulu'), isTrue);
  });
}
