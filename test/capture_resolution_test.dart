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
  testWidgets(
    'photos use the full sensor before and after a recording (decision 034)',
    (tester) async {
      final previousCamera = CameraPlatform.instance;
      late Directory directory;
      late Session session;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('camera-resolution');
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
      final camera = ControlledCamera(directory);
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
        expect(camera.opened, [(ResolutionPreset.max, false)]);

        await tester.tap(find.byKey(Keys.videoToggle));
        await _until(
          tester,
          () => find.byKey(Keys.captureTimer).evaluate().isNotEmpty,
        );
        // 1080p unless the owner chose another video quality (decision 034).
        expect(camera.opened.last, (ResolutionPreset.veryHigh, true));

        // The controlled camera returns an empty clip, so the save fails; the
        // photo camera must come back either way.
        await tester.tap(find.byKey(Keys.videoToggle));
        await _until(tester, () => camera.opened.length == 3);
        expect(camera.opened.last, (ResolutionPreset.max, false));
        await _until(
          tester,
          () => find.byKey(Keys.preview).evaluate().isNotEmpty,
        );
        // Lets the 180 ms capture flash finish before the screen goes.
        await tester.pump(const Duration(milliseconds: 200));
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
    },
  );
}
