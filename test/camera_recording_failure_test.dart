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
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/controlled_camera.dart';
import '../test_support/fake_cast_backend.dart';

class _FailingStopCamera extends ControlledCamera {
  _FailingStopCamera(super.directory);
  var stops = 0;

  @override
  Future<XFile> stopVideoRecording(int id) async {
    stops++;
    throw CameraException('videoRecordingFailed', 'Recorder stopped early');
  }
}

class _FailingStartCamera extends ControlledCamera {
  _FailingStartCamera(super.directory);

  @override
  Future<void> startVideoRecording(int id, {Duration? maxVideoDuration}) async {
    throw CameraException('videoRecordingFailed', 'Encoder unavailable');
  }
}

Future<({Directory directory, Session session})> _boot(
  WidgetTester tester,
) async {
  late Directory directory;
  late Session session;
  await tester.runAsync(() async {
    directory = await Directory.systemTemp.createTemp('camera-failure');
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

void main() {
  testWidgets('a failed recording start names the recorder, not the save', (
    tester,
  ) async {
    final previousCamera = CameraPlatform.instance;
    final (:directory, :session) = await _boot(tester);
    final camera = _FailingStartCamera(directory);
    CameraPlatform.instance = camera;
    const cameraChannel = MethodChannel('quietake/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cameraChannel,
      (_) async => true,
    );
    try {
      await tester.pumpWidget(
        MaterialApp(home: CaptureScreen(session: session)),
      );
      await _until(
        tester,
        () => find.byKey(Keys.preview).evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(Keys.videoToggle));
      await _until(
        tester,
        () => find
            .text('Could not start recording. Try again.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.byKey(Keys.captureTimer), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await _until(tester, () => camera.disposed.length >= camera.created);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await session.close();
        await directory.delete(recursive: true);
      });
      CameraPlatform.instance = previousCamera;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        cameraChannel,
        null,
      );
    }
  });

  testWidgets(
    'a recovery failure still opens the camera with a storage status',
    (tester) async {
      final previousCamera = CameraPlatform.instance;
      final (:directory, :session) = await _boot(tester);
      final captures = Directory('${directory.path}/.captures');
      await tester.runAsync(() async {
        await captures.create();
        await Process.run('chmod', ['000', captures.path]);
      });
      final camera = ControlledCamera(directory);
      CameraPlatform.instance = camera;
      try {
        await tester.pumpWidget(
          MaterialApp(home: CaptureScreen(session: session)),
        );
        await _until(
          tester,
          () => find.byKey(Keys.preview).evaluate().isNotEmpty,
        );
        expect(
          find.textContaining('pending captures'),
          findsOneWidget,
          reason: 'storage trouble is named; the camera is not blamed',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await _until(tester, () => camera.disposed.length >= camera.created);
        await tester.runAsync(() async {
          await Process.run('chmod', ['755', captures.path]);
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await session.close();
          await directory.delete(recursive: true);
        });
        CameraPlatform.instance = previousCamera;
      }
    },
  );

  testWidgets('a failed recording stop releases recording state', (
    tester,
  ) async {
    final previousCamera = CameraPlatform.instance;
    var locked = false;
    final privacy = PrivacyController(
      onLock: () => locked = true,
      timeoutOverride: const Duration(milliseconds: 50),
    )..minutes = 1;
    late Directory directory;
    late Session session;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('camera-stop-failure');
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
    final camera = _FailingStopCamera(directory);
    CameraPlatform.instance = camera;
    const cameraChannel = MethodChannel('quietake/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cameraChannel,
      (_) async => true,
    );
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue);
    }

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacyScope(
            controller: privacy,
            child: CaptureScreen(session: session),
          ),
        ),
      );
      await until(() => find.byKey(Keys.preview).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Keys.videoToggle));
      await until(() => find.byKey(Keys.captureTimer).evaluate().isNotEmpty);
      // Recording holds the idle timer: enabling privacy now must not lock.
      privacy.setEnabled(true);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      expect(locked, isFalse);

      await tester.tap(find.byKey(Keys.videoToggle));
      await until(() => camera.stops == 1);
      await until(() => find.byKey(Keys.captureTimer).evaluate().isEmpty);
      expect(find.text('Could not stop recording. Try again.'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      // The hold is released, so the idle timer runs again and locks.
      await until(() => locked);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await until(() => camera.disposed.length >= camera.created);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await session.close();
        await directory.delete(recursive: true);
      });
      CameraPlatform.instance = previousCamera;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        cameraChannel,
        null,
      );
      privacy.dispose();
    }
  });
}
