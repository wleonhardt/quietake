import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/pending_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/controlled_camera.dart';
import '../test_support/fake_authenticator.dart';

void main() {
  late SodiumSumo sodium;
  setUpAll(() async => sodium = await SodiumSumoInit.init());

  Future<({Directory dir, ControlledCamera camera, CameraPlatform previous})>
  boot(WidgetTester tester, {required bool pair}) async {
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('locked-camera');
      if (pair) {
        await PendingKeyStore(
          sodium,
          dir,
        ).ensure(sodium.crypto.secretBox.keygen());
      }
    });
    final camera = ControlledCamera(dir)..empty = false;
    final previous = CameraPlatform.instance;
    CameraPlatform.instance = camera;
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LockScreen(
            store: MasterKeyStore(sodium, dir),
            auth: FakeAuthenticator(isAvailable: false),
            autoPrompt: false,
            vaultDir: () async => dir,
            onUnlocked: (_) {},
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    return (dir: dir, camera: camera, previous: previous);
  }

  testWidgets('a vault without a key pair offers no locked camera', (
    tester,
  ) async {
    final b = await boot(tester, pair: false);
    addTearDown(() => CameraPlatform.instance = b.previous);
    expect(find.byKey(Keys.lockCamera), findsNothing);
  });

  testWidgets('the lock screen camera seals a photo without the vault key', (
    tester,
  ) async {
    final b = await boot(tester, pair: true);
    addTearDown(() => CameraPlatform.instance = b.previous);
    expect(find.byKey(Keys.lockCamera), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.lockCamera));
      await tester.pump();
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.lockedShutter));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    expect(find.byKey(Keys.lockedStatus), findsOneWidget);
    final pending = Directory('${b.dir.path}/.pending');
    final sealed = pending.listSync().whereType<File>().toList();
    expect(sealed, hasLength(1));
    expect(sealed.single.path, endsWith('.jpg.pending'));
    expect(
      b.camera.outputs.every((f) => !f.existsSync()),
      isTrue,
      reason: 'the plaintext photo must not stay behind',
    );
    // The locked camera shows no library, settings or unlock controls.
    expect(find.byKey(Keys.lockUnlock).hitTestable(), findsNothing);
  });

  testWidgets('a failed seal says so and leaves no plaintext photo behind', (
    tester,
  ) async {
    final b = await boot(tester, pair: true);
    addTearDown(() => CameraPlatform.instance = b.previous);
    // A file where the pending folder belongs makes sealing fail.
    await tester.runAsync(
      () async => File('${b.dir.path}/.pending').writeAsString('x'),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.lockCamera));
      await tester.pump();
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.lockedShutter));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    final context = tester.element(find.byKey(Keys.lockedStatus));
    expect(
      tester.widget<Text>(find.byKey(Keys.lockedStatus)).data,
      context.l10n.lockedCameraFailed,
    );
    expect(b.camera.outputs, isNotEmpty);
    expect(
      b.camera.outputs.every((f) => !f.existsSync()),
      isTrue,
      reason: 'a photo that could not be sealed must not linger as plaintext',
    );
  });
}
