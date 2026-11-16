import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/gallery_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/albums_screen.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/gallery/viewer_screen.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/settings/settings_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/library_controls.dart';

class _UnreadableStorage extends FlutterSecureStoragePlatform {
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw PlatformException(code: 'unavailable');
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {}
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => false;
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {}
  @override
  Future<void> deleteAll({required Map<String, String> options}) async {}
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => {};
}

void main() {
  late Directory dir;
  late Session session;

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (done()) return;
    }
    fail('Gallery did not settle');
  }

  Future<void> open(WidgetTester tester, {bool corruptCatalog = false}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-gallery-select');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        dir,
      );
      for (final name in ['a.jpg', 'b.jpg']) {
        final input = await File('test_fixtures/tiny.jpg')
            .copy('${dir.path}/in-$name');
        await vault.ingestAs(input, name);
      }
      if (corruptCatalog) {
        await File('${dir.path}/${PrivateCatalog.fileName}')
            .writeAsBytes([1, 2, 3]);
      }
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
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: GalleryScreen(session: session)),
      );
    });
    await until(
      tester,
      () => find.byKey(Keys.galleryTile(1)).evaluate().isNotEmpty,
    );
  }

  testWidgets('unreadable saved NAS details keep the gallery and explain', (
    tester,
  ) async {
    await open(tester);
    FlutterSecureStoragePlatform.instance = _UnreadableStorage();
    await tester.runAsync(() => tester.tap(find.byKey(Keys.gallerySettings)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      find.text('Could not read saved NAS details. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Select captures from the actions sheet enters selection', (
    tester,
  ) async {
    await open(tester);
    await revealLibraryControl(tester, Keys.librarySelect);
    await tester.tap(find.byKey(Keys.librarySelect));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.byKey(Keys.librarySelectAll));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    // Two selected: no rename button.
    expect(find.byKey(Keys.libraryRename), findsNothing);
  });

  testWidgets('favoriting the selection persists and flips the action', (
    tester,
  ) async {
    await open(tester);
    await tester.longPress(find.byKey(Keys.galleryTile(0)));
    await tester.pump();
    await tester.runAsync(() => tester.tap(find.byKey(Keys.libraryFavorite)));
    await until(
      tester,
      () => session.vault.catalog.items.values.any((d) => d.favorite),
    );
    await tester.pump();
    expect(find.text('Unfavorite'), findsOneWidget);
  });

  testWidgets('naming a single selected capture saves its title', (
    tester,
  ) async {
    await open(tester);
    await tester.longPress(find.byKey(Keys.galleryTile(0)));
    await tester.pump();
    await tester.tap(find.byKey(Keys.libraryRename));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byKey(Keys.libraryName), 'Harbour');
    await tester.runAsync(() => tester.tap(find.byKey(Keys.librarySave)));
    await until(
      tester,
      () => session.vault.catalog.items.values.any((d) => d.title == 'Harbour'),
    );
  });

  testWidgets('Tags in the actions sheet opens the tag manager', (
    tester,
  ) async {
    await open(tester);
    await revealLibraryControl(tester, Keys.libraryAlbums);
    await tester.tap(find.byKey(Keys.libraryAlbums));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.libraryAlbums), findsNothing);
    expect(find.byType(AlbumsScreen), findsOneWidget);
  });

  testWidgets('an unreadable catalog offers retry and disables selection', (
    tester,
  ) async {
    await open(tester, corruptCatalog: true);
    expect(find.byKey(Keys.libraryRetry), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(Keys.librarySelectMode)).onPressed,
      isNull,
    );
    // Originals stay listed.
    expect(find.byKey(Keys.galleryTile(0)), findsOneWidget);
  });

  testWidgets('tapping a tile opens the viewer', (tester) async {
    await open(tester);
    await tester.runAsync(() => tester.tap(find.byKey(Keys.galleryTile(0))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ViewerScreen), findsOneWidget);
  });
}
