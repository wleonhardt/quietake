import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/albums_screen.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  for (final protected in [false, true]) {
    testWidgets(
      'tag management counts and merges safely; protected=$protected',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final privacy = PrivacyController(onLock: () {})..minutes = 0;
        privacy.setEnabled(protected);
        late Directory dir;
        late Session session;
        late String source;
        late String target;
        await tester.runAsync(() async {
          final sodium = await SodiumSumoInit.init();
          dir = await Directory.systemTemp.createTemp('tags-manager');
          final vault = Vault(
            VaultCrypto(sodium),
            sodium.crypto.secretBox.keygen(),
            dir,
          );
          source = await vault.catalog.createAlbum('Jogging');
          target = await vault.catalog.createAlbum('Running');
          for (final name in ['one', 'two', 'three', 'four']) {
            final input = await File('test_fixtures/tiny.jpg')
                .copy('${dir.path}/input');
            await vault.ingestAs(input, '$name.jpg');
          }
          await vault.catalog.organize(
            {'one.jpg.shtr', 'two.jpg.shtr', 'pending.jpg.shtr'},
            tagIds: {source},
          );
          await vault.catalog.organize(
            {'two.jpg.shtr', 'three.jpg.shtr'},
            tagIds: {target},
          );
          session = Session(
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

        try {
          await tester.runAsync(
            () => tester.pumpWidget(
              MaterialApp(
                theme: quietakeTheme(),
                builder: (_, child) =>
                    PrivacyScope(controller: privacy, child: child!),
                home: AlbumsScreen(session: session),
              ),
            ),
          );
          await settle();
          expect(find.text('2 captures'), findsNWidgets(2));
          expect(find.text('1 capture'), findsOneWidget);
          await tester.enterText(find.byKey(const Key('tags.search')), 'jog');
          await tester.pump();
          expect(find.text('Running'), findsNothing);
          await tester.enterText(find.byKey(const Key('tags.search')), '');
          await tester.pump();
          await tap(Keys.albumMenu(source));
          await tap(const Key('tags.merge'));
          await tap(Key('tags.merge.target.$target'));
          expect(find.textContaining('3 captures'), findsOneWidget);
          if (protected) {
            privacy.lock();
            await tap(Keys.tagMergeConfirm);
            expect(
              session.vault.catalog.albums.containsKey(source),
              isTrue,
              reason:
                  'Privacy transition invalidates pending merge confirmation',
            );
            privacy.setEnabled(true);
            await tap(Keys.albumMenu(source));
            await tap(Keys.tagMerge);
            await tap(Keys.tagMergeTarget(target));
          }
          await tap(Keys.tagMergeConfirm);
          expect(session.vault.catalog.albums.containsKey(source), isFalse);
          expect(session.vault.catalog.details('pending.jpg.shtr').albums, {
            target,
          });
          expect(find.text('3 captures'), findsOneWidget);
          await tap(Key('tags.browse.$target'));
          expect(find.text('Search'), findsOneWidget);
          expect(
            tester
                .widget<GridView>(find.byKey(Keys.galleryGrid))
                .childrenDelegate
                .estimatedChildCount,
            3,
          );
          await tap(Keys.libraryCloseSearch);
          await settle();
          await tap(Keys.libraryUntagged);
          expect(
            tester
                .widget<GridView>(find.byKey(Keys.galleryGrid))
                .childrenDelegate
                .estimatedChildCount,
            1,
          );
          expect(
            await tester.runAsync(() => session.vault.list()),
            hasLength(4),
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          var closed = false;
          final closing = session.close().then((_) => closed = true);
          for (var i = 0; i < 250 && !closed; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          expect(closed, isTrue, reason: 'Session cleanup must finish');
          await closing;
          privacy.dispose();
          await tester.runAsync(() => dir.delete(recursive: true));
        }
      },
    );
  }

  testWidgets('tag search stays laid out above a landscape keyboard', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(832, 384);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final privacy = PrivacyController(onLock: () {})..minutes = 0;
    late Session session;
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      final dir = await Directory.systemTemp.createTemp('tags-landscape');
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
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: quietakeTheme(),
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(832, 384),
              viewInsets: EdgeInsets.only(bottom: 223),
            ),
            child: PrivacyScope(controller: privacy, child: child!),
          ),
          home: AlbumsScreen(session: session),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byKey(Keys.tagSearch).hitTestable(), findsOneWidget);
      final list = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(Keys.albumCreateFirst),
        50,
        scrollable: list,
      );
      final position = tester.state<ScrollableState>(list).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(
        tester.getBottomLeft(find.byKey(Keys.albumCreateFirst)).dy,
        lessThanOrEqualTo(384 - 223),
        reason: 'the last item scrolls above the keyboard',
      );
    } finally {
      await tester.runAsync(() => session.close());
    }
  });
}
