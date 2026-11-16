import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/main.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';
import '../test_support/fake_cast_backend.dart';

void main() {
  late SodiumSumo sodium;
  setUpAll(() async => sodium = await SodiumSumoInit.init());
  for (final firstRun in [false, true]) {
    testWidgets(
      'a vault that cannot open keeps the lock screen with a reason; firstRun=$firstRun',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        late Directory dir;
        late File blocker;
        await tester.runAsync(() async {
          dir = await Directory.systemTemp.createTemp('quietake-start-fail');
          if (!firstRun) {
            await File('${dir.path}/vault.keyfile.json').writeAsString('{}');
          }
          // The documents path is a file, so the vault directory cannot be made.
          blocker = await File('${dir.path}/not-a-directory')
              .writeAsString('x');
        });
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => blocker.path,
        );
        addTearDown(() async {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(() => dir.delete(recursive: true));
        });
        await tester.pumpWidget(
          QuietakeApp(
            store: MasterKeyStore(sodium, dir),
            auth: FakeAuthenticator(isAvailable: false),
            castBackend: FakeCastBackend(),
          ),
        );
        final first = firstRun
            ? find.byType(SetupScreen)
            : find.byType(LockScreen);
        for (var i = 0; i < 50 && first.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        final key = sodium.crypto.secretBox.keygen();
        if (firstRun) {
          // Setup commits the keyfile before it hands the key to the app.
          await tester.runAsync(
            () => File('${dir.path}/vault.keyfile.json').writeAsString('{}'),
          );
          tester.widget<SetupScreen>(first).onUnlocked(key);
        } else {
          tester.widget<LockScreen>(first).onUnlocked(key);
        }
        for (
          var i = 0;
          i < 100 &&
              find
                  .text('Could not open the vault. Try again.')
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.byType(LockScreen), findsOneWidget);
        expect(
          find.text('Could not open the vault. Try again.'),
          findsOneWidget,
        );
      },
    );
  }
}
