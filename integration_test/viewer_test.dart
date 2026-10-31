import '../test_support/fixtures.dart';
import '../test_support/viewer_gestures.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:video_player/video_player.dart';
import 'package:quietake/vault/vault.dart';

import 'harness.dart';

/// Gallery and viewer, seeded from test-only fixtures so it runs on the iOS
/// simulator too (no camera needed).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;
  late Vault vault;

  setUpAll(() async {
    app = await TestApp.unlocked();
    vault = app.vault;
    for (final entry in await vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    final tmp = await getTemporaryDirectory();
    for (final name in ['tiny.jpg', 'tiny.mp4']) {
      final data = fixtureBytes(name);
      final f = File('${tmp.path}/$name')..writeAsBytesSync(data);
      // Names sort newest first in the gallery; make the photo "newer".
      final stem = name.endsWith('jpg') ? '2026-02' : '2026-01';
      await vault.ingestAs(f, '$stem.$name');
    }
  });

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('timed out after $timeout');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String videoState(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(Keys.viewerVideoState)).data!;

  Future<void> waitForPage(WidgetTester tester, String position) async {
    final pager = tester.widget<PageView>(find.byKey(Keys.viewerPager));
    try {
      await pumpUntil(
        tester,
        () =>
            tester.widget<Text>(find.byKey(Keys.viewerPosition)).data ==
                position &&
            !pager.controller!.position.isScrollingNotifier.value,
      );
    } on TestFailure catch (error) {
      fail(
        '$error; expected=$position '
        'actual=${tester.widget<Text>(find.byKey(Keys.viewerPosition)).data} '
        'page=${pager.controller!.page} '
        'scrolling=${pager.controller!.position.isScrollingNotifier.value} '
        'physics=${pager.physics}',
      );
    }
  }

  testWidgets('gallery lists both items; viewer shows photo then plays video', (
    tester,
  ) async {
    await tester.pumpWidget(app.widget());
    await pumpUntil(
      tester,
      () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Keys.openGallery));
    await pumpUntil(
      tester,
      () => find.byKey(Keys.galleryTile(1)).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 500)); // route transition
    expect(find.byKey(Keys.galleryTile(2)), findsNothing);

    await pumpUntil(
      tester,
      () => find.byKey(Keys.galleryVideoDuration).evaluate().isNotEmpty,
    );
    expect(
      tester.widget<Text>(find.byKey(Keys.galleryVideoDuration)).data,
      '0:01',
    );

    // Tile 0 is the photo: its decrypted thumbnail renders as an Image.
    await pumpUntil(
      tester,
      () => find
          .descendant(
            of: find.byKey(Keys.galleryTile(0)),
            matching: find.byKey(Keys.galleryPreview),
          )
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(find.byKey(Keys.galleryTile(0)));
    await pumpUntil(
      tester,
      () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
    );
    await tester.pump(
      const Duration(milliseconds: 500),
    ); // route transition before the fling
    final img = tester.widget<Image>(find.byKey(Keys.viewerPhoto));
    final completer = img.image.resolve(ImageConfiguration.empty);
    final size = await () async {
      final c = Completer<Size>();
      completer.addListener(
        ImageStreamListener((info, _) {
          if (!c.isCompleted) {
            c.complete(
              Size(info.image.width.toDouble(), info.image.height.toDouble()),
            );
          }
        }, onError: (e, _) => c.completeError(e)),
      );
      return c.future;
    }();
    expect(size, const Size(160, 120), reason: 'decrypted JPEG decodes');

    // Swipe to the video page; it streams from the loopback server.
    await swipeViewerPage(tester, forward: true);
    await waitForPage(tester, '2 / 2');
    expect(
      tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
      '2 / 2',
      reason: 'Swipe up must move to the next capture',
    );
    await pumpUntil(
      tester,
      () => find.byKey(Keys.viewerVideoState).evaluate().isNotEmpty,
    );
    await pumpUntil(
      tester,
      () => find.byKey(Keys.viewerPlay).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );
    final pager = tester
        .widget<PageView>(find.byKey(Keys.viewerPager))
        .controller!;
    await pumpUntil(tester, () => !pager.position.isScrollingNotifier.value);
    await tester.pump();
    expect(
      tester.getSize(find.byKey(Keys.viewerSeek)).height,
      lessThan(80),
      reason: 'Playback controls must not cover the entire video',
    );
    expect(
      tester
          .getRect(find.byKey(Keys.viewerVideo))
          .overlaps(tester.getRect(find.byKey(Keys.viewerSeek))),
      isFalse,
      reason: 'Video and playback controls must have separate visible space',
    );
    expect(videoState(tester), contains('/ 0:01'));
    expect(find.byKey(Keys.viewerSeek), findsOneWidget);
    final player = tester
        .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
        .controller;
    await player.setLooping(true);
    await player.seekTo(Duration.zero);
    await player.play();
    await tester.pump();
    final before = tester
        .widget<IconButton>(find.byKey(Keys.viewerPlay))
        .tooltip;
    await tester.tap(find.byKey(Keys.viewerPlay));
    await pumpUntil(
      tester,
      () =>
          tester.widget<IconButton>(find.byKey(Keys.viewerPlay)).tooltip !=
          before,
    );
    expect(
      tester.widget<IconButton>(find.byKey(Keys.viewerPlay)).tooltip,
      before == 'Pause video'
          ? anyOf('Play video', 'Replay video')
          : 'Pause video',
    );
    if (before == 'Pause video') {
      expect(player.value.isPlaying, isFalse);
    }
    await player.pause();
    await player.seekTo(Duration.zero);
    await tester.pump();
    final seek = tester.widget<Slider>(find.byKey(Keys.viewerSeek));
    seek.onChanged!(600);
    await tester.pump();
    expect(player.value.position.inMilliseconds, isNot(closeTo(600, 100)));
    tester.widget<Slider>(find.byKey(Keys.viewerSeek)).onChangeEnd!(600);
    await pumpUntil(
      tester,
      () => (player.value.position.inMilliseconds - 600).abs() < 200,
    );
    expect(
      player.value.isPlaying,
      isFalse,
      reason: 'Seeking must preserve pause',
    );
    await tester.tap(find.byKey(Keys.viewerPlay));
    await pumpUntil(tester, () => player.value.isPlaying);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (player.value.isPlaying) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Background video kept playing');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await pumpUntil(tester, () => player.value.isPlaying);
    await tester.binding.setSurfaceSize(const Size(740, 360));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(Keys.viewerSeek)).height, lessThan(80));
    expect(
      tester
          .getRect(find.byKey(Keys.viewerVideo))
          .overlaps(tester.getRect(find.byKey(Keys.viewerSeek))),
      isFalse,
    );
    await tester.binding.setSurfaceSize(null);
    await tester.pump(const Duration(milliseconds: 500));
    await swipeViewerPage(tester, forward: false);
    await waitForPage(tester, '1 / 2');
    expect(
      tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
      '1 / 2',
      reason: 'Swipe down must return to the preceding capture',
    );
  });
  testWidgets('damaged media stays navigable and can be deleted', (
    tester,
  ) async {
    final temp = await getTemporaryDirectory();
    for (final extension in ['jpg', 'mp4']) {
      final plain = await File('${temp.path}/invalid.$extension')
          .writeAsBytes([1, 2, 3]);
      final damaged = await vault.ingestAs(plain, '2099-invalid.$extension');
      try {
        await tester.pumpWidget(app.widget());
        await pumpUntil(
          tester,
          () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(Keys.openGallery));
        await pumpUntil(
          tester,
          () => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(Keys.galleryTile(0)));
        await pumpUntil(
          tester,
          () => find.byKey(Keys.viewerError).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(Keys.viewerDelete));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(Keys.deleteConfirm));
        await pumpUntil(
          tester,
          () =>
              find.byKey(Keys.viewerPosition).evaluate().isNotEmpty &&
              tester.widget<Text>(find.byKey(Keys.viewerPosition)).data ==
                  '1 / 2',
        );
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(Keys.galleryGrid), findsOneWidget);
        expect(await damaged.exists(), isFalse);
        expect(await vault.list(), hasLength(2));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        if (await damaged.exists()) await damaged.delete();
      }
    }
  });

  testWidgets('large gallery scrolls lazily and opens its last capture', (
    tester,
  ) async {
    final temp = await getTemporaryDirectory();
    try {
      for (var i = 0; i < 120; i++) {
        final plain = await File('${temp.path}/gallery-seed.jpg')
            .writeAsBytes(fixtureBytes('tiny.jpg'));
        await vault.ingestAs(
          plain,
          '2088-many-${i.toString().padLeft(3, '0')}.jpg',
        );
      }
      await tester.pumpWidget(app.widget());
      await pumpUntil(
        tester,
        () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(Keys.openGallery));
      await pumpUntil(
        tester,
        () => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 500));
      final grid = tester.widget<GridView>(find.byKey(Keys.galleryGrid));
      expect(grid.childrenDelegate.estimatedChildCount, 122);
      expect(
        find.byKey(Keys.galleryPreview).evaluate().length,
        lessThan(120),
        reason: 'Offscreen captures must not all decode at once',
      );
      await tester.scrollUntilVisible(
        find.byKey(Keys.galleryTile(121)),
        400,
        scrollable: find.descendant(
          of: find.byKey(Keys.galleryGrid),
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 35,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Keys.galleryTile(121)));
      await pumpUntil(
        tester,
        () => find.byKey(Keys.viewerVideoState).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
        '122 / 122',
      );
      expect(tester.takeException(), isNull);
      expect(await vault.list(), hasLength(122));
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      for (final file in await vault.list()) {
        if (file.uri.pathSegments.last.startsWith('2088-many-')) {
          await file.delete();
        }
      }
    }
  });

  testWidgets(
    'share photo/video copies through chooser without changing the vault',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final sent = <String>[];
      final temp = await getTemporaryDirectory();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        final mime = (args['mimeTypes'] as List).single as String;
        final file = File((args['paths'] as List).single as String);
        expect(
          await file.readAsBytes(),
          fixtureBytes(mime == 'image/jpeg' ? 'tiny.jpg' : 'tiny.mp4'),
        );
        sent.add(mime);
        final cache = await Directory('${temp.path}/share_plus').create();
        await file.copy('${cache.path}/${file.uri.pathSegments.last}');
        return ''; // Script native dismissal; no external app receives media.
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(app.widget());
      await pumpUntil(
        tester,
        () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(Keys.openGallery));
      await pumpUntil(
        tester,
        () => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Keys.galleryTile(0)));
      await pumpUntil(
        tester,
        () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Keys.viewerShare));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(Keys.shareDialog), findsOneWidget);
      await tester.tap(find.byKey(Keys.shareCancel));
      await tester.pump(const Duration(milliseconds: 500));
      expect(sent, isEmpty);
      for (final expected in ['image/jpeg', 'video/mp4']) {
        await tester.tap(find.byKey(Keys.viewerShare));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(Keys.shareConfirm));
        await pumpUntil(tester, () => sent.contains(expected));
        await pumpUntil(
          tester,
          () =>
              tester
                  .widget<IconButton>(find.byKey(Keys.viewerShare))
                  .onPressed !=
              null,
        );
        expect(
          await Directory('${temp.path}/quietake-share').exists(),
          isFalse,
        );
        expect(await Directory('${temp.path}/share_plus').exists(), isFalse);
        expect(await vault.list(), hasLength(2));
        if (expected == 'image/jpeg') {
          await swipeViewerPage(tester, forward: true);
          await waitForPage(tester, '2 / 2');
          expect(
            tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
            '2 / 2',
          );
        }
      }
      expect(sent, ['image/jpeg', 'video/mp4']);
    },
  );

  testWidgets('extreme photo previews stay bounded and preserve originals', (
    tester,
  ) async {
    Future<Size> decodedSize(Image image) async {
      final decoded = Completer<Size>();
      final stream = image.image.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, _) {
          if (!decoded.isCompleted) {
            decoded.complete(
              Size(info.image.width.toDouble(), info.image.height.toDouble()),
            );
          }
          info.dispose();
        },
        onError: (Object error, StackTrace? stack) =>
            decoded.completeError(error, stack),
      );
      stream.addListener(listener);
      try {
        return await decoded.future.timeout(const Duration(seconds: 10));
      } finally {
        stream.removeListener(listener);
      }
    }

    final temp = await getTemporaryDirectory();
    for (final name in ['wide.png', 'tall.png']) {
      final data = fixtureBytes(name);
      final plain = await File('${temp.path}/$name').writeAsBytes(data);
      final file = await vault.ingestAs(plain, '9998-$name');
      try {
        await tester.pumpWidget(app.widget());
        await pumpUntil(
          tester,
          () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(Keys.openGallery));
        final tile = find.descendant(
          of: find.byKey(Keys.galleryTile(0)),
          matching: find.byKey(Keys.galleryPreview),
        );
        await pumpUntil(tester, () => tile.evaluate().isNotEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        // Tiles paint the decoded preview directly; its size is the decode size.
        final thumbnail = tester.widget<RawImage>(tile).image!;
        expect(thumbnail.width, inInclusiveRange(1, 300));
        expect(thumbnail.height, inInclusiveRange(1, 300));
        await tester.tap(find.byKey(Keys.galleryTile(0)));
        await pumpUntil(
          tester,
          () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 500));
        final size = await decodedSize(
          tester.widget<Image>(find.byKey(Keys.viewerPhoto)),
        );
        expect(size.width, inInclusiveRange(1, 4096));
        expect(size.height, inInclusiveRange(1, 4096));
        expect(
          await vault.readAll(file),
          data,
          reason: 'Preview resizing must preserve encrypted originals',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        if (await file.exists()) await file.delete();
      }
    }
  });
}
