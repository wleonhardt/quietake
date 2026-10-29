import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:video_player/video_player.dart';

import '../test_support/long_video.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ten-minute encrypted video seeks, plays and releases resources', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    final plain = File('${(await getTemporaryDirectory()).path}/long.mp4');
    await writeLongVideo(plain);
    final file = await app.vault.ingestAs(plain, '2099-long.mp4');
    expect(await plain.exists(), isFalse);
    final size = await file.length();
    final rss = ProcessInfo.currentRss;
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> timings) => frames.addAll(timings);
    SchedulerBinding.instance.addTimingsCallback(record);
    Future<void> until(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) fail('Long video deadline');
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    try {
      await tester.pumpWidget(app.widget());
      await until(() => find.byKey(Keys.openGallery).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Keys.openGallery));
      await until(() => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      final startup = Stopwatch()..start();
      await tester.tap(find.byKey(Keys.galleryTile(0)));
      await until(() => find.byKey(Keys.viewerVideo).evaluate().isNotEmpty);
      final player = tester
          .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
          .controller;
      expect(player.value.duration.inSeconds, 600);
      await until(() => player.value.isPlaying);
      await tester.tap(find.byKey(Keys.viewerPlay));
      await until(() => !player.value.isPlaying);
      await tester.pump(const Duration(milliseconds: 500));
      // ignore: avoid_print
      print(
        'LONG startup_ms=${startup.elapsedMilliseconds} encrypted_bytes=$size',
      );
      for (final seconds in [10, 300, 590, 30, 580]) {
        final watch = Stopwatch()..start();
        final slider = tester.widget<Slider>(find.byKey(Keys.viewerSeek));
        slider.onChanged!(seconds * 1000.0);
        await tester.pump();
        tester.widget<Slider>(find.byKey(Keys.viewerSeek)).onChangeEnd!(
          seconds * 1000.0,
        );
        await until(
          () =>
              (player.value.position.inSeconds - seconds).abs() < 2 &&
              !player.value.isBuffering,
        );
        expect(player.value.isPlaying, isFalse);
        await tester.tap(find.byKey(Keys.viewerPlay));
        final before = player.value.position;
        await until(() => player.value.position > before);
        await tester.tap(find.byKey(Keys.viewerPlay));
        await until(() => !player.value.isPlaying);
        // ignore: avoid_print
        print(
          'LONG seek_s=$seconds ready_ms=${watch.elapsedMilliseconds} rss=${ProcessInfo.currentRss}',
        );
      }
      final burst = tester.widget<Slider>(find.byKey(Keys.viewerSeek));
      for (final seconds in [120, 560, 240, 590]) {
        burst.onChanged!(seconds * 1000.0);
        burst.onChangeEnd!(seconds * 1000.0);
      }
      await until(
        () =>
            (player.value.position.inSeconds - 590).abs() < 2 &&
            !player.value.isBuffering,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        player.value.position.inSeconds,
        inInclusiveRange(589, 591),
        reason: 'Last rapid seek wins and stays paused',
      );
      expect(player.value.isPlaying, isFalse);
      final url = Uri.parse(player.dataSource);
      expect(player.value.hasError, isFalse);
      final growth = ProcessInfo.currentRss - rss;
      // A regression guard, not a physical-device performance target.
      expect(growth, lessThan(384 * 1024 * 1024));
      // ignore: avoid_print
      print(
        'LONG rss_growth=$growth frames=${frames.length} slow_frames=${frames.where((f) => f.totalSpan.inMilliseconds > 32).length}',
      );
      await tester.pageBack();
      await until(
        () => find
            .byKey(Keys.viewerVideo, skipOffstage: false)
            .evaluate()
            .isEmpty,
      );
      final client = HttpClient();
      try {
        final request = await client
            .getUrl(url)
            .timeout(const Duration(seconds: 5));
        final response = await request.close().timeout(
          const Duration(seconds: 5),
        );
        expect(
          response.statusCode,
          HttpStatus.notFound,
          reason: 'Closing viewer revokes long-media URL',
        );
        await response.drain<void>();
      } finally {
        client.close(force: true);
      }
      expect(await app.vault.list(), hasLength(1));
      expect(await file.length(), size);
      expect(await plain.exists(), isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(record);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      await app.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
