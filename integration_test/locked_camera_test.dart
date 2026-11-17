import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/camera/locked_capture_store.dart';
import 'package:quietake/crypto/pending_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/pending_key_store.dart';

import '../test_support/fake_authenticator.dart';
import '../test_support/integration_binding.dart';
import '../test_support/test_vault.dart';

/// A photo taken from the lock screen is sealed without the vault key and
/// becomes an ordinary capture once published with the key.
void main() {
  initializeIntegrationBinding();

  testWidgets('a photo from the lock screen camera is sealed and published', (
    tester,
  ) async {
    final vault = await openTestVault();
    final sodium = vault.crypto.sodium;
    final docs = await getApplicationDocumentsDirectory();
    final keys = PendingKeyStore(sodium, docs);
    await keys.ensure(vault.masterKeyForTests);
    final locked = LockedCaptureStore(PendingCrypto(sodium), vault.dir);
    if (await locked.directory.exists()) {
      await locked.directory.delete(recursive: true);
    }
    final before = (await vault.list()).length;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LockScreen(
          store: MasterKeyStore(sodium, docs),
          auth: FakeAuthenticator(isAvailable: false),
          autoPrompt: false,
          onUnlocked: (_) {},
        ),
      ),
    );
    for (
      var i = 0;
      i < 20 && find.byKey(Keys.lockCamera).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(Keys.lockCamera), findsOneWidget);
    if ((await availableCameras()).isEmpty) {
      // A simulator without a camera: the screen must say so, not hang.
      await tester.tap(find.byKey(Keys.lockCamera));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(Keys.lockedStatus), findsOneWidget);
      return;
    }
    await tester.tap(find.byKey(Keys.lockCamera));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final shutter = find.byKey(Keys.lockedShutter);
      if (shutter.evaluate().isNotEmpty &&
          tester.widget<IconButton>(shutter).onPressed != null) {
        break;
      }
    }
    await tester.tap(find.byKey(Keys.lockedShutter));
    for (var i = 0; i < 100 && await locked.count() == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await locked.count(), 1);

    final secret = await keys.secretKey(vault.masterKeyForTests);
    final result = await locked.publishAll(
      vault,
      (await keys.publicKey())!,
      secret,
    );
    secret.dispose();
    expect(result.published, 1);
    expect(result.failed, 0);
    final after = await vault.list();
    expect(after.length, before + 1);
    final head = <int>[];
    await for (final chunk in vault.read(after.first)) {
      head.addAll(chunk);
      if (head.length >= 2) break;
    }
    expect(head.sublist(0, 2), [0xFF, 0xD8], reason: 'a JPEG after publishing');
  });
}
