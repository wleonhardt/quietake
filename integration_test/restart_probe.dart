// Explicit host-orchestrated process-death probe; not automatically discovered.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/main.dart' as production;
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/sync/background_uploads.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment('RESTART_STAGE');
  testWidgets('process restart $stage preserves authenticated originals', (
    tester,
  ) async {
    final sodium = await SodiumSumoInit.init();
    final store = MasterKeyStore(
      sodium,
      await getApplicationDocumentsDirectory(),
    );
    if (stage == 'seed') {
      await BackgroundUploads().reset();
      await const SyncSettings(url: '', username: '', password: '').save();
      final dir = await Vault.defaultDir();
      for (final entry in await dir.list().toList()) {
        await entry.delete(recursive: true);
      }
      final key = await store.createWithPasscode('restart-fixture-only');
      final vault = Vault(VaultCrypto(sodium), key, dir);
      for (final name in ['tiny.jpg', 'tiny.mp4']) {
        final file = File('${(await getTemporaryDirectory()).path}/$name');
        await file.writeAsBytes(fixtureBytes(name));
        await vault.ingestAs(file, '2099-restart.$name');
      }
      // Finalized sources survive a killed process before encryption, during
      // normalization and after publication but before source cleanup.
      for (final capture in [
        (id: '2099-capture-before', extension: 'jpg', encrypted: false),
        (id: '2099-capture-converting', extension: 'mp4', encrypted: true),
        (id: '2099-restart.tiny', extension: 'mp4', encrypted: true),
      ]) {
        final work = await Directory('${dir.path}/.captures/${capture.id}')
            .create(recursive: true);
        final plain = await File(
          '${work.path}/capture.${capture.extension}',
        ).writeAsBytes(fixtureBytes('tiny.${capture.extension}'), flush: true);
        if (capture.encrypted) {
          await vault.encryptFile(plain, File('${plain.path}.shtr'));
        } else {
          await File('${plain.path}.shtr.part').writeAsBytes(VaultCrypto.magic);
        }
      }
      if (Platform.isAndroid) {
        await File('${(await getTemporaryDirectory()).path}/REC20991234.mp4')
            .writeAsBytes(fixtureBytes('tiny.mp4'), flush: true);
      }
      final removed = File('${dir.path}/2099-restart.tiny.jpg.shtr');
      final preserved = await removed.readAsBytes();
      await vault.delete(removed);
      // Simulate a crash between the durable decision and the final unlink.
      await removed.writeAsBytes(preserved);
      await File('${removed.path}.part').writeAsBytes(preserved);
      final album = await vault.catalog.createAlbum('Restart album');
      await vault.catalog.organize(
        {'2099-restart.tiny.mp4.shtr'},
        albumId: album,
        favorite: true,
      );
      await vault.catalog.renameItem(
        '2099-restart.tiny.mp4.shtr',
        'Restart video',
      );
      final abandoned = await dir.createTemp('.catalog-upload-');
      await vault.catalog.file.copy('${abandoned.path}/quietake.catalog');
      await store
          .clearCache(); // Normal launch must wait for explicit passcode.
      await vault.catalog.close();
      vault.dispose();
      await tester.pumpWidget(const SizedBox());
      return;
    }
    expect(stage, 'verify');
    await production.main();
    Future<void> until(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) fail('Restart unlock deadline');
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await until(() => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty);
    expect(find.byKey(Keys.openGallery), findsNothing);
    await tester.enterText(
      find.byKey(Keys.lockPasscode),
      'restart-fixture-only',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.lockUnlock));
    await until(
      () =>
          find.byKey(Keys.openGallery).evaluate().isNotEmpty &&
          tester.widget<IconButton>(find.byKey(Keys.openGallery)).onPressed !=
              null,
    );
    await tester.tap(find.byKey(Keys.openGallery));
    await until(() => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty);
    final dir = await Vault.defaultDir();
    expect(
      (await dir.list().toList()).whereType<Directory>().where(
        (entry) => entry.path.contains('.catalog-upload-'),
      ),
      isEmpty,
      reason:
          'Production library load must clear interrupted encrypted uploads',
    );
    final key = await store.unlockWithPasscode('restart-fixture-only');
    final vault = Vault(VaultCrypto(sodium), key, await Vault.defaultDir());
    try {
      await vault.catalog.load();
      expect(vault.catalog.albums.values, ['Restart album']);
      final details = vault.catalog.details('2099-restart.tiny.mp4.shtr');
      expect(details.title, 'Restart video');
      expect(details.favorite, isTrue);
      expect(details.albums, {vault.catalog.albums.keys.single});
      final files = await vault.list();
      expect(files.length, Platform.isAndroid ? 4 : 3);
      expect(
        files.map((f) => f.uri.pathSegments.last).toSet(),
        containsAll({
          '2099-restart.tiny.mp4.shtr',
          '2099-capture-before.jpg.shtr',
          '2099-capture-converting.mp4.shtr',
        }),
      );
      for (final file in files) {
        expect(
          await vault.readAll(file),
          fixtureBytes(
            file.path.endsWith('.jpg.shtr') ? 'tiny.jpg' : 'tiny.mp4',
          ),
        );
      }
      expect(
        await Directory('${dir.path}/.captures').list(recursive: true).length,
        0,
      );
      expect(
        await vault.deletedNames(),
        contains('2099-restart.tiny.jpg.shtr'),
      );
      expect(
        await File('${vault.dir.path}/2099-restart.tiny.jpg.shtr').exists(),
        isFalse,
      );
      expect(
        await File('${vault.dir.path}/2099-restart.tiny.jpg.shtr.part')
            .exists(),
        isFalse,
      );
      final temp = await getTemporaryDirectory();
      for (final name in ['quietake-share', 'share_plus']) {
        expect(await Directory('${temp.path}/$name').exists(), isFalse);
      }
    } finally {
      await vault.catalog.close();
      vault.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
