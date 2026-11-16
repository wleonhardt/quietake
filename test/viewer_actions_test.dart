import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/viewer_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/viewer_gestures.dart';

void main() {
  late Directory dir;
  late Session session;
  late List<VaultItem> items;

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'condition never became true');
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-viewer-actions');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        dir,
      );
      items = [];
      for (var i = 0; i < 2; i++) {
        final input = await File('test_fixtures/tiny.jpg')
            .copy('${dir.path}/in$i.jpg');
        items.add(VaultItem(await vault.ingestAs(input, 'p$i.jpg')));
      }
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, dir),
      );
      await vault.catalog.load();
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await session.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('test.open'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => ViewerScreen(
                  session: session,
                  items: [...items],
                  initialIndex: 0,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('test.open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('favorite toggles the catalog entry and its tooltip', (
    tester,
  ) async {
    await open(tester);
    expect(find.byTooltip('Add favorite'), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.byKey(Keys.viewerFavorite)));
    await until(
      tester,
      () => session.vault.catalog.details(items[0].name).favorite,
    );
    await tester.pump();
    expect(find.byTooltip('Remove favorite'), findsOneWidget);
  });

  testWidgets('cancelling delete keeps the capture', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.viewerDelete));
    await until(
      tester,
      () => find.byKey(Keys.deleteDialog).evaluate().isNotEmpty,
    );
    expect(find.text('Delete from this phone?'), findsOneWidget);
    await tester.tap(find.byKey(Keys.deleteCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.deleteDialog), findsNothing);
    expect(items[0].file.existsSync(), isTrue);
  });

  testWidgets('deleting one of two captures removes it and stays open', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.viewerDelete));
    await until(
      tester,
      () => find.byKey(Keys.deleteDialog).evaluate().isNotEmpty,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.deleteConfirm));
      // Keep the whole delete pipeline in real time; catalog cleanup follows
      // the file removal and must not continue under fake async.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await until(tester, () => !items[0].file.existsSync());
    await tester.pump(const Duration(milliseconds: 500));
    expect(items[1].file.existsSync(), isTrue);
    expect(find.byKey(Keys.viewerPager), findsOneWidget);
  });

  testWidgets('swiping moves to the next capture and back', (tester) async {
    await open(tester);
    expect(find.text('1 / 2'), findsOneWidget);
    await swipeViewerPage(tester, forward: true);
    await until(tester, () => find.text('2 / 2').evaluate().isNotEmpty);
    await swipeViewerPage(tester, forward: false);
    await until(tester, () => find.text('1 / 2').evaluate().isNotEmpty);
  });

  testWidgets('double tap zooms a photo and Reset to fit restores it', (
    tester,
  ) async {
    await open(tester);
    await until(
      tester,
      () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
    );
    expect(find.byKey(Keys.viewerFit), findsNothing);
    final photo = find.byKey(Keys.viewerPhoto);
    await tester.tap(photo, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(photo, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.viewerFit), findsOneWidget);
    await tester.tap(find.byKey(Keys.viewerFit));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.viewerFit), findsNothing);
  });
}
