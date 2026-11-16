import 'dart:io';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera/camera.dart' show CameraPreview;
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

/// A camera whose orientation lock works.
class _CastCamera extends ControlledCamera {
  _CastCamera(super.directory);
  final focus = <Point<double>?>[];
  final exposure = <Point<double>?>[];
  bool refuse = false;
  final modes = <Object>[];

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {
    modes.add(mode);
  }

  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async {
    modes.add(mode);
  }

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {
    focus.add(point);
    if (refuse) throw CameraException('focus', 'unsupported');
  }

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {
    exposure.add(point);
  }

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<void> unlockCaptureOrientation(int cameraId) async {}
}

typedef _Booted = ({
  _CastCamera camera,
  Session session,
  FakeCastBackend backend,
  Future<void> Function(bool Function()) until,
});

/// Opens the capture screen on [makeCamera] with a cast session available.
Future<_Booted> _boot(
  WidgetTester tester,
  ControlledCamera Function(Directory) makeCamera,
) async {
  FlutterSecureStorage.setMockInitialValues({});
  late Directory root;
  late Session session;
  late ControlledCamera camera;
  final backend = FakeCastBackend();
  final previous = CameraPlatform.instance;
  await tester.runAsync(() async {
    final sodium = await SodiumSumoInit.init();
    root = await Directory.systemTemp.createTemp('quietake-camera-cast-boot');
    final vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      root,
    );
    session = Session(
      vault: vault,
      server: await MediaServer.start(vault),
      cast: CastController(vault, backend),
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

  await until(() => find.byKey(Keys.preview).evaluate().isNotEmpty);
  return (
    camera: camera as _CastCamera,
    session: session,
    backend: backend,
    until: until,
  );
}

void main() {
  testWidgets('the grid button shows and hides thirds lines over the preview', (
    tester,
  ) async {
    await _boot(tester, _CastCamera.new);
    expect(find.byKey(Keys.cameraGridOverlay), findsNothing);
    expect(find.byTooltip('Show grid'), findsOneWidget);

    await tester.tap(find.byKey(Keys.cameraGrid));
    await tester.pump();
    expect(find.byKey(Keys.cameraGridOverlay), findsOneWidget);
    expect(find.byTooltip('Hide grid'), findsOneWidget);

    await tester.tap(find.byKey(Keys.cameraGrid));
    await tester.pump();
    expect(find.byKey(Keys.cameraGridOverlay), findsNothing);
  });

  testWidgets('tapping the preview focuses and meters there and shows a ring', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final booted = await _boot(tester, _CastCamera.new);
    // The top controls cover the upper part of the preview; tap below them.
    final preview = tester.getRect(find.byType(CameraPreview));
    final at = preview.center + Offset(0, preview.height / 4);
    await tester.tapAt(at);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(Keys.captureFocusRing), findsOneWidget);
    expect(booted.camera.focus.single!.x, closeTo(0.5, 0.01));
    expect(booted.camera.exposure.single!.y, closeTo(0.75, 0.01));

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(Keys.captureFocusRing), findsNothing);
  });

  testWidgets('a camera that refuses manual focus keeps working', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final booted = await _boot(tester, _CastCamera.new);
    booted.camera.refuse = true;
    final preview = tester.getRect(find.byType(CameraPreview));
    await tester.tapAt(preview.center + Offset(0, preview.height / 4));
    await tester.pump(const Duration(milliseconds: 900));
    expect(booted.camera.focus, hasLength(1));
    expect(tester.takeException(), isNull);
    expect(find.byKey(Keys.preview), findsOneWidget);
  });

  testWidgets('a long press locks focus and exposure until the next tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final booted = await _boot(tester, _CastCamera.new);
    final preview = tester.getRect(find.byType(CameraPreview));
    final at = preview.center + Offset(0, preview.height / 4);

    await tester.longPressAt(at);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(Keys.captureLock), findsOneWidget);
    expect(booted.camera.modes, [FocusMode.locked, ExposureMode.locked]);
    // The lock does not fade like a plain focus ring.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(Keys.captureLock), findsOneWidget);

    await tester.tapAt(at);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(Keys.captureLock), findsNothing);
    expect(booted.camera.modes.skip(2), [FocusMode.auto, ExposureMode.auto]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(Keys.captureFocusRing), findsNothing);
  });

  testWidgets('a camera that cannot lock explains and shows no lock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final booted = await _boot(tester, _CastCamera.new);
    booted.camera.refuse = true;
    final preview = tester.getRect(find.byType(CameraPreview));
    await tester.longPressAt(preview.center + Offset(0, preview.height / 4));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(Keys.captureLock), findsNothing);
    expect(
      find.text('Could not lock focus and exposure on this camera.'),
      findsOneWidget,
    );
  });
}
