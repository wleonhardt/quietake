import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../test_support/fake_cast_backend.dart';

class _RealHttp extends HttpOverrides {}

/// A deterministic 30-second decoder for seek-call and recovery assertions.
/// Native integration tests separately exercise the real platform decoders.
class _VideoPlatform extends VideoPlayerPlatform {
  final sources = <int, String>{};
  final positions = <int, Duration>{};
  final disposed = <int>[];
  final seeks = <Duration>[];
  bool failFirst = false;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length + 1;
    sources[id] = options.dataSource.uri!;
    positions[id] = Duration.zero;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => failFirst && playerId == 1
      ? Stream<VideoEvent>.error(
          PlatformException(
            code: 'test-decoder-error',
            message: 'Decoder failed',
          ),
        )
      : Stream<VideoEvent>.value(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 30),
            size: const Size(160, 120),
          ),
        );
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => positions[playerId]!;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add(position);
    positions[playerId] = position;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

void main() {
  late Directory root;
  late Session session;
  late File file;
  late _VideoPlatform platform;
  late VideoPlayerPlatform original;

  setUp(() async {
    original = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    final sodium = await SodiumSumoInit.init();
    root = await Directory.systemTemp.createTemp('quietake-video-controls');
    final vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      Directory('${root.path}/vault')..createSync(),
    );
    file = await vault.ingestAs(
      await File('test_fixtures/tiny.mp4').copy('${root.path}/input.mp4'),
      'video.mp4',
    );
    session = Session(
      vault: vault,
      server: await MediaServer.start(vault),
      cast: CastController(vault, FakeCastBackend()),
      store: MasterKeyStore(sodium, root),
    );
  });
  tearDown(() async {
    VideoPlayerPlatform.instance = original;
    await session.close();
    await root.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: ViewerScreen(
          session: session,
          items: [VaultItem(file)],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets(
      'transport preserves pause, clamps skips and seeks once at $size',
      (tester) async {
        await open(tester, size: size);
        final player = tester
            .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
            .controller;
        await tester.tap(find.byKey(Keys.viewerPlay));
        await tester.pump();
        expect(player.value.isPlaying, isFalse);
        final slider = tester.widget<Slider>(find.byKey(Keys.viewerSeek));
        slider.onChangeStart!(0);
        slider.onChanged!(10000);
        slider.onChanged!(20000);
        await tester.pump();
        expect(
          platform.seeks,
          isEmpty,
          reason: 'Dragging must not request intermediate decrypt/seek work',
        );
        expect(
          tester.widget<Text>(find.byKey(Keys.viewerVideoState)).data,
          '0:20 / 0:30',
        );
        tester.widget<Slider>(find.byKey(Keys.viewerSeek)).onChangeEnd!(20000);
        await tester.pump();
        expect(platform.seeks, [const Duration(seconds: 20)]);
        expect(player.value.isPlaying, isFalse);
        await tester.tap(find.byKey(Keys.viewerSkipForward));
        await tester.pump();
        expect(player.value.position, const Duration(seconds: 30));
        expect(
          tester.widget<IconButton>(find.byKey(Keys.viewerPlay)).tooltip,
          'Replay video',
        );
        await tester.tap(find.byKey(Keys.viewerSkipBack));
        await tester.pump();
        expect(player.value.position, const Duration(seconds: 20));
        await player.seekTo(const Duration(seconds: 5));
        await tester.tap(find.byKey(Keys.viewerSkipBack));
        await tester.pump();
        expect(player.value.position, Duration.zero);
        await tester.tap(find.byKey(Keys.viewerMute));
        await tester.pump();
        expect(player.value.volume, 0);
        expect(
          tester.widget<IconButton>(find.byKey(Keys.viewerMute)).tooltip,
          'Unmute video',
        );
        await tester.tap(find.byKey(Keys.viewerMute));
        await tester.pump();
        expect(player.value.volume, 1);
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
        expect(
          player.value.isPlaying,
          isFalse,
          reason: 'Focus mode must not resume a paused video',
        );
        await tester.tap(find.byKey(Keys.viewerControls));
        await tester.pump();
        expect(find.byKey(Keys.viewerSeek), findsOneWidget);
        final semantics = tester.ensureSemantics();
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'completed decoder restarts at zero even with a lagging position',
    (tester) async {
      await open(tester);
      final player = tester
          .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
          .controller;
      await player.pause();
      player.value = player.value.copyWith(
        position: const Duration(milliseconds: 29999),
        isCompleted: true,
      );
      await tester.pump();
      await tester.tap(find.byKey(Keys.viewerPlay));
      await tester.pumpAndSettle();
      expect(platform.seeks, [Duration.zero]);
      expect(player.value.isPlaying, isTrue);
    },
  );

  testWidgets('video retries in place and revokes failed and closed streams', (
    tester,
  ) async {
    platform.failFirst = true;
    await open(tester);
    expect(find.byKey(Keys.viewerError), findsOneWidget);
    final oldUrl = Uri.parse(platform.sources[1]!);
    await tester.tap(find.byKey(Keys.viewerError));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.viewerError), findsNothing);
    expect(
      platform.sources.length,
      2,
      reason: 'Disposed: ${platform.disposed}',
    );
    expect(find.byKey(Keys.viewerVideo), findsOneWidget);
    expect(platform.disposed, contains(1));
    final newUrl = Uri.parse(platform.sources[2]!);
    expect(newUrl, isNot(oldUrl));
    final player = tester
        .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
        .controller;
    expect(player.value.isPlaying, isTrue);
    late HttpClient client;
    await tester.runAsync(() async {
      client = _RealHttp().createHttpClient(null);
    });
    Future<int> status(Uri url) async {
      final response = await (await client.getUrl(url)).close();
      await response.drain<void>();
      return response.statusCode;
    }

    try {
      expect(await tester.runAsync(() => status(oldUrl)), HttpStatus.notFound);
      expect(await tester.runAsync(() => status(newUrl)), HttpStatus.ok);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => status(newUrl)), HttpStatus.notFound);
      expect(await tester.runAsync(() => session.vault.list()), hasLength(1));
    } finally {
      client.close(force: true);
    }
  });
}
