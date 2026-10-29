import '../test_support/library_controls.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/gallery_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/import_screen.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(360, 640),
    const Size(740, 360),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('gallery title and actions fit $size at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        FlutterSecureStorage.setMockInitialValues({});
        final semantics = tester.ensureSemantics();
        final privacy = PrivacyController(onLock: () {})..minutes = 0;
        privacy.setEnabled(true);
        late Directory dir;
        late Session session;
        await tester.runAsync(() async {
          final sodium = await SodiumSumoInit.init();
          dir = await Directory.systemTemp.createTemp(
            'quietake-gallery-layout',
          );
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: PrivacyScope(controller: privacy, child: child!),
              ),
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GalleryScreen(session: session),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            await tester.tap(find.text('Open'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          });
          expect(find.byKey(Keys.libraryActionsClose), findsNothing);
          for (
            var i = 0;
            i < 100 && find.byKey(Keys.galleryEmpty).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          expect(find.byKey(Keys.galleryEmpty), findsOneWidget);
          await tester.runAsync(session.sync.sync);
          await tester.pump();
          expect(find.byKey(Keys.gallerySyncResult), findsNothing);
          await revealLibraryControl(tester, Keys.gallerySync);
          expect(find.byTooltip('Set up backup'), findsOneWidget);
          final title = tester.renderObject<RenderParagraph>(
            find.text('Library'),
          );
          expect(title.size.width, greaterThan(0));
          expect(
            title.didExceedMaxLines,
            isFalse,
            reason: 'Library title must remain readable',
          );
          for (final key in [
            Keys.lockNow,
            Keys.gallerySettings,
            Keys.galleryCast,
            Keys.gallerySync,
            Keys.libraryImport,
          ]) {
            await revealLibraryControl(tester, key);
            expect(find.byKey(key).hitTestable(), findsOneWidget);
            final size = tester.getSize(find.byKey(key));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          // A scrolled viewport can clip part of an off-focus target. Verify
          // each revealed target above, then the compact screen guidelines.
          await tester.ensureVisible(find.byKey(Keys.libraryActionsClose));
          await tester.tap(find.byKey(Keys.libraryActionsClose));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          for (final guideline in [
            androidTapTargetGuideline,
            iOSTapTargetGuideline,
            labeledTapTargetGuideline,
            textContrastGuideline,
          ]) {
            await expectLater(tester, meetsGuideline(guideline));
          }
          if (size.width == 320 && scale == 2) {
            await revealLibraryControl(tester, Keys.galleryCast);
            await tester.tap(find.byKey(Keys.galleryCast));
            await tester.pumpAndSettle();
            expect(find.text('Cast to a TV'), findsOneWidget);
            expect(
              find.byKey(const Key('cast.close')).hitTestable(),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const Key('cast.close')));
            await tester.pumpAndSettle();
            expect(find.byKey(Keys.castSheet), findsNothing);
          }
          final importKey = size.width == 320 && scale == 1
              ? Keys.libraryImport
              : Keys.galleryEmptyImport;
          await revealLibraryControl(tester, importKey);
          await tester.ensureVisible(find.byKey(importKey));
          await tester.runAsync(() async {
            await tester.tap(find.byKey(importKey));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          });
          expect(find.byType(ImportScreen), findsOneWidget);
          await tester.runAsync(() async {
            await tester.pageBack();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          });
          expect(find.byKey(Keys.libraryActionsClose), findsNothing);
          for (
            var i = 0;
            i < 100 && find.byKey(Keys.galleryEmpty).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          await tester.ensureVisible(find.byKey(Keys.galleryEmptyCamera));
          await tester.tap(find.byKey(Keys.galleryEmptyCamera));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('Open'), findsOneWidget);
          await tester.runAsync(() async {
            expect(await session.vault.list(), isEmpty);
            await tester.tap(find.text('Open'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          });
          await tester.tap(find.byKey(Keys.lockNow));
          expect(privacy.enabled, isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          privacy.dispose();
          await tester.runAsync(() async {
            await tester.pumpWidget(const SizedBox());
            await session.close();
            await dir.delete(recursive: true);
          });
        }
      });
    }
  }
}
