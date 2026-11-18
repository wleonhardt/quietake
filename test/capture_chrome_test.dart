import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

/// Reports no camera until [present] is set, like a phone whose camera is busy.
class _LateCamera extends ControlledCamera {
  _LateCamera(super.directory);
  bool present = false;
  @override
  Future<List<CameraDescription>> availableCameras() async =>
      present ? super.availableCameras() : const [];
}

/// A camera with a zoom range, recording what the screen asks for.
class _ZoomCamera extends ControlledCamera {
  _ZoomCamera(super.directory);
  final zooms = <double>[];
  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;
  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;
  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async => zooms.add(zoom);
}

/// A camera with a flash, recording the modes the screen sets.
class _FlashCamera extends ControlledCamera {
  _FlashCamera(super.directory);
  final modes = <FlashMode>[];
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async =>
      modes.add(mode);
}

typedef _Booted = ({
  ControlledCamera camera,
  Future<void> Function(bool Function()) until,
});

Future<_Booted> _boot(
  WidgetTester tester,
  ControlledCamera Function(Directory) makeCamera, {
  bool waitForPreview = true,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  late Directory root;
  late Session session;
  late ControlledCamera camera;
  final previous = CameraPlatform.instance;
  await tester.runAsync(() async {
    final sodium = await SodiumSumoInit.init();
    root = await Directory.systemTemp.createTemp('quietake-camera-chrome');
    final vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      root,
    );
    session = Session(
      vault: vault,
      server: await MediaServer.start(vault),
      cast: CastController(vault, FakeCastBackend()),
      store: MasterKeyStore(sodium, root),
    );
    camera = makeCamera(root);
  });
  CameraPlatform.instance = camera;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 100 && camera.disposed.length < camera.created; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    CameraPlatform.instance = previous;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await session.close();
      await root.delete(recursive: true);
    });
  });
  await tester.runAsync(
    () => tester.pumpWidget(MaterialApp(home: CaptureScreen(session: session))),
  );
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  if (waitForPreview) {
    await until(() => find.byKey(Keys.preview).evaluate().isNotEmpty);
  }
  return (camera: camera, until: until);
}

void main() {
  testWidgets('the status bar icons are light on the dark camera', (
    tester,
  ) async {
    await _boot(tester, ControlledCamera.new);
    await tester.pump();
    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.light,
    );
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
  });

  testWidgets('the saved notice goes away on its own', (tester) async {
    final booted = await _boot(tester, (d) => ControlledCamera(d)..empty = false);
    await tester.tap(find.byKey(Keys.shutter));
    await booted.until(() => find.text('Saved securely').evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Saved securely'), findsNothing);
    expect(find.byKey(Keys.status), findsNothing);
  });

  testWidgets('pinching the preview zooms within the camera range', (
    tester,
  ) async {
    final booted = await _boot(tester, _ZoomCamera.new);
    final camera = booted.camera as _ZoomCamera;
    expect(find.byKey(Keys.captureZoom), findsNothing);
    final center = tester.getCenter(find.byKey(Keys.preview));
    final a = await tester.startGesture(center - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(center + const Offset(20, 0), pointer: 2);
    await a.moveBy(const Offset(-40, 0));
    await b.moveBy(const Offset(40, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();
    expect(camera.zooms, isNotEmpty);
    // The exact factor depends on when the gesture is recognised.
    expect(camera.zooms.last, greaterThan(1.2));
    expect(camera.zooms.every((z) => z >= 1 && z <= 8), isTrue);
    expect(find.byKey(Keys.captureZoom), findsOneWidget);

    // The label is also the way back to no zoom.
    await tester.tap(find.byKey(Keys.captureZoom));
    await tester.pump();
    expect(camera.zooms.last, 1);
    expect(find.byKey(Keys.captureZoom), findsNothing);
  });

  testWidgets('a camera without zoom ignores the pinch', (tester) async {
    await _boot(tester, ControlledCamera.new);
    final center = tester.getCenter(find.byKey(Keys.preview));
    final a = await tester.startGesture(center - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(center + const Offset(20, 0), pointer: 2);
    await a.moveBy(const Offset(-40, 0));
    await b.moveBy(const Offset(40, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();
    expect(find.byKey(Keys.captureZoom), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the flash starts off and cycles automatic, on, off', (
    tester,
  ) async {
    final booted = await _boot(tester, _FlashCamera.new);
    final camera = booted.camera as _FlashCamera;
    expect(camera.modes, [FlashMode.off]);
    for (final expected in [FlashMode.auto, FlashMode.always, FlashMode.off]) {
      await tester.tap(find.byKey(Keys.cameraFlashMode));
      await booted.until(() => camera.modes.last == expected);
    }
    expect(camera.modes, [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.always,
      FlashMode.off,
    ]);
    expect(find.byTooltip('Flash off'), findsOneWidget);
  });

  testWidgets('a camera without a flash says so and stays off', (tester) async {
    final booted = await _boot(tester, ControlledCamera.new);
    await tester.tap(find.byKey(Keys.cameraFlashMode));
    await booted.until(
      () => find.text('This camera has no flash.').evaluate().isNotEmpty,
    );
    expect(find.byTooltip('Flash off'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('while recording, Stop takes the centre and the shutter steps aside', (
    tester,
  ) async {
    final booted = await _boot(tester, ControlledCamera.new);
    const cameraChannel = MethodChannel('quietake/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cameraChannel,
      (_) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        cameraChannel,
        null,
      ),
    );
    final middle = tester.getCenter(find.byType(CaptureScreen)).dx;
    double x(Key key) => tester.getCenter(find.byKey(key)).dx;
    expect(x(Keys.shutter), closeTo(middle, 1));
    expect(x(Keys.videoToggle), lessThan(middle - 40));
    // A drawn shutter, not the radio button glyph.
    expect(
      find.descendant(
        of: find.byKey(Keys.shutter),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(Keys.videoToggle));
    await booted.until(
      () => find.byKey(Keys.captureTimer).evaluate().isNotEmpty,
    );
    expect(x(Keys.videoToggle), closeTo(middle, 1));
    expect(x(Keys.shutter), lessThan(middle - 40));
    expect(
      tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(Keys.videoToggle));
    await booted.until(() => x(Keys.shutter) > middle - 1);
    // Let the photo camera come back, so the screen can shut down cleanly.
    await booted.until(
      () =>
          booted.camera.opened.length == 3 &&
          find.byKey(Keys.preview).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('a missing camera offers Retry, which opens it', (tester) async {
    final booted = await _boot(
      tester,
      _LateCamera.new,
      waitForPreview: false,
    );
    await booted.until(() => find.text('No camera').evaluate().isNotEmpty);
    expect(find.byKey(Keys.preview), findsNothing);
    (booted.camera as _LateCamera).present = true;
    await tester.tap(find.byKey(Keys.captureRetry));
    await booted.until(() => find.byKey(Keys.preview).evaluate().isNotEmpty);
    expect(find.text('No camera'), findsNothing);
    expect(find.byKey(Keys.captureRetry), findsNothing);
  });
}
