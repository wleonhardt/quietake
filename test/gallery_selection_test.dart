import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:quietake/sync/sync_controller.dart';
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

  Future<void> open(
    WidgetTester tester, {
    bool corruptCatalog = false,
    bool vaultMissing = false,
    List<String> names = const ['a.jpg', 'b.jpg'],
    DateTime? month,
  }) async {
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
      for (final name in names) {
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
    if (vaultMissing) {
      await tester.runAsync(() => dir.rename('${dir.path}-moved'));
    }
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: month == null
              ? GalleryScreen(session: session)
              : GalleryScreen(
                  session: session,
                  searchMode: true,
                  initialMonth: month,
                ),
        ),
      );
    });
    if (vaultMissing) return;
    await until(
      tester,
      () => find
          .byKey(Keys.galleryTile(month == null ? 1 : 0))
          .evaluate()
          .isNotEmpty,
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

  testWidgets('Add tags then Remove tags change the selected capture', (
    tester,
  ) async {
    await open(tester);
    final catalog = session.vault.catalog;
    final tag = (await tester.runAsync(() => catalog.createAlbum('Harbour')))!;
    await tester.longPress(find.byKey(Keys.galleryTile(0)));
    await tester.pump();
    Future<void> apply(Key action) async {
      // The handler's continuation does file IO, so it must start in the real zone.
      await tester.runAsync(() => tester.tap(find.byKey(action)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Keys.albumChoose(tag)));
      await tester.pump();
      await tester.tap(find.byKey(Keys.tagPickerApply));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await apply(Keys.libraryAddAlbum);
    await until(
      tester,
      () =>
          catalog.items.values.where((d) => d.albums.contains(tag)).length == 1,
    );
    await apply(Keys.libraryRemoveAlbum);
    await until(
      tester,
      () => catalog.items.values.every((d) => !d.albums.contains(tag)),
    );
    expect(catalog.items, isNotEmpty);
  });

  testWidgets('Settings opens with readable saved NAS details', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await open(tester);
    await tester.runAsync(() => tester.tap(find.byKey(Keys.gallerySettings)));
    for (
      var i = 0;
      i < 50 && find.byType(SettingsScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Untagged in the actions sheet opens a filtered search', (
    tester,
  ) async {
    await open(tester);
    await revealLibraryControl(tester, Keys.libraryUntagged);
    // The new screen starts its own file IO while building, so pump in the real zone.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.libraryUntagged));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
    expect(find.byKey(Keys.libraryCloseSearch), findsOneWidget);
  });

  testWidgets('submitting a search keeps its text as a removable chip', (
    tester,
  ) async {
    await open(tester);
    await revealLibraryControl(tester, Keys.libraryUntagged);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.libraryUntagged));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
    await tester.tap(find.byKey(Keys.libraryOpenSearch));
    await tester.pump();
    await tester.enterText(find.byKey(Keys.librarySearch), 'garden');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Edit search'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'garden'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Untagged'), findsOneWidget);
  });

  testWidgets('Reset view clears a narrowed view and lists everything again', (
    tester,
  ) async {
    await open(tester);
    await revealLibraryControl(tester, Keys.libraryFavorites);
    await tester.tap(find.byKey(Keys.libraryFavorites));
    await tester.pump();
    await revealLibraryControl(tester, Keys.libraryViewApply);
    await tester.tap(find.byKey(Keys.libraryViewApply));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.galleryTile(0)), findsNothing);
    await tester.ensureVisible(find.byKey(Keys.libraryResetScope));
    await tester.tap(find.byKey(Keys.libraryResetScope));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.libraryResetScope), findsNothing);
    expect(find.byKey(Keys.galleryTile(0)), findsOneWidget);
  });

  testWidgets('Set up backup in the actions sheet opens Settings', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await open(tester);
    // A sync with no saved details marks backup as off.
    await tester.runAsync(() => session.sync.sync());
    await tester.pump();
    expect(session.sync.state, SyncState.unconfigured);
    await revealLibraryControl(tester, Keys.gallerySync);
    expect(find.byTooltip('Set up backup'), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.byKey(Keys.gallerySync)));
    for (
      var i = 0;
      i < 50 && find.byType(SettingsScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('a vault that cannot be listed offers Retry and recovers', (
    tester,
  ) async {
    await open(tester, vaultMissing: true);
    final retry = find.text('Could not open vault. Retry');
    await until(tester, () => retry.evaluate().isNotEmpty);
    // The folder comes back, then Retry lists the captures again.
    await tester.runAsync(
      () => Directory('${dir.path}-moved').rename(dir.path),
    );
    await tester.runAsync(() => tester.tap(retry));
    await until(
      tester,
      () => find.byKey(Keys.galleryTile(1)).evaluate().isNotEmpty,
    );
    expect(retry, findsNothing);
  });

  testWidgets('returning from the viewer lists the captures again', (
    tester,
  ) async {
    await open(tester);
    await tester.runAsync(() => tester.tap(find.byKey(Keys.galleryTile(0))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ViewerScreen), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
    await until(
      tester,
      () =>
          find.byType(ViewerScreen).evaluate().isEmpty &&
          find.byKey(Keys.galleryTile(1)).evaluate().isNotEmpty,
    );
  });

  testWidgets('Retry on an unreadable catalog tries the load again', (
    tester,
  ) async {
    await open(tester, corruptCatalog: true);
    // Repair the catalog, then Retry unlocks selection.
    await tester.runAsync(
      () => File('${dir.path}/${PrivateCatalog.fileName}').delete(),
    );
    await tester.runAsync(() => tester.tap(find.byKey(Keys.libraryRetry)));
    await until(tester, () => find.byKey(Keys.libraryRetry).evaluate().isEmpty);
    expect(
      tester.widget<IconButton>(find.byKey(Keys.librarySelectMode)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'opened from Moments, the gallery lists one month and can clear it',
    (tester) async {
      await open(
        tester,
        names: ['2026-11-03T10-00-00.jpg', '2026-10-31T23-59-59.jpg'],
        month: DateTime(2026, 11),
      );
      expect(find.widgetWithText(InputChip, 'November 2026'), findsOneWidget);
      expect(find.byKey(Keys.galleryTile(0)), findsOneWidget);
      expect(find.byKey(Keys.galleryTile(1)), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byKey(Keys.libraryRemoveMonth),
          matching: find.byType(Icon),
        ),
      );
      await until(
        tester,
        () => find.byKey(Keys.galleryTile(1)).evaluate().isNotEmpty,
      );
      expect(find.byKey(Keys.libraryRemoveMonth), findsNothing);
    },
  );
}
