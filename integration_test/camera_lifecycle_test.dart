import 'dart:io';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    as platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quietake/keys.dart';

import 'harness.dart';
import '../test_support/controlled_camera.dart';
import '../test_support/fixtures.dart';

import 'package:path_provider/path_provider.dart';

class _OrientingCamera extends ControlledCamera {
  _OrientingCamera(super.directory);
  final entered = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<void> lockCaptureOrientation(
    int id,
    DeviceOrientation orientation,
  ) async {
    if (id == 1 && !entered.isCompleted) {
      entered.complete();
      await finish.future;
    }
  }

  @override
  Future<void> unlockCaptureOrientation(int id) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'video waits for pending Cast camera orientation before replacing controller',
    (tester) async {
      final app = await TestApp.unlocked();
      final original = platform.CameraPlatform.instance;
      final camera = _OrientingCamera(await getTemporaryDirectory())
        ..empty = false;
      platform.CameraPlatform.instance = camera;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('quietake/camera'),
        (call) async => call.method == 'requestMicrophone'
            ? true
            : (call.arguments as Map)['path'],
      );
      Future<void> until(bool Function() ready) async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!ready()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Camera orientation checkpoint deadline');
          }
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      try {
        for (final entry in await app.vault.dir.list().toList()) {
          await entry.delete(recursive: true);
        }
        await tester.pumpWidget(app.widget());
        await until(() => find.byKey(Keys.preview).evaluate().isNotEmpty);
        await app.session.cast.start(app.backend.available.first, null);
        await until(() => camera.entered.isCompleted);
        await tester.tap(find.byKey(Keys.videoToggle));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          camera.disposed,
          isNot(contains(1)),
          reason: 'A capture operation must wait for the controller orientation future',
        );
        camera.finish.complete();
        await until(
          () => find.byKey(Keys.captureRecordingFrame).evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(Keys.videoToggle));
        await until(
          () =>
              find.byKey(Keys.status).evaluate().isNotEmpty &&
              tester.widget<Text>(find.byKey(Keys.status)).data ==
                  'Saved securely',
        );
        final saved = (await app.vault.list()).single;
        expect(await app.vault.readAll(saved), fixtureBytes('tiny.mp4'));
        expect(camera.outputs.every((file) => !file.existsSync()), isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        if (!camera.finish.isCompleted) camera.finish.complete();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        await app.close();
        platform.CameraPlatform.instance = original;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('quietake/camera'),
          null,
        );
      }
    },
  );

  testWidgets('camera survives rapid resume and complete screen replacement', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    for (final file in await app.vault.list()) {
      await file.delete();
    }
    final hasCamera = (await availableCameras()).isNotEmpty;
    Future<void> until(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Replacement camera did not become ready');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    try {
      for (var generation = 0; generation < 8; generation++) {
        await tester.pumpWidget(
          KeyedSubtree(key: ValueKey(generation), child: app.widget()),
        );
        await until(
          () => hasCamera
              ? find.byKey(Keys.preview).evaluate().isNotEmpty &&
                    tester
                        .widget<CameraPreview>(find.byType(CameraPreview))
                        .controller
                        .value
                        .isInitialized
              : find.text('No camera').evaluate().isNotEmpty,
        );
        if (generation < 7) {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          // Replace immediately, while the old state's resume/release is queued.
        }
      }
      if (hasCamera) {
        await tester.tap(find.byKey(Keys.shutter));
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while ((await app.vault.list()).isEmpty) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Final camera did not save a photo');
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await until(
          () =>
              find.byKey(Keys.status).evaluate().isNotEmpty &&
              tester.widget<Text>(find.byKey(Keys.status)).data ==
                  'Saved securely',
        );
        final file = (await app.vault.list()).single;
        expect((await app.vault.readAll(file)).take(3), [0xff, 0xd8, 0xff]);
        expect(
          await Directory.systemTemp
              .list(recursive: true)
              .where(
                (file) =>
                    file.path.endsWith('.jpg') || file.path.endsWith('.mp4'),
              )
              .length,
          0,
        );
      } else {
        expect(await app.vault.list(), isEmpty);
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      await app.close();
    }
  });
}
