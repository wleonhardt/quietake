// Explicit host-controlled native process-death check. Synthetic data only.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/background_uploads.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment('BACKGROUND_STAGE');
  const port = int.fromEnvironment('BACKGROUND_PORT');
  if (!Platform.isAndroid ||
      !['seed', 'verify', 'nudge'].contains(stage) ||
      port < 1024) {
    throw StateError(
      'Use guarded tool/background_check.py on a development AVD',
    );
  }
  testWidgets('native background process $stage', (tester) async {
    final sodium = await SodiumSumoInit.init();
    final store = MasterKeyStore(
      sodium,
      await getApplicationDocumentsDirectory(),
    );
    final background = BackgroundUploads();
    if (stage == 'nudge') {
      await background.request();
      debugPrint('BACKGROUND_NUDGE_REQUESTED');
      await tester.pumpWidget(const SizedBox());
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (await background.status() != 'transferred') {
        if (DateTime.now().isAfter(deadline)) {
          fail('Unchanged native pass deadline');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      return;
    }
    final dir = await Vault.defaultDir();
    if (stage == 'seed') {
      await background.reset();
      for (final entry in await dir.list().toList()) {
        await entry.delete(recursive: true);
      }
    }
    final key = stage == 'seed'
        ? await store.createWithPasscode('background-fixture-only')
        : await store.unlockWithPasscode('background-fixture-only');
    final vault = Vault(VaultCrypto(sodium), key, dir);
    final sync = SyncController(vault);
    try {
      if (stage == 'seed') {
        final first = await File(
          '${(await getTemporaryDirectory()).path}/background.jpg',
        ).writeAsBytes(fixtureBytes('tiny.jpg'));
        await vault.ingestAs(first, 'background-first.jpg');
        await SyncSettings(
          url: 'http://127.0.0.1:$port/vault/',
          username: 'fixture',
          password: 'synthetic-background',
          backgroundUploads: true,
        ).save();
        await sync.sync();
        expect(
          await background.status(),
          anyOf('scheduled', 'uploading', 'transferred'),
        );
        // Keep foreground work leased until process death. The host controls the
        // receiver and kills the ordinary background process, never force-stop.
        await BackgroundUploads.channel.invokeMethod<String>('begin');
        final second = await File(
          '${(await getTemporaryDirectory()).path}/background.mp4',
        ).writeAsBytes(fixtureBytes('tiny.mp4'));
        await vault.ingestAs(second, 'background-second.mp4');
        await vault.catalog.renameItem(
          'background-second.mp4.shtr',
          'Background video',
        );
        expect(await vault.list(), hasLength(2));
        await store.clearCache();
      } else {
        expect(await background.status(), 'transferred');
        for (final suffix in ['first.jpg', 'second.mp4']) {
          final file = File('${dir.path}/background-$suffix.shtr');
          expect(
            await vault.readAll(file),
            fixtureBytes(suffix.endsWith('jpg') ? 'tiny.jpg' : 'tiny.mp4'),
          );
        }
        await vault.catalog.load();
        expect(
          vault.catalog.details('background-second.mp4.shtr').title,
          'Background video',
        );
        await sync.disconnect();
        expect(await background.status(), 'disabled');
      }
      await tester.pumpWidget(const SizedBox());
    } finally {
      await sync.close();
      await vault.catalog.close();
      vault.dispose();
    }
  });
}
