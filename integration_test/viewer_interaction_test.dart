import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:video_player/video_player.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

/// Disposable development vault only. Covers gestures and repeated playback
/// through the real decoder rather than a mocked video platform.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestApp app;

  setUp(() async {
    app = await TestApp.unlocked();
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    final temp = await getTemporaryDirectory();
    for (final extension in ['jpg', 'mp4']) {
      final plain = await File('${temp.path}/interaction.$extension')
          .writeAsBytes(fixtureBytes('tiny.$extension'));
      await app.vault.ingestAs(
        plain,
        '${extension == 'jpg' ? '2099-02' : '2099-01'}.$extension',
      );
      expect(await plain.exists(), isFalse);
    }
  });
  tearDown(() => app.close());

  Future<void> until(WidgetTester tester, bool Function() ready) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Viewer interaction timed out');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester, int index) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    });
    await tester.pumpWidget(app.widget());
    await until(
      tester,
      () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Keys.openGallery));
    await until(
      tester,
      () => find.byKey(Keys.galleryTile(index)).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.galleryTile(index)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pinch(WidgetTester tester, double from, double to) async {
    final center = tester.getCenter(find.byType(InteractiveViewer).first);
    final left = await tester.createGesture(pointer: 1);
    final right = await tester.createGesture(pointer: 2);
    await left.down(center - Offset(from, 0));
    await right.down(center + Offset(from, 0));
    // Gradual movement lets the scale recognizer win its gesture arena.
    for (var step = 1; step <= 8; step++) {
      final distance = from + (to - from) * step / 8;
      await left.moveTo(center - Offset(distance, 0));
      await right.moveTo(center + Offset(distance, 0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await left.up();
    await right.up();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('photo double tap, reset and focus preserve browsing and back', (
    tester,
  ) async {
    await open(tester, 0);
    await until(
      tester,
      () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
    );
    final image = find.byKey(Keys.viewerPhoto);
    double scale() => tester
        .renderObject<RenderBox>(image)
        .getTransformTo(null)
        .getMaxScaleOnAxis();
    final fit = scale();
    Future<void> doubleTap() async {
      final point =
          tester.getCenter(find.byType(InteractiveViewer).first) +
          const Offset(35, 20);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 400));
    }

    await doubleTap();
    expect(scale(), greaterThan(fit * 1.5));
    expect(find.byKey(Keys.viewerFit).hitTestable(), findsOneWidget);
    await doubleTap();
    expect(scale(), closeTo(fit, 0.05));
    await doubleTap();
    await tester.tap(find.byKey(Keys.viewerFit));
    await tester.pump();
    expect(scale(), closeTo(fit, 0.05));
    await tester.tap(find.byKey(Keys.viewerControls));
    await tester.pump();
    // Hidden chrome leaves the tree once its 200 ms fade finishes.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(Keys.viewerShare), findsNothing);
    expect(find.byKey(Keys.viewerBack).hitTestable(), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(Keys.viewerControls)).tooltip,
      'Show controls',
    );
    await tester.tapAt(tester.getCenter(find.byType(InteractiveViewer).first));
    await tester.pump(const Duration(milliseconds: 400));
    // The bar slides in over 200 ms; let the animation finish before hit tests.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(Keys.viewerShare).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(Keys.viewerControls));
    await tester.pump();
    // Let the hidden app bar unmount so pageBack sees one back button.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(Keys.galleryGrid), findsOneWidget);
    expect(await app.vault.list(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'zoomed photo pans vertically; zoom-out restores vertical browsing',
    (tester) async {
      await open(tester, 0);
      await until(
        tester,
        () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
      );
      double scale() => tester
          .renderObject<RenderBox>(find.byKey(Keys.viewerPhoto))
          .getTransformTo(null)
          .getMaxScaleOnAxis();
      final originalScale = scale();
      await pinch(tester, 30, 110);
      expect(scale(), greaterThan(originalScale * 1.5));
      final before = tester.getCenter(find.byKey(Keys.viewerPhoto));
      await tester.drag(
        find.byType(InteractiveViewer).first,
        const Offset(0, -100),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final pager = tester
          .widget<PageView>(find.byKey(Keys.viewerPager))
          .controller!;
      await until(tester, () => !pager.position.isScrollingNotifier.value);
      expect(pager.page, closeTo(0, 0.001));
      expect(
        tester.getCenter(find.byKey(Keys.viewerPhoto)).dy,
        lessThan(before.dy - 50),
        reason: 'Vertical drag of an enlarged photo must move the photo',
      );
      await pinch(tester, 110, 15);
      expect(scale(), closeTo(originalScale, 0.05));
      await tester.fling(
        find.byKey(Keys.viewerPager),
        const Offset(0, -500),
        1500,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await until(
        tester,
        () => find.byKey(Keys.viewerVideo).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
        '2 / 2',
      );
      await tester.fling(
        find.byKey(Keys.viewerPager),
        const Offset(0, 500),
        1500,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
        '1 / 2',
      );
      final files = await app.vault.list();
      expect(files, hasLength(2));
      expect(await app.vault.readAll(files.first), fixtureBytes('tiny.jpg'));
      expect(await app.vault.readAll(files.last), fixtureBytes('tiny.mp4'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native transport mutes, clamps skips and commits seek on release',
    (tester) async {
      await open(tester, 1);
      await until(
        tester,
        () => find.byKey(Keys.viewerVideo).evaluate().isNotEmpty,
      );
      final player = tester
          .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
          .controller;
      await player.pause();
      await player.seekTo(Duration.zero);
      await tester.pump();
      await tester.tap(find.byKey(Keys.viewerMute));
      await tester.pump();
      expect(player.value.volume, 0);
      await tester.tap(find.byKey(Keys.viewerMute));
      await tester.pump();
      expect(player.value.volume, 1);
      await tester.tap(find.byKey(Keys.viewerSkipBack));
      await tester.pump();
      expect(player.value.position, Duration.zero);
      await tester.tap(find.byKey(Keys.viewerSkipForward));
      await until(tester, () => player.value.position == player.value.duration);
      expect(player.value.isPlaying, isFalse);
      expect(
        tester.widget<IconButton>(find.byKey(Keys.viewerPlay)).tooltip,
        'Replay video',
      );
      final slider = tester.widget<Slider>(find.byKey(Keys.viewerSeek));
      slider.onChangeStart!(slider.value);
      slider.onChanged!(300);
      slider.onChanged!(600);
      await tester.pump();
      expect(player.value.position, player.value.duration);
      tester.widget<Slider>(find.byKey(Keys.viewerSeek)).onChangeEnd!(600);
      await until(
        tester,
        () => (player.value.position.inMilliseconds - 600).abs() < 150,
      );
      expect(player.value.isPlaying, isFalse);
      await tester.tap(find.byKey(Keys.viewerControls));
      await tester.pump();
      expect(find.byKey(Keys.viewerSeek), findsNothing);
      expect(
        identical(
          tester.widget<VideoPlayer>(find.byKey(Keys.viewerVideo)).controller,
          player,
        ),
        isTrue,
      );
      expect(player.value.isPlaying, isFalse);
      await tester.tap(find.byKey(Keys.viewerControls));
      await tester.pump();
      expect(find.byKey(Keys.viewerSeek).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed native video retries in place after media becomes available',
    (tester) async {
      final temp = await getTemporaryDirectory();
      final input = File('${temp.path}/retry.mp4');
      final file = await app.vault.ingestAs(
        await input.writeAsBytes([1, 2, 3]),
        '2099-03.mp4',
      );
      await open(tester, 0);
      await until(
        tester,
        () => find.byKey(Keys.viewerError).evaluate().isNotEmpty,
      );
      // Replace the damaged container in place; ingestAs refuses to reuse a
      // name (3.1), and an atomic encryptFile is what recovery does.
      await app.vault.encryptFile(
        await input.writeAsBytes(fixtureBytes('tiny.mp4')),
        file,
      );
      await input.delete();
      await tester.tap(find.byKey(Keys.viewerError));
      await until(
        tester,
        () => find.byKey(Keys.viewerVideo).evaluate().isNotEmpty,
      );
      expect(find.byKey(Keys.viewerError), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(Keys.viewerPosition)).data,
        '1 / 3',
      );
      expect(await app.vault.readAll(file), fixtureBytes('tiny.mp4'));
      expect(await input.exists(), isFalse);
      expect(await app.vault.list(), hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completed video replays and leaving viewer stops its stream', (
    tester,
  ) async {
    await open(tester, 1);
    await until(
      tester,
      () => find.byKey(Keys.viewerVideo).evaluate().isNotEmpty,
    );
    final player = tester
        .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
        .controller;
    final url = Uri.parse(player.dataSource);
    final client = HttpClient();
    addTearDown(client.close);
    for (var replay = 0; replay < 2; replay++) {
      await until(
        tester,
        () => player.value.isCompleted && !player.value.isPlaying,
      );
      expect(
        tester.widget<IconButton>(find.byKey(Keys.viewerPlay)).tooltip,
        'Replay video',
      );
      await tester.tap(find.byKey(Keys.viewerPlay));
      await until(
        tester,
        () => player.value.isPlaying && !player.value.isCompleted,
      );
      expect(player.value.position, lessThan(player.value.duration));
    }
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(Keys.galleryGrid), findsOneWidget);
    final response =
        await (await client.getUrl(url).timeout(const Duration(seconds: 5)))
            .close()
            .timeout(const Duration(seconds: 5));
    expect(
      response.statusCode,
      HttpStatus.notFound,
      reason: 'Closed viewer must revoke playback URL',
    );
    await response.drain<void>();
    expect(await app.vault.list(), hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
