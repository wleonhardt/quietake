import 'dart:io';
import 'dart:math';

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

/// A camera whose orientation lock works.
class _CastCamera extends ControlledCamera {
  _CastCamera(super.directory) {
    empty = false;
  }
  final focus = <Point<double>?>[];
  final exposure = <Point<double>?>[];
  bool refuse = false;

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
  FlutterSecureStorage.setMockInitialValues({'camera.burstSize': '3'});
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
  testWidgets('a saved burst size of three takes three photos', (tester) async {
    final booted = await _boot(tester, _CastCamera.new);
    await tester.longPress(find.byKey(Keys.shutter));
    await booted.until(
      () => find.text('Saved 3 photos securely').evaluate().isNotEmpty,
    );
    await tester.runAsync(() async {
      expect((await booted.session.vault.list()).length, 3);
    });
    await tester.pump(const Duration(milliseconds: 300));
  });
}
