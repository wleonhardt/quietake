import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Holds every recording until [recorded] gets an event, like CameraX before
/// the video source streams, and counts the stops that reach the platform.
class _SlowStartCamera extends ControlledCamera {
  _SlowStartCamera(super.directory) {
    streamsAtStart = false;
  }
  var stops = 0;

  @override
  Future<XFile> stopVideoRecording(int id) {
    stops++;
    return super.stopVideoRecording(id);
  }
}

Future<({Directory directory, Session session})> _boot(
  WidgetTester tester,
) async {
  late Directory directory;
  late Session session;
  await tester.runAsync(() async {
    directory = await Directory.systemTemp.createTemp('camera-start');
    final sodium = await SodiumSumoInit.init();
    final vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      directory,
    );
    session = Session(
      vault: vault,
      server: await MediaServer.start(vault),
      cast: CastController(vault, FakeCastBackend()),
      store: MasterKeyStore(sodium, directory),
    );
  });
  return (directory: directory, session: session);
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue);
}

Future<void> _settle(WidgetTester tester, Duration duration) async {
  await tester.runAsync(() => Future<void>.delayed(duration));
  await tester.pump(duration);
}

void main() {
  late Directory directory;
  late Session session;
  late _SlowStartCamera camera;
  late CameraPlatform previousCamera;
  const channel = MethodChannel('quietake/camera');

  Future<void> record(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: CaptureScreen(session: session)));
    await _until(tester, () => find.byKey(Keys.preview).evaluate().isNotEmpty);
    await tester.tap(find.byKey(Keys.videoToggle));
    await _until(tester, () => find.text('Stop').evaluate().isNotEmpty);
  }

  setUp(() {
    previousCamera = CameraPlatform.instance;
  });

  Future<void> boot(WidgetTester tester) async {
    (:directory, :session) = await _boot(tester);
    camera = _SlowStartCamera(directory);
    CameraPlatform.instance = camera;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      // Microphone granted; host prepareVideo returns the recording unchanged.
      (call) async => call.method == 'prepareVideo'
          ? (call.arguments as Map)['path']
          : true,
    );
  }

  Future<void> shutdown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => camera.disposed.length >= camera.created);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await session.close();
      await directory.delete(recursive: true);
    });
    CameraPlatform.instance = previousCamera;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  }

  testWidgets('recording shows as live only after the first video data', (
    tester,
  ) async {
    await boot(tester);
    try {
      await record(tester);
      expect(find.byKey(Keys.captureStarting), findsOneWidget);
      expect(find.byKey(Keys.captureTimer), findsNothing);
      expect(find.byKey(Keys.captureRecordingFrame), findsNothing);

      camera.recorded.add(null);
      await _until(
        tester,
        () => find.byKey(Keys.captureTimer).evaluate().isNotEmpty,
      );
      expect(find.byKey(Keys.captureRecordingFrame), findsOneWidget);
      expect(find.byKey(Keys.captureStarting), findsNothing);

      await tester.tap(find.byKey(Keys.videoToggle));
      await _until(tester, () => camera.stops == 1);
      expect(tester.takeException(), isNull);
    } finally {
      await shutdown(tester);
    }
  });

  testWidgets('a stop before any video data waits for the first frames', (
    tester,
  ) async {
    await boot(tester);
    camera.empty = false;
    try {
      await record(tester);
      await tester.tap(find.byKey(Keys.videoToggle));
      await _settle(tester, const Duration(milliseconds: 300));
      expect(camera.stops, 0);
      expect(find.byKey(Keys.captureStarting), findsOneWidget);

      camera.recorded.add(null);
      await _until(tester, () => camera.stops == 1);
      await _until(
        tester,
        () => find.textContaining('Saved securely').evaluate().isNotEmpty,
      );
      expect(find.byKey(Keys.captureStarting), findsNothing);
      expect(find.text('Video'), findsOneWidget);
      late int saved;
      await tester.runAsync(() async {
        saved = (await session.vault.list()).length;
      });
      expect(saved, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await shutdown(tester);
    }
  });

  testWidgets('a stop gives up waiting when no video data ever arrives', (
    tester,
  ) async {
    await boot(tester);
    try {
      await record(tester);
      await tester.tap(find.byKey(Keys.videoToggle));
      await _settle(tester, const Duration(milliseconds: 300));
      expect(camera.stops, 0);

      await tester.pump(const Duration(seconds: 5));
      await _until(tester, () => camera.stops == 1);
      await _until(
        tester,
        () => find
            .text('No video frames were recorded. Try again.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Video'), findsOneWidget);
      // Let the capture flash finish before the tree goes away.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    } finally {
      await shutdown(tester);
    }
  });
}
