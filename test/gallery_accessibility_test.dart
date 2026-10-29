import '../test_support/library_controls.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/gallery_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  testWidgets(
    'gallery identifies simultaneous photos, duration and failed previews',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      const channel = MethodChannel('quietake/previews');
      late Directory dir;
      late Session session;
      await tester.runAsync(() async {
        final sodium = await SodiumSumoInit.init();
        dir = await Directory.systemTemp.createTemp(
          'quietake-gallery-semantics',
        );
        final vault = Vault(
          VaultCrypto(sodium),
          sodium.crypto.secretBox.keygen(),
          dir,
        );
        final jpg = await File('test_fixtures/tiny.jpg').readAsBytes();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => {'bytes': jpg, 'durationMs': 65000},
        );
        for (final name in [
          '2026-10-27T12-00-01.002Z.jpg',
          '2026-10-27T12-00-01.001Z.jpg',
          '2026-10-27T12-00-00.000Z.mp4',
          '2026-10-27T11-59-59.000Z.jpg',
        ]) {
          final plain = await File('${dir.path}/input')
              .writeAsBytes(name.contains('11-59') ? [1, 2, 3] : jpg);
          await vault.ingestAs(plain, name);
        }
        session = Session(
          vault: vault,
          server: await MediaServer.start(vault),
          cast: CastController(vault, FakeCastBackend()),
          store: MasterKeyStore(sodium, dir),
        );
      });
      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: quietakeTheme(),
              home: GalleryScreen(session: session),
            ),
          );
        });
        for (
          var i = 0;
          i < 100 &&
              find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        expect(find.byKey(Keys.librarySearch), findsNothing);
        expect(
          tester.getTopLeft(find.byKey(Keys.galleryGrid)).dy,
          lessThan(270),
        );
        final durationBadge = find
            .ancestor(
              of: find.byKey(Keys.galleryVideoDuration),
              matching: find.byType(DecoratedBox),
            )
            .first;
        final compactDuration =
            tester.getSize(durationBadge).width <
            tester.getSize(find.byKey(Keys.galleryTile(2))).width * .6;
        String label(int index) =>
            tester.getSemantics(find.byKey(Keys.galleryTile(index))).label;
        expect(label(0), isNot(label(1)));
        expect(label(0), contains('1 of 4'));
        expect(label(1), contains('2 of 4'));
        expect(label(2), contains('duration 1:05'));
        expect(label(3), contains('Preview unavailable'));
        await tester.longPress(find.byKey(Keys.galleryTile(0)));
        await tester.pump();
        expect(label(0), startsWith('Select Photo'));
        expect(find.text('Share copies'), findsOneWidget);
        expect(find.text('Add tags'), findsOneWidget);
        final selectionBar = find
            .ancestor(
              of: find.text('1 selected'),
              matching: find.byType(SafeArea),
            )
            .first;
        expect(
          {
            'untitled duration uses a compact badge': compactDuration,
            'count is above selection actions':
                tester.getBottomLeft(find.text('1 selected')).dy <=
                tester.getTopLeft(find.text('Share copies')).dy,
            'selection bar reaches screen bottom':
                (tester.getBottomLeft(selectionBar).dy - 900).abs() < 1,
          },
          {
            'untitled duration uses a compact badge': true,
            'count is above selection actions': true,
            'selection bar reaches screen bottom': true,
          },
        );
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();
        for (final size in [
          const Size(320, 640),
          const Size(740, 360),
          const Size(400, 900),
        ]) {
          tester.view.physicalSize = size;
          await tester.pump();
          for (final key in [
            Keys.libraryShare,
            Keys.libraryFavorite,
            Keys.libraryAddAlbum,
            Keys.libraryCancelSelection,
          ]) {
            await tester.ensureVisible(find.byKey(key));
            expect(find.byKey(key).hitTestable(), findsOneWidget);
            final target = tester.getSize(find.byKey(key));
            expect(target.width, greaterThanOrEqualTo(48));
            expect(target.height, greaterThanOrEqualTo(48));
          }
          expect(tester.takeException(), isNull);
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pump();
        await tester.tap(find.byKey(Keys.libraryCancelSelection));
        await tester.pump();
        tester.view.physicalSize = const Size(1024, 900);
        await tester.pump();
        await tester.runAsync(
          () => session.vault.catalog.createAlbum('Empty album'),
        );
        await tester.pump();
        await revealLibraryControl(tester, Keys.librarySearch);
        await tester.enterText(find.byKey(Keys.librarySearch), 'absent');
        await showLibrarySearch(tester);
        await revealLibraryControl(tester, Keys.libraryVideos);
        await tester.tap(find.byKey(Keys.libraryVideos));
        await tester.tap(find.byKey(Keys.libraryFavorites));
        await applyLibraryView(tester);
        expect(find.byKey(Keys.libraryNoResults), findsOneWidget);
        await tester.tap(find.byKey(Keys.libraryClearFilters));
        await tester.pump();
        expect(
          tester
              .widget<GridView>(find.byKey(Keys.galleryGrid))
              .childrenDelegate
              .estimatedChildCount,
          4,
        );
        for (final width in [320.0, 360.0, 740.0, 1024.0]) {
          tester.view.physicalSize = Size(width, 900);
          await tester.pump();
          final tileWidth = tester
              .getSize(find.byKey(Keys.galleryTile(0)))
              .width;
          expect(
            tileWidth,
            inInclusiveRange(110, 180),
            reason: 'Readable media density at width $width',
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          await session.close();
          await dir.delete(recursive: true);
        });
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      }
    },
  );
}
