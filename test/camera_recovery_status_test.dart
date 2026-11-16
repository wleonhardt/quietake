import 'dart:io';

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

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory root;
  late Session session;

  int vaultCount() => root
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.shtr'))
      .length;

  Future<void> open(WidgetTester tester, {bool blockStorage = false}) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      root = await Directory.systemTemp.createTemp('quietake-camera-recovery');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        root,
      );
      // An interrupted photo left in private working storage.
      final work = await Directory('${root.path}/.captures/2099-interrupted')
          .create(recursive: true);
      await File('test_fixtures/tiny.jpg').copy('${work.path}/capture.jpg');
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, root),
      );
    });
    const channel = MethodChannel('plugins.flutter.io/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => <Object?>[],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await session.close();
        await root.delete(recursive: true);
      });
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: CaptureScreen(session: session)),
      );
    });
  }

  testWidgets('opening the camera recovers an interrupted photo', (
    tester,
  ) async {
    await open(tester);
    for (var i = 0; i < 150 && vaultCount() == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(vaultCount(), 1);
    // The recovery message is replaced by "No camera" once the open finishes.
    expect(find.byKey(Keys.status), findsOneWidget);
  });
}
