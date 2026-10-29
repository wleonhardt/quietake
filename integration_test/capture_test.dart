import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/vault/vault.dart';
import 'package:video_player/video_player.dart';

import '../test_support/mp4.dart';
import 'harness.dart';

/// End-to-end capture tests. Run with tool/e2e.sh, which grants the camera
/// permission first so no native dialog appears.
///
/// On a device or emulator with a camera: shutter and video both produce one
/// decryptable container with the right magic bytes. On the iOS simulator,
/// which has no camera, the app must show "No camera" and stay usable.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;
  late Vault vault;

  setUpAll(() async {
    app = await TestApp.unlocked();
    vault = app.vault;
    for (final f in await vault.list()) {
      await f.delete();
    }
  });

  Future<void> pumpUntil(
    WidgetTester tester,
    Future<bool> Function() done, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!await done()) {
      if (DateTime.now().isAfter(end)) {
        final status = find.byKey(Keys.status).evaluate().isEmpty
            ? 'none'
            : tester.widget<Text>(find.byKey(Keys.status)).data;
        fail(
          'timed out after $timeout; status=$status; cast=${app.session.cast.isCasting}; loaded=${app.backend.loadedType}',
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<Uint8List> head(File container, int n) async {
    final b = BytesBuilder(copy: false);
    await for (final chunk in vault.read(container)) {
      b.add(chunk);
      if (b.length >= n) break;
    }
    return b.takeBytes().sublist(0, n);
  }

  testWidgets('boots, captures a photo and a video into the vault', (
    tester,
  ) async {
    await tester.pumpWidget(app.widget());
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
    );
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    final labelY = tester.getTopLeft(find.text('Photo')).dy;
    expect(tester.getTopLeft(find.text('Video')).dy, labelY);
    expect(tester.getTopLeft(find.text('Library')).dy, labelY);
    final cameras = await availableCameras();
    await pumpUntil(
      tester,
      () async =>
          tester.widget<TextButton>(find.byKey(Keys.captureAlbum)).onPressed !=
          null,
    );
    Future<void> albumTap(Key key) async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.byKey(key));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(key).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(key));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await albumTap(Keys.captureAlbum);
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.captureAlbumCreate).evaluate().isNotEmpty,
    );
    await albumTap(Keys.captureAlbumCreate);
    final albumName = 'Camera test ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(find.byKey(Keys.libraryName), albumName);
    FocusManager.instance.primaryFocus?.unfocus();
    await albumTap(Keys.librarySave);
    await pumpUntil(
      tester,
      () async => vault.catalog.albums.containsValue(albumName),
    );
    final albumId = vault.catalog.albums.entries
        .singleWhere((e) => e.value == albumName)
        .key;
    await albumTap(Keys.captureAlbumCreate);
    final actionName = 'Action ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(find.byKey(Keys.libraryName), actionName);
    FocusManager.instance.primaryFocus?.unfocus();
    await albumTap(Keys.librarySave);
    await pumpUntil(
      tester,
      () async => vault.catalog.albums.containsValue(actionName),
    );
    final actionId = vault.catalog.albums.entries
        .singleWhere((e) => e.value == actionName)
        .key;
    await albumTap(Keys.tagPickerApply);
    expect(find.text('2 tags'), findsOneWidget);
    await albumTap(Keys.captureAlbum);
    await albumTap(Keys.captureAlbumClose);
    expect(
      find.text('2 tags'),
      findsOneWidget,
      reason: 'Dismissal preserves selection',
    );

    if (cameras.isEmpty) {
      await pumpUntil(
        tester,
        () async => find.text('No camera').evaluate().isNotEmpty,
      );
      expect(find.byKey(Keys.preview), findsNothing);
      expect(find.byKey(Keys.cameraFlip), findsNothing);
      await albumTap(Keys.captureAlbum);
      await albumTap(Keys.captureAlbumNone);
      await albumTap(Keys.tagPickerApply);
      expect(find.text('Tags'), findsOneWidget);
      return;
    }

    // A real phone may be answering the camera and microphone dialogs here.
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.preview).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 120),
    );

    final hasBothLenses =
        cameras.any((c) => c.lensDirection == CameraLensDirection.front) &&
        cameras.any((c) => c.lensDirection == CameraLensDirection.back);
    CameraController currentCamera() =>
        tester.widget<CameraPreview>(find.byType(CameraPreview)).controller;
    Future<void> flipTo(CameraLensDirection lens) async {
      await tester.tap(find.byKey(Keys.cameraFlip));
      await pumpUntil(
        tester,
        () async =>
            currentCamera().description.lensDirection == lens &&
            currentCamera().value.isInitialized &&
            tester.widget<IconButton>(find.byKey(Keys.cameraFlip)).onPressed !=
                null,
      );
    }

    if (hasBothLenses) {
      expect(find.byKey(Keys.cameraFlip), findsOneWidget);
      expect(
        currentCamera().description.lensDirection,
        CameraLensDirection.back,
      );
      await flipTo(CameraLensDirection.front);
      expect(
        tester.widget<IconButton>(find.byKey(Keys.cameraFlip)).tooltip,
        'Switch to rear camera',
      );
    } else {
      expect(find.byKey(Keys.cameraFlip), findsNothing);
    }

    // Photo.
    await tester.tap(find.byKey(Keys.shutter));
    await pumpUntil(tester, () async => (await vault.list()).length == 1);
    final photo = (await vault.list()).single;
    expect(photo.path, endsWith('.jpg.shtr'));
    expect(await head(photo, 3), [0xFF, 0xD8, 0xFF], reason: 'JPEG SOI');
    await pumpUntil(
      tester,
      () async =>
          find.byKey(Keys.status).evaluate().isNotEmpty &&
          tester.widget<Text>(find.byKey(Keys.status)).data == 'Saved securely',
    );
    final status = tester.widget<Text>(find.byKey(Keys.status)).data!;
    expect(status, 'Saved securely');
    expect(vault.catalog.details(photo.uri.pathSegments.last).albums, {
      albumId,
      actionId,
    });
    debugPrint('PHOTO $status');
    if (hasBothLenses) await flipTo(CameraLensDirection.back);

    // Transient inactive/resumed events (such as system prompts) must not
    // allocate a second camera when no background pause occurred.
    final existingCamera = tester
        .widget<CameraPreview>(find.byType(CameraPreview))
        .controller;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<CameraPreview>(find.byType(CameraPreview)).controller,
      same(existingCamera),
    );

    // Video: start, record two seconds (red frame showing), stop.
    await tester.tap(find.byKey(Keys.videoToggle));
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.captureRecordingFrame).evaluate().isNotEmpty,
    );
    if (hasBothLenses) {
      expect(
        tester.widget<IconButton>(find.byKey(Keys.cameraFlip)).onPressed,
        isNull,
      );
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(Keys.videoToggle));
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.captureFlash).evaluate().isNotEmpty,
    );
    await pumpUntil(tester, () async => (await vault.list()).length == 2);
    final video = (await vault.list()).firstWhere(
      (f) => f.path.endsWith('.mp4.shtr'),
    );
    final h = await head(video, 12);
    expect(String.fromCharCodes(h.sublist(4, 8)), 'ftyp', reason: 'MP4 box');
    expect(
      mp4SampleEntries(await vault.readAll(video)),
      containsAll(['avc1', 'mp4a']),
      reason: 'New recordings must contain H.264 video and AAC audio',
    );
    if (Platform.isAndroid) {
      // A second preparation of compatible media must bypass conversion.
      final bytes = await vault.readAll(video);
      final temp = await getTemporaryDirectory();
      final input = await File('${temp.path}/compatible-check.mp4')
          .writeAsBytes(bytes);
      try {
        final path = await const MethodChannel('quietake/camera')
            .invokeMethod<String>('prepareVideo', {
              'path': input.path,
              'pending': '${vault.dir.path}/.captures',
            });
        expect(path, await input.resolveSymbolicLinks());
        expect(listEquals(await input.readAsBytes(), bytes), isTrue);
      } finally {
        if (await input.exists()) await input.delete();
      }
    }
    final playbackUrl = app.session.server.register(video);
    final player = VideoPlayerController.networkUrl(playbackUrl);
    try {
      await player.initialize().timeout(const Duration(seconds: 15));
      expect(player.value.duration, greaterThan(const Duration(seconds: 1)));
      await player.play();
      await pumpUntil(
        tester,
        () async => player.value.position.inMilliseconds > 400,
      );
      expect(player.value.hasError, isFalse);
    } finally {
      await player.dispose();
      app.session.server.unregister(playbackUrl);
    }
    await pumpUntil(
      tester,
      () async =>
          tester.widget<Text>(find.byKey(Keys.status)).data == 'Saved securely',
    );
    debugPrint('VIDEO ${tester.widget<Text>(find.byKey(Keys.status)).data}');
    expect(vault.catalog.details(video.uri.pathSegments.last).albums, {
      albumId,
      actionId,
    });
    await vault.catalog.load();
    expect(vault.catalog.details(photo.uri.pathSegments.last).albums, {
      albumId,
      actionId,
    });
    expect(vault.catalog.details(video.uri.pathSegments.last).albums, {
      albumId,
      actionId,
    });
    await albumTap(Keys.captureAlbum);
    await albumTap(Keys.captureAlbumNone);
    await albumTap(Keys.tagPickerApply);
    expect(find.text('Tags'), findsOneWidget);
    if (hasBothLenses) await flipTo(CameraLensDirection.front);

    // Cast from the camera: connect first, then every capture lands on the TV.
    await tester.tap(find.byKey(Keys.captureCast));
    debugPrint('CAST discovery requested');
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.castDevice(0)).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(Keys.castDevice(0)));
    expect(find.byKey(Keys.castDevice(0)).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(Keys.castDevice(0)));
    await pumpUntil(tester, () async => app.session.cast.isCasting);
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.captureCastState).evaluate().isNotEmpty,
    );
    expect(
      tester.widget<Text>(find.byKey(Keys.captureCastState)).data,
      'Casting to Living Room TV',
    );
    expect(
      app.backend.loadedUrl,
      isNull,
      reason: 'nothing shown until something is captured',
    );
    await pumpUntil(
      tester,
      () async =>
          tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed != null,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.shutter));
    await tester.pump();
    await pumpUntil(tester, () async => app.backend.loadedType == 'image/jpeg');
    expect((await vault.list()).length, 3);
    debugPrint('CAST capture saved');
    // Backgrounding a recording saves it before releasing the camera.
    await pumpUntil(
      tester,
      () async =>
          tester.widget<IconButton>(find.byKey(Keys.videoToggle)).onPressed !=
          null,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.videoToggle));
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.captureRecordingFrame).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 2));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    // A paused app does not produce frames. Observe storage directly here,
    // then resume before asking the widget binding for another frame.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while ((await vault.list()).length != 4) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Background recording was not saved');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final saved = (await vault.list()).first;
      expect(saved.path, endsWith('.mp4.shtr'));
      final header = await head(saved, 12);
      expect(String.fromCharCodes(header.sublist(4, 8)), 'ftyp');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    debugPrint('BACKGROUND capture saved');
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await pumpUntil(
      tester,
      () async => find.byKey(Keys.preview).evaluate().isNotEmpty,
    );
    if (hasBothLenses) {
      expect(
        currentCamera().description.lensDirection,
        CameraLensDirection.front,
        reason: 'Resume must retain the selected lens',
      );
    }
    await pumpUntil(tester, () async => app.backend.loadedType == 'video/mp4');
    final recorded = (await vault.list()).first;
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(app.backend.loadedUrl!))
          .close()
          .timeout(const Duration(seconds: 10));
      expect(response.statusCode, 200);
      final bytes = await response
          .fold<BytesBuilder>(BytesBuilder(), (out, chunk) => out..add(chunk))
          .timeout(const Duration(seconds: 10));
      final received = bytes.takeBytes();
      expect(listEquals(received, await vault.readAll(recorded)), isTrue);
      expect(mp4SampleEntries(received), containsAll(['avc1', 'mp4a']));
    } finally {
      client.close(force: true);
    }
    await tester.tap(find.byKey(Keys.captureCast));
    await pumpUntil(tester, () async => !app.session.cast.isCasting);

    // Plaintext temp files are gone.
    final cacheLeft = await (await getTemporaryDirectory())
        .list(recursive: true)
        .where((e) => e.path.endsWith('.jpg') || e.path.endsWith('.mp4'))
        .length;
    expect(cacheLeft, 0, reason: 'no plaintext left in temp');
  });

  testWidgets(
    'conversion failure encrypts original and does not auto-cast it',
    (tester) async {
      const channel = MethodChannel('quietake/camera');
      Uint8List? original;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'requestMicrophone') return true;
        expect(call.method, 'prepareVideo');
        original = await File((call.arguments as Map)['path'] as String)
            .readAsBytes();
        throw PlatformException(code: 'video_preparation');
      });
      try {
        await tester.pumpWidget(app.widget());
        await pumpUntil(
          tester,
          () async => find.byKey(Keys.preview).evaluate().isNotEmpty,
        );
        await app.session.cast.start(app.backend.available.first, null);
        await tester.pump(const Duration(milliseconds: 500));
        final before = (await vault.list()).map((file) => file.path).toSet();
        await tester.tap(find.byKey(Keys.videoToggle));
        await pumpUntil(
          tester,
          () async =>
              find.byKey(Keys.captureRecordingFrame).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.byKey(Keys.videoToggle));
        await pumpUntil(
          tester,
          () async =>
              find.byKey(Keys.status).evaluate().isNotEmpty &&
              tester.widget<Text>(find.byKey(Keys.status)).data ==
                  'Saved securely. This video may not play on your TV.',
        );
        final saved = (await vault.list()).singleWhere(
          (file) => !before.contains(file.path),
        );
        expect(original, isNotNull);
        expect(listEquals(await vault.readAll(saved), original), isTrue);
        expect(app.backend.loadedUrl, isNull);
        expect(
          await (await getTemporaryDirectory())
              .list(recursive: true)
              .where((file) => file.path.endsWith('.mp4'))
              .length,
          0,
        );
      } finally {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        await app.session.cast.stop();
      }
    },
    skip: !Platform.isAndroid,
  );

  for (
    var attempt = 0;
    attempt <
        const int.fromEnvironment('CAPTURE_RESUME_REPEATS', defaultValue: 1);
    attempt++
  ) {
    testWidgets(
      'foreground resume waits for pending video preparation #$attempt',
      (tester) async {
        const channel = MethodChannel('quietake/camera');
        final preparing = Completer<void>();
        final finish = Completer<void>();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          if (call.method == 'requestMicrophone') return true;
          expect(call.method, 'prepareVideo');
          final source = File((call.arguments as Map)['path'] as String);
          debugPrint('RESUME capture bytes=${await source.length()}');
          preparing.complete();
          await finish.future;
          return (call.arguments as Map)['path'];
        });
        await tester.pumpWidget(app.widget());
        await pumpUntil(
          tester,
          () async => find.byKey(Keys.preview).evaluate().isNotEmpty,
        );
        final before = (await vault.list()).length;
        await tester.tap(find.byKey(Keys.videoToggle));
        await pumpUntil(
          tester,
          () async =>
              find.byKey(Keys.captureRecordingFrame).evaluate().isNotEmpty,
        );
        final recordingCamera = tester
            .widget<CameraPreview>(find.byType(CameraPreview))
            .controller;
        // CameraX start precedes its first encoded frame. Wait for native data
        // so this lifecycle case tests saving, rather than an empty recording.
        await pumpUntil(tester, () async {
          await for (final entry in (await getTemporaryDirectory()).list(
            recursive: true,
          )) {
            if (entry is File &&
                entry.path.endsWith('.mp4') &&
                await entry.length() > 0) {
              return true;
            }
          }
          return false;
        });
        await tester.pump(const Duration(seconds: 2));
        try {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.runAsync(
            () => preparing.future.timeout(const Duration(seconds: 20)),
          );
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.pump(const Duration(milliseconds: 500));
          await app.session.cast.start(app.backend.available.first, null);
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            recordingCamera.value.lockedCaptureOrientation,
            isNull,
            reason: 'Cast orientation must not reconfigure a retiring camera',
          );
          for (final key in [
            Keys.shutter,
            Keys.videoToggle,
            Keys.openGallery,
            if (find.byKey(Keys.cameraFlip).evaluate().isNotEmpty)
              Keys.cameraFlip,
          ]) {
            expect(
              tester.widget<IconButton>(find.byKey(key)).onPressed,
              isNull,
              reason: 'Pending background preparation must keep capture controls disabled',
            );
          }
        } finally {
          if (!finish.isCompleted) finish.complete();
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await pumpUntil(
            tester,
            () async =>
                find.byKey(Keys.preview).evaluate().isNotEmpty &&
                !identical(
                  tester
                      .widget<CameraPreview>(find.byType(CameraPreview))
                      .controller,
                  recordingCamera,
                ) &&
                tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed !=
                    null,
          );
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          await app.session.cast.stop();
        }
        expect(
          (await vault.list()).length,
          before + 1,
          reason: 'Finalized background recording must remain in vault',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(Keys.shutter));
        await pumpUntil(
          tester,
          () async => (await vault.list()).length == before + 2,
        );
        await pumpUntil(
          tester,
          () async =>
              tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed !=
              null,
        );
        expect(await head((await vault.list()).first, 3), [0xff, 0xd8, 0xff]);
        expect(
          await (await getTemporaryDirectory())
              .list(recursive: true)
              .where(
                (file) =>
                    file.path.endsWith('.mp4') || file.path.endsWith('.jpg'),
              )
              .length,
          0,
        );
      },
      skip: !Platform.isAndroid,
    );
  }
}
