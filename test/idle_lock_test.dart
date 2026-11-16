import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/capture_screen.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/main.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';
import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Session session;

  Future<void> open(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-idle');
      await File('${dir.path}/vault.keyfile.json').writeAsString('{}');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        Directory('${dir.path}/vault')..createSync(),
      );
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, dir),
      );
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (call) async => call.method == 'availableCameras' ? <Object?>[] : null,
    );
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/camera'),
        null,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await session.server.close();
        session.cast.dispose();
        session.vault.masterKeyForTests.dispose();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      QuietakeApp(
        store: session.store,
        auth: FakeAuthenticator(isAvailable: false),
        castBackend: session.cast.backend,
        session: session,
        idleTimeout: const Duration(milliseconds: 600),
      ),
    );
    // The keyfile check is real file IO; idle locking starts once it resolves.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(CaptureScreen).evaluate().isNotEmpty) break;
    }
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
  }

  testWidgets('an idle session locks after the timeout', (tester) async {
    await open(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('hardware key presses keep the session unlocked', (tester) async {
    await open(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    }
    expect(find.byType(LockScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('touches keep the session unlocked', (tester) async {
    await open(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      final touch = await tester.startGesture(const Offset(2, 2));
      await touch.up();
    }
    expect(find.byType(LockScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(LockScreen), findsOneWidget);
  });
}
