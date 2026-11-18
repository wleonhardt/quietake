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
