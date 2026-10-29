import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/brand.dart';
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

class _BrightCamera extends ControlledCamera {
  _BrightCamera(super.directory);

  @override
  Future<List<CameraDescription>> availableCameras() async => [
    ...await super.availableCameras(),
    const CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    ),
  ];

  @override
  Widget buildPreview(int id) => const ColoredBox(color: Colors.white);
}

void main() {
  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('camera controls stay legible at $size with $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final previousCamera = CameraPlatform.instance;
        var locked = false;
        final privacy = PrivacyController(onLock: () => locked = true)
          ..minutes = 0;
        privacy.setEnabled(true);
        late Directory directory;
        late Session session;
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp('camera-layout');
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
        final camera = _BrightCamera(directory);
        CameraPlatform.instance = camera;
        const cameraChannel = MethodChannel('quietake/camera');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          cameraChannel,
          (_) async => true,
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: quietakeTheme(brightness: Brightness.light),
              builder: (_, child) => MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: PrivacyScope(controller: privacy, child: child!),
              ),
              home: CaptureScreen(session: session),
            ),
          );
          for (
            var i = 0;
            i < 100 && find.byKey(Keys.preview).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          expect(find.byKey(Keys.preview), findsOneWidget);
          expect(Theme.of(tester.element(find.byKey(Keys.shutter))).brightness, Brightness.dark);
          expect(find.byKey(Keys.cameraFlip).hitTestable(), findsOneWidget);
          for (final key in [
            Keys.shutter,
            Keys.videoToggle,
            Keys.openGallery,
            Keys.captureCast,
            Keys.lockNow,
          ]) {
            final control = find.byKey(key);
            expect(control.hitTestable(), findsOneWidget);
            final panel = find
                .ancestor(of: control, matching: find.byType(Material))
                .first;
            expect(
              find.descendant(of: panel, matching: find.byKey(Keys.preview)),
              findsNothing,
              reason: 'The control needs its own opaque backing above bright preview pixels',
            );
            final color = tester.widget<Material>(panel).color!;
            expect(color.a, 1);
            expect(
              1.05 / (color.computeLuminance() + .05),
              greaterThanOrEqualTo(4.5),
            );
          }
          expect(find.text('Library'), findsOneWidget);
          expect(find.text('Video'), findsOneWidget);
          final labelY = tester.getTopLeft(find.text('Photo')).dy;
          expect(tester.getTopLeft(find.text('Video')).dy, labelY);
          expect(tester.getTopLeft(find.text('Library')).dy, labelY);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byKey(Keys.videoToggle));
          for (
            var i = 0;
            i < 100 && find.byKey(Keys.captureTimer).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          expect(find.byKey(Keys.captureTimer).hitTestable(), findsOneWidget);
          expect(find.text('Stop'), findsOneWidget);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byKey(Keys.videoToggle));
          for (
            var i = 0;
            i < 100 &&
                find
                    .text('No video frames were recorded. Try again.')
                    .evaluate()
                    .isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(
            find.text('No video frames were recorded. Try again.'),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            tester
                .getSemantics(find.byKey(Keys.status))
                .flagsCollection
                .isLiveRegion,
            isTrue,
          );
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byKey(Keys.lockNow));
          expect(locked, isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          for (
            var i = 0;
            i < 100 && camera.disposed.length < camera.created;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
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
          semantics.dispose();
        }
      });
    }
  }
}
