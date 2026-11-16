import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/capture_screen.dart';
import 'package:quietake/cast/cast_backend.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  testWidgets('the camera follows a cast session into landscape and back', (
    tester,
  ) async {
    if (await tester.runAsync(MediaServer.lanAddress) == null) return;
    FlutterSecureStorage.setMockInitialValues({});
    late Directory root;
    late Session session;
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      root = await Directory.systemTemp.createTemp('quietake-camera-cast');
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
    });
    final orientations = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (call) async => <Object?>[],
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments);
      }
      return null;
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/camera'),
        null,
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await session.close();
        await root.delete(recursive: true);
      });
    });
    await tester.runAsync(
      () =>
          tester.pumpWidget(MaterialApp(home: CaptureScreen(session: session))),
    );

    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 150 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await tester.runAsync(
      () =>
          session.cast.start(const CastDevice('tv-1', 'Living Room TV'), null),
    );
    await until(
      () => orientations.any(
        (o) => o is List && o.contains('DeviceOrientation.landscapeLeft'),
      ),
    );
    expect(orientations.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    final before = orientations.length;
    await tester.runAsync(() => session.cast.stop());
    await until(() => orientations.length > before);
    expect(orientations.last, isEmpty);
  });
}
