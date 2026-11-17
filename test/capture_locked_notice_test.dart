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
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/controlled_camera.dart';
import '../test_support/fake_cast_backend.dart';

class _Camera extends ControlledCamera {
  _Camera(super.directory) {
    empty = false;
  }

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<void> unlockCaptureOrientation(int cameraId) async {}
}

void main() {
  testWidgets('after unlock the camera screen says how many lock screen '
      'photos reached the library', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    late Directory root;
    late Session session;
    late ControlledCamera camera;
    final previous = CameraPlatform.instance;
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      root = await Directory.systemTemp.createTemp('quietake-locked-notice');
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
        lockedPublished: Future.value(2),
      );
      camera = _Camera(root);
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
      () => tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CaptureScreen(session: session),
        ),
      ),
    );
    for (
      var i = 0;
      i < 150 && find.byKey(Keys.lockedPublishedNotice).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(
      find.text(
        '2 photos from the lock screen camera are now in your library.',
      ),
      findsOneWidget,
    );
  });
}
