import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/portable_backup.dart';
import 'package:quietake/backup/restore_transaction.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/nas_recovery.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';
import '../test_support/legacy_backup.dart';

// Deliberately constructs the old published contracts, independent of new writers.
void main() {
  late Directory root;
  late MasterKeyStore store;
  late Vault source;
  late Map<String, dynamic> fixture;
  late List<int> catalog;
  late List<int> media;
  late FakeWebDavServer server;
  late WebDavClient dav;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('quietake-migration-');
    final sodium = await SodiumSumoInit.init();
    store = MasterKeyStore(sodium, root);
    fixture = jsonDecode(
      await File('docs/recovery-vectors/v1.json').readAsString(),
    ) as Map<String, dynamic>;
    final key = store.importRecovery(fixture['public_key'] as String);
    source = Vault(
      VaultCrypto(sodium),
      key,
      await Directory('${root.path}/source').create(),
    );
    final mediaFile = await source.ingestAs(
      await File('${root.path}/input').writeAsBytes([1, 2, 3, 4]),
      'photo.jpg',
    );
    media = await mediaFile.readAsBytes();
    final file = File('${root.path}/legacy.catalog');
    await source.writeMetadata(
      file,
      utf8.encode(
        jsonEncode({
          'version': 1,
          'albums': {'subject': 'Coast', 'action': 'In motion'},
          'items': {
            'photo.jpg.shtr': {
              'title': 'Old capture',
              'favorite': true,
              'albums': ['subject', 'action'],
            },
          },
        }),
      ),
    );
    catalog = await file.readAsBytes();
    server = await FakeWebDavServer.start();
    server.collectionExists = true;
    server.files.addAll({
      'tucklight.catalog': catalog,
      'photo.jpg.shtr': media,
      'tucklight.recovery.json': utf8.encode(jsonEncode(fixture['box'])),
    });
    dav = WebDavClient(
      base: server.url,
      username: server.username,
      password: server.password,
    );
  });
  tearDown(() async {
    dav.close();
    await server.close();
    await source.catalog.close();
    source.dispose();
    await root.delete(recursive: true);
  });

  Future<File> legacyArchive() => writeLegacyArchive(
    source,
    source.masterKeyForTests,
    File('${root.path}/legacy.zip'),
    catalog,
    {'photo.jpg.shtr': media},
  );

  Future<void> checkRestored(Directory directory) async {
    final key = store.importRecovery(fixture['public_key'] as String);
    final restored = Vault(source.crypto, key, directory);
    try {
      expect(
        await File('${directory.path}/quietake.catalog').readAsBytes(),
        catalog,
      );
      expect(
        await File('${directory.path}/tucklight.catalog').exists(),
        isFalse,
      );
      await restored.catalog.load();
      expect(restored.catalog.albums, {
        'subject': 'Coast',
        'action': 'In motion',
      });
      expect(restored.catalog.details('photo.jpg.shtr').albums, {
        'subject',
        'action',
      });
      final file = (await restored.list()).single;
      expect(await file.readAsBytes(), media);
      expect(await restored.readAll(file), [1, 2, 3, 4]);
    } finally {
      await restored.catalog.close();
      restored.dispose();
    }
  }

  test(
    'legacy portable restore preserves tags and ciphertext across interruption',
    () async {
      final archive = await legacyArchive();
      final before = await archive.readAsBytes();
      final backup = PortableBackup(source, source.masterKeyForTests);
      await expectLater(
        backup.stage(archive, root, isCancelled: () => true),
        throwsStateError,
      );
      final stage = await backup.stage(archive, root);
      await checkRestored(stage);
      final transaction = RestoreTransaction(store);
      await expectLater(
        transaction.commit(
          stage,
          source.masterKeyForTests,
          'new-pin',
          onProgress: (phase) {
            if (phase == 'Saving restored vault') {
              throw StateError('simulated process death');
            }
          },
        ),
        throwsStateError,
      );
      expect(await transaction.resume(), isTrue);
      await checkRestored(transaction.target);
      final unlocked = await store.unlockWithPasscode('new-pin');
      expect(source.matchesKey(unlocked), isTrue);
      unlocked.dispose();
      expect(await archive.readAsBytes(), before);
      expect(await (await source.list()).single.readAsBytes(), media);
    },
  );

  test(
    'legacy NAS restore is read-only and normalizes local metadata',
    () async {
      final before = Map<String, List<int>>.of(server.files);
      await NasRecovery(
        store,
        dav,
      ).restore(fixture['passphrase'] as String, 'new-pin');
      await checkRestored(Directory('${root.path}/vault'));
      expect(server.files, before);
      expect(
        server.log.every(
          (s) => s.startsWith('GET ') || s.startsWith('PROPFIND '),
        ),
        isTrue,
      );
    },
  );

  for (final mixed in [false, true]) {
    test(
      'sync refuses ${mixed ? 'mixed' : 'legacy'} backup without writes or deletion replay',
      () async {
        if (mixed) server.files['quietake.catalog'] = catalog;
        await source.delete((await source.list()).single);
        final before = Map<String, List<int>>.of(server.files);
        await expectLater(
          SyncService(source, dav).sync(),
          throwsFormatException,
        );
        expect(server.files, before);
        expect(await source.deletedNames(), contains('photo.jpg.shtr'));
        expect(
          server.log.any(
            (s) =>
                s.startsWith('PUT ') ||
                s.startsWith('DELETE ') ||
                s.startsWith('MOVE '),
          ),
          isFalse,
        );
      },
    );
  }

  test(
    'recovery management refuses a legacy collection without modifying it',
    () async {
      final key = await store.restoreFromRecovery(
        fixture['public_key'] as String,
        'local-pin',
      );
      key.dispose();
      final before = Map<String, List<int>>.of(server.files);
      await expectLater(
        NasRecovery(
          store,
          dav,
        ).change(source, 'local-pin', fixture['passphrase'] as String),
        throwsFormatException,
      );
      expect(server.files, before);
      expect(
        server.log.any(
          (s) =>
              s.startsWith('PUT ') ||
              s.startsWith('DELETE ') ||
              s.startsWith('MOVE '),
        ),
        isFalse,
      );
    },
  );

  test('mixed recovery identities reject before adoption', () async {
    server.files['quietake.catalog'] = catalog;
    server.files['quietake.recovery.json'] =
        server.files['tucklight.recovery.json']!;
    await expectLater(
      NasRecovery(
        store,
        dav,
      ).restore(fixture['passphrase'] as String, 'new-pin'),
      throwsFormatException,
    );
    expect(await store.hasKeyfile, isFalse);
    expect(await Directory('${root.path}/vault').exists(), isFalse);
  });

  test(
    'new recovery writer selects v2 purpose and new storage identifiers',
    () async {
      final box = jsonDecode(
        await store.wrapBackupKey(
          source.masterKeyForTests,
          fixture['passphrase'] as String,
        ),
      );
      expect(box['v'], 2);
      expect(box['purpose'], 'quietake.nas-recovery');
      expect(
        () => MasterKeyStore.validateBackupBox(
          utf8.encode(jsonEncode({...box, 'v': 1})),
        ),
        throwsFormatException,
      );
      expect(MasterKeyStore.recoveryBoxName, 'quietake.recovery.json');
      expect(MasterKeyStore.cacheName, 'quietake.master_key');
    },
  );
}
