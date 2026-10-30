import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/gallery_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

class _QuietSync extends SyncController {
  _QuietSync(super.vault);
  @override
  Future<void> sync() async {}
}

class _SearchSession extends Session {
  _SearchSession({
    required super.vault,
    required super.server,
    required super.cast,
    required super.store,
  });
  late final _sync = _QuietSync(vault);
  @override
  _QuietSync get sync => _sync;
}

void main() {
  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    testWidgets(
      'focused search combines tags and restores browse scope at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        FlutterSecureStorage.setMockInitialValues({});
        late Directory dir;
        late Session session;
        late String subject;
        late String action;
        await tester.runAsync(() async {
          final sodium = await SodiumSumoInit.init();
          dir = await Directory.systemTemp.createTemp('focused-search');
          final vault = Vault(
            VaultCrypto(sodium),
            sodium.crypto.secretBox.keygen(),
            dir,
          );
          subject = await vault.catalog.createAlbum('Alex');
          action = await vault.catalog.createAlbum('Running outdoors');
          for (final name in ['one', 'two', 'three']) {
            final plain = await File('test_fixtures/tiny.jpg')
                .copy('${dir.path}/input');
            await vault.ingestAs(plain, '$name.jpg');
          }
          await vault.catalog.organize(
            {'one.jpg.shtr'},
            tagIds: {subject, action},
          );
          await vault.catalog.organize({'two.jpg.shtr'}, tagIds: {subject});
          session = _SearchSession(
            vault: vault,
            server: await MediaServer.start(vault),
            cast: CastController(vault, FakeCastBackend()),
            store: MasterKeyStore(sodium, dir),
          );
        });
        Future<void> settle() async {
          for (var i = 0; i < 15; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        Future<void> tap(Key key) async {
          await tester.ensureVisible(find.byKey(key));
          await tester.runAsync(() => tester.tap(find.byKey(key)));
          await settle();
        }

        var keyboardCastReachable = true;
        try {
          await tester.runAsync(
            () => tester.pumpWidget(
              MaterialApp(
                theme: quietakeTheme(),
                home: GalleryScreen(session: session),
              ),
            ),
          );
          await settle();
          expect(find.byKey(Keys.librarySearch), findsNothing);
          expect(find.byKey(Keys.libraryPhotos), findsNothing);
          expect(find.byKey(Keys.libraryAlbums), findsNothing);
          await tap(const Key('library.view'));
          await tap(Keys.libraryFavorites);
          await tap(const Key('library.view.apply'));
          expect(find.byKey(Keys.libraryNoResults), findsOneWidget);
          await tap(Keys.libraryOpenSearch);
          expect(find.text('Search'), findsOneWidget);
          if (size.height == 360) {
            tester.view.padding = const FakeViewPadding(top: 62);
            tester.view.viewInsets = const FakeViewPadding(bottom: 200);
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetViewInsets);
            await settle();
            keyboardCastReachable = find
                .byKey(Keys.galleryCast)
                .hitTestable()
                .evaluate()
                .isNotEmpty;
            tester.view.resetPadding();
            tester.view.resetViewInsets();
            await settle();
          }
          await tap(Key('library.tag.$subject'));
          await tap(Key('library.tag.$action'));
          expect(find.text('Show 1 capture'), findsOneWidget);
          await tap(const Key('library.search.show'));
          expect(
            tester
                .widget<GridView>(find.byKey(Keys.galleryGrid))
                .childrenDelegate
                .estimatedChildCount,
            1,
          );
          await tap(const Key('library.search.options'));
          await tap(const Key('library.search.any'));
          expect(
            tester
                .widget<GridView>(find.byKey(Keys.galleryGrid))
                .childrenDelegate
                .estimatedChildCount,
            2,
          );
          await tap(Keys.libraryCloseSearch);
          expect(
            find.byKey(Keys.libraryNoResults),
            findsOneWidget,
            reason: 'Search starts in All Library and closing restores the favorite scope',
          );
          await tap(Keys.libraryClearFilters);
          expect(
            tester
                .widget<GridView>(find.byKey(Keys.galleryGrid))
                .childrenDelegate
                .estimatedChildCount,
            3,
          );
          expect(tester.takeException(), isNull);
          expect(
            keyboardCastReachable,
            isTrue,
            reason: 'Cast remains reachable with little space above keyboard',
          );
          await tester.runAsync(() async {
            expect(await session.vault.list(), hasLength(3));
            expect(await session.vault.deletedNames(), isEmpty);
          });
        } finally {
          await tester.runAsync(() async {
            await tester.pumpWidget(const SizedBox());
            await session.close();
            await dir.delete(recursive: true);
          });
        }
      },
    );
  }
}
