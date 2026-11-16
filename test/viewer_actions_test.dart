import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_backend.dart';
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
  final backend = FakeCastBackend();

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
    double textScale = 1,
    Size size = const Size(800, 1600),
    Duration slideshowInterval = const Duration(seconds: 4),
  }) async {
    tester.view.physicalSize = size;
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
        cast: CastController(vault, backend),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
                  slideshowInterval: slideshowInterval,
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

  testWidgets('Details lists type, tags and encrypted size', (tester) async {
    await open(tester);
    await tester.runAsync(() async {
      final catalog = session.vault.catalog;
      final tag = await catalog.createAlbum('Trips');
      await catalog.organize({items[0].name}, tagIds: {tag});
    });
    await tester.tap(find.byKey(Keys.viewerInfo));
    await until(
      tester,
      () => find.byKey(Keys.viewerInfoDialog).evaluate().isNotEmpty,
    );
    await until(
      tester,
      () => find.textContaining('Encrypted size: ').evaluate().isNotEmpty,
    );
    expect(find.text('Type: Photo'), findsOneWidget);
    expect(find.text('Tags: Trips'), findsOneWidget);
    final bytes = await tester.runAsync(() => items[0].file.length());
    expect(find.textContaining('Encrypted size: $bytes bytes'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.viewerInfoDialog), findsNothing);
  });

  testWidgets('Details fits a narrow screen at large text', (tester) async {
    await open(tester, textScale: 2, size: const Size(320, 640));
    await tester.runAsync(() async {
      final catalog = session.vault.catalog;
      final tag = await catalog.createAlbum('A tag with a rather long name');
      await catalog.organize({items[0].name}, tagIds: {tag});
    });
    await tester.tap(find.byKey(Keys.viewerInfo));
    await until(
      tester,
      () => find.textContaining('Encrypted size: ').evaluate().isNotEmpty,
    );
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers get a photo label and named controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await until(
      tester,
      () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
    );
    expect(find.bySemanticsLabel('Private photo'), findsOneWidget);
    for (final label in [
      'Add favorite',
      'Details',
      'Share a copy',
      'Delete photo',
    ]) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
    semantics.dispose();
  });

  testWidgets('cancelling delete keeps the capture', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.viewerDelete));
    await until(
      tester,
      () => find.byKey(Keys.deleteDialog).evaluate().isNotEmpty,
    );
    expect(find.text('Delete this photo?'), findsOneWidget);
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

  testWidgets('Recently deleted hides the capture but keeps its bytes', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.viewerDelete));
    await until(
      tester,
      () => find.byKey(Keys.deleteDialog).evaluate().isNotEmpty,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.deleteTrash));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await until(tester, () => find.byKey(Keys.deleteDialog).evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    final vault = session.vault;
    var trashed = <String, DateTime>{};
    for (var i = 0; i < 100 && trashed.isEmpty; i++) {
      trashed = await tester.runAsync(vault.trashedAt) ?? trashed;
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.runAsync(() async {
      expect(items[0].file.existsSync(), isTrue);
      expect((await vault.trashedAt()).keys, [items[0].name]);
      expect(await vault.deletedNames(), isEmpty);
      expect((await vault.list()).map((f) => f.path), [items[1].file.path]);
    });
    expect(find.byKey(Keys.viewerPager), findsOneWidget);
  });

  testWidgets(
    'with keeping turned off the dialog offers only a permanent delete',
    (tester) async {
      await open(tester);
      FlutterSecureStorage.setMockInitialValues({'trash.keep': 'off'});
      await tester.tap(find.byKey(Keys.viewerDelete));
      await until(
        tester,
        () => find.byKey(Keys.deleteDialog).evaluate().isNotEmpty,
      );
      expect(find.byKey(Keys.deleteTrash), findsNothing);
      expect(find.byKey(Keys.deleteConfirm), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
  );

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

  testWidgets('the viewer shows the cast device, or that casting failed', (
    tester,
  ) async {
    if (await tester.runAsync(MediaServer.lanAddress) == null) return;
    await open(tester);
    const tv = CastDevice('tv-1', 'Living Room TV');
    backend.failConnect = true;
    await tester.runAsync(() => session.cast.start(tv, null));
    await until(
      tester,
      () => find.text('Could not cast. Try again.').evaluate().isNotEmpty,
    );
    backend.failConnect = false;
    await tester.runAsync(() => session.cast.start(tv, null));
    await until(
      tester,
      () => find.text('casting to Living Room TV').evaluate().isNotEmpty,
    );
  });

  testWidgets('a running slideshow keeps the screen awake and releases it', (
    tester,
  ) async {
    final calls = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('quietake/screen'), (
      call,
    ) async {
      if (call.method == 'keepAwake') calls.add(call.arguments);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('quietake/screen'),
        null,
      ),
    );
    await open(tester);
    await tester.tap(find.byKey(Keys.viewerSlideshow));
    await tester.pump();
    expect(calls, [true]);
    await tester.tap(find.byKey(Keys.viewerSlideshow));
    await tester.pump();
    expect(calls, [true, false]);
    await tester.tap(find.byKey(Keys.viewerSlideshow));
    await tester.pump();
    expect(calls, [true, false, true]);
    // Leaving the viewer while it runs also releases the screen.
    await tester.pumpWidget(const SizedBox());
    expect(calls, [true, false, true, false]);
  });

  testWidgets('a slideshow advances to the next photo and stops at the last', (
    tester,
  ) async {
    await open(tester, slideshowInterval: const Duration(seconds: 1));
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byKey(Keys.viewerSlideshow));
    await tester.pump();
    expect(find.byTooltip('Stop slideshow'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2 / 2'), findsOneWidget);

    // The next tick finds no further photo and ends the show.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Start slideshow'), findsOneWidget);
  });

  testWidgets('stopping a slideshow keeps the current photo', (tester) async {
    await open(tester, slideshowInterval: const Duration(seconds: 1));
    await tester.tap(find.byKey(Keys.viewerSlideshow));
    await tester.pump();
    await tester.tap(find.byKey(Keys.viewerSlideshow));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Start slideshow'), findsOneWidget);
  });
}
