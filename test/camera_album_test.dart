import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/camera/capture_screen.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/controlled_camera.dart';
import '../test_support/fake_cast_backend.dart';

class _AlbumCamera extends ControlledCamera {
  _AlbumCamera(super.directory) {
    empty = false;
  }
  Completer<void>? photo;
  @override
  Future<XFile> takePicture(int id) async {
    await photo?.future;
    return super.takePicture(id);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Session session;
  late _AlbumCamera camera;
  late CameraPlatform previous;
  late String album;
  var cleanupRegistered = false;

  Future<void> until(WidgetTester tester, Future<bool> Function() done) async {
    for (var i = 0; i < 250; i++) {
      await tester.pump();
      if (await tester.runAsync(done) == true) {
        await tester.pump();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail('Camera album operation did not complete');
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.pump(const Duration(milliseconds: 500));
    final target = find.byKey(key);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        key == Keys.captureAlbumClose ? -100 : 100,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 500));
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> choose(WidgetTester tester, String? id) async {
    await tap(tester, Keys.captureAlbum);
    await until(
      tester,
      () async => find.byKey(Keys.captureAlbumClose).evaluate().isNotEmpty,
    );
    await tap(
      tester,
      id == null ? Keys.captureAlbumNone : Keys.captureAlbumChoose(id),
    );
    await tap(tester, Keys.tagPickerApply);
  }

  Future<void> boot(
    WidgetTester tester, {
    bool active = true,
    double scale = 1,
  }) async {
    if (!cleanupRegistered) {
      cleanupRegistered = true;
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        root = await Directory.systemTemp.createTemp('camera-albums');
        final sodium = await SodiumSumoInit.init();
        final vault = Vault(
          VaultCrypto(sodium),
          sodium.crypto.secretBox.keygen(),
          root,
        );
        session = Session(
          vault: vault,
          server: await MediaServer.start(vault),
          cast: CastController(vault, FakeCastBackend()),
          store: MasterKeyStore(sodium, root),
        );
        album = await vault.catalog.createAlbum('Field notes');
        previous = CameraPlatform.instance;
        camera = _AlbumCamera(root);
        CameraPlatform.instance = camera;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('quietake/camera'),
          (call) async =>
              call.method == 'prepareVideo' ? call.arguments['path'] : true,
        );
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await until(
          tester,
          () async => camera.disposed.length == camera.created,
        );
        CameraPlatform.instance = previous;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('quietake/camera'),
          null,
        );
        var closed = false;
        final close = session.close().then((_) => closed = true);
        await until(tester, () async => closed);
        await close;
        await tester.runAsync(() async {
          await root.delete(recursive: true);
        });
        expect(tester.takeException(), isNull);
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: CaptureScreen(session: session, active: active),
      ),
    );
    if (active) {
      await until(
        tester,
        () async => find.byKey(Keys.preview).evaluate().isNotEmpty,
      );
    }
  }

  setUp(() async {
    cleanupRegistered = false;
  });
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await until(tester, () async => camera.disposed.length == camera.created);
  }

  testWidgets(
    'choose, dismiss, clear and manage albums without changing captures',
    (tester) async {
      await boot(tester);
      await choose(tester, album);
      expect(
        find.descendant(
          of: find.byKey(Keys.captureAlbum),
          matching: find.text('Field notes'),
        ),
        findsOneWidget,
      );
      await tap(tester, Keys.captureAlbum);
      await until(
        tester,
        () async => find.byKey(Keys.captureAlbumClose).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.captureAlbumClose);
      expect(find.text('Field notes'), findsOneWidget);
      await tester.runAsync(
        () => session.vault.catalog.renameAlbum(album, 'Renamed'),
      );
      await tester.pump();
      expect(find.text('Renamed'), findsOneWidget);
      await choose(tester, null);
      expect(find.text('Tags'), findsOneWidget);
      await tap(tester, Keys.captureAlbum);
      await until(
        tester,
        () async => find.byKey(Keys.captureAlbumCreate).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.captureAlbumCreate);
      await tester.enterText(find.byKey(Keys.libraryName), 'New album');
      await tap(tester, Keys.librarySave);
      await until(
        tester,
        () async => session.vault.catalog.albums.containsValue('New album'),
      );
      final created = session.vault.catalog.albums.entries
          .singleWhere((e) => e.value == 'New album')
          .key;
      await tap(tester, Keys.captureAlbumManage);
      expect(find.text('Tags'), findsOneWidget);
      await until(
        tester,
        () async => find.byKey(Keys.albumMenu(created)).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.albumMenu(created));
      await tap(tester, Keys.albumDelete);
      await tap(tester, Keys.albumDeleteConfirm);
      await until(
        tester,
        () async => !session.vault.catalog.albums.containsKey(created),
      );
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('New album'), findsNothing);
      await tap(tester, Keys.captureAlbumClose);
      expect(await tester.runAsync(() => session.vault.list()), isEmpty);
      await unmount(tester);
    },
  );

  testWidgets(
    'camera combines tags and cancels pending choice without media edits',
    (tester) async {
      await boot(tester);
      final action = (await tester.runAsync(
        () => session.vault.catalog.createAlbum('Running'),
      ))!;
      await choose(tester, album);
      await tap(tester, Keys.captureAlbum);
      await until(
        tester,
        () async => find.byKey(Keys.captureAlbumClose).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.captureAlbumChoose(action));
      await tap(tester, Keys.captureAlbumClose);
      expect(find.text('Field notes'), findsOneWidget);
      await choose(tester, action);
      expect(find.text('2 tags'), findsOneWidget);
      await tap(tester, Keys.shutter);
      await until(tester, () async => (await session.vault.list()).length == 1);
      final saved = (await tester.runAsync(() => session.vault.list()))!.single;
      expect(
        session.vault.catalog.details(saved.uri.pathSegments.last).albums,
        {album, action},
      );
      await unmount(tester);
    },
  );

  testWidgets(
    'photo snapshots album, preserves secure media on stale album, then clears',
    (tester) async {
      await boot(tester);
      await choose(tester, album);
      camera.photo = Completer<void>();
      await tap(tester, Keys.shutter);
      expect(
        tester.widget<TextButton>(find.byKey(Keys.captureAlbum)).onPressed,
        isNull,
      );
      await tester.runAsync(() => session.vault.catalog.deleteAlbum(album));
      camera.photo!.complete();
      await until(
        tester,
        () async =>
            (await session.vault.list()).length == 1 &&
            find
                .text(
                  'Saved securely. Tags were not applied; organize in Library.',
                )
                .evaluate()
                .isNotEmpty,
      );
      final first = (await tester.runAsync(() => session.vault.list()))!.single;
      expect(
        (await tester.runAsync(() => session.vault.readAll(first)))!.take(3),
        [0xff, 0xd8, 0xff],
      );
      expect(find.text('Tags'), findsOneWidget);
      camera.photo = null;
      await tap(tester, Keys.shutter);
      await until(
        tester,
        () async =>
            (await session.vault.list()).length == 2 &&
            find.text('Saved securely').evaluate().isNotEmpty,
      );
      expect(session.vault.catalog.items, isEmpty);
      await unmount(tester);
    },
  );

  testWidgets(
    'background stop retains video album and clears future camera choice',
    (tester) async {
      await boot(tester);
      await choose(tester, album);
      final action = (await tester.runAsync(
        () => session.vault.catalog.createAlbum('Moving'),
      ))!;
      await choose(tester, action);
      await tap(tester, Keys.videoToggle);
      await until(
        tester,
        () async => find.byKey(Keys.captureTimer).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<TextButton>(find.byKey(Keys.captureAlbum)).onPressed,
        isNull,
      );
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await until(
        tester,
        () async =>
            (await session.vault.list()).length == 1 &&
            camera.disposed.length == camera.created,
      );
      final saved = (await tester.runAsync(() => session.vault.list()))!.single;
      expect(
        session.vault.catalog.details(saved.uri.pathSegments.last).albums,
        {album, action},
      );
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(
        tester,
        () async => find.byKey(Keys.preview).evaluate().isNotEmpty,
      );
      expect(find.text('Tags'), findsOneWidget);
      await choose(tester, album);
      await boot(tester, active: false);
      await until(tester, () async => camera.disposed.length == camera.created);
      await boot(tester);
      expect(find.text('Tags'), findsOneWidget);
      await unmount(tester);
    },
  );

  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    testWidgets('long album names and picker fit $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await boot(tester, scale: 2);
        final longName = List.filled(12, 'Long album').join(' ');
        await tester.runAsync(
          () => session.vault.catalog.renameAlbum(
            album,
            longName.substring(0, 120),
          ),
        );
        await choose(tester, album);
        expect(find.byKey(Keys.captureAlbum).hitTestable(), findsOneWidget);
        expect(
          tester.getSize(find.byKey(Keys.captureAlbum)).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
        await tap(tester, Keys.captureAlbum);
        await until(
          tester,
          () async => find.byKey(Keys.captureAlbumClose).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tap(tester, Keys.captureAlbumChoose(album));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      } finally {
        semantics.dispose();
      }
    });
  }
}
