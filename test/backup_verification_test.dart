import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

class _CancelReadVault extends Vault {
  _CancelReadVault(Vault original, this.onRead)
    : super(original.crypto, original.masterKeyForTests.copy(), original.dir);
  final void Function() onRead;
  @override
  Stream<List<int>> read(File file) async* {
    await for (final bytes in super.read(file)) {
      if (file.path.endsWith('.jpg.shtr')) onRead();
      yield bytes;
    }
  }
}

void main() {
  late Directory root;
  late Vault vault;
  late FakeWebDavServer server;
  late WebDavClient client;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup-confidence-test');
    final sodium = await SodiumSumoInit.init();
    vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      await Directory('${root.path}/vault').create(),
    );
    server = await FakeWebDavServer.start();
    server.collectionExists = true;
    client = WebDavClient(
      base: server.url,
      username: server.username,
      password: server.password,
    );
  });
  tearDown(() async {
    client.close();
    await server.close();
    await vault.catalog.close();
    vault.dispose();
    await root.delete(recursive: true);
  });

  Future<File> local(String name) async {
    final source = await File('${root.path}/input').writeAsBytes([1, 2, 3]);
    return vault.ingestAs(source, name);
  }

  test(
    'damaged remote-only media is rejected before becoming visible',
    () async {
      final file = await local('damaged.jpg');
      final bytes = await file.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await file.delete();
      server.files['damaged.jpg.shtr'] = bytes;
      await expectLater(SyncService(vault, client).sync(), throwsA(anything));
      expect(await vault.list(), isEmpty);
      expect(server.files['damaged.jpg.shtr'], bytes);
      expect(await vault.dir.list().toList(), isEmpty);
    },
  );

  test(
    'wrong-key collection rejects before uploading local originals',
    () async {
      final own = await local('own.jpg');
      final ownBytes = await own.readAsBytes();
      final foreign = Vault(
        vault.crypto,
        vault.crypto.generateMasterKey(),
        await Directory('${root.path}/foreign').create(),
      );
      try {
        final source = await File('${root.path}/foreign-input')
            .writeAsBytes([4, 5, 6]);
        final container = await foreign.ingestAs(source, 'other.jpg');
        final bytes = await container.readAsBytes();
        server.files['other.jpg.shtr'] = bytes;
        await expectLater(SyncService(vault, client).sync(), throwsA(anything));
        expect((await vault.list()).map((f) => f.path), [own.path]);
        expect(await own.readAsBytes(), ownBytes);
        expect(server.files, {'other.jpg.shtr': bytes});
        expect(
          server.log.where(
            (line) => line.startsWith('PUT ') || line.startsWith('DELETE '),
          ),
          isEmpty,
        );
      } finally {
        foreign.dispose();
      }
    },
  );

  test(
    'local catalog never authorizes overwriting an invalid remote catalog',
    () async {
      final own = await local('own.jpg');
      await vault.catalog.renameItem(own.uri.pathSegments.last, 'My capture');
      final localCatalog = await vault.catalog.file.readAsBytes();
      server.files[PrivateCatalog.fileName] = [0, 1, 2];
      await expectLater(SyncService(vault, client).sync(), throwsA(anything));
      expect(server.files, {
        PrivateCatalog.fileName: [0, 1, 2],
      });
      expect(await vault.catalog.file.readAsBytes(), localCatalog);
      expect(
        server.log.where(
          (line) => line.startsWith('PUT ') || line.startsWith('DELETE '),
        ),
        isEmpty,
      );
    },
  );
  test('full verification checks remote bytes and catalog without changing originals', () async {
    final file = await local('one.jpg');
    await SyncService(vault, client).sync();
    final original = await file.readAsBytes();
    final remote = {
      for (final entry in server.files.entries) entry.key: [...entry.value],
    };
    server.log.clear();
    final started = DateTime.now();
    final report = await SyncService(vault, client).verify();
    expect(report.media, 1);
    expect(report.catalog, isTrue);
    expect(report.checkedAt.isBefore(started), isFalse);
    expect(
      server.log.every(
        (line) => line.startsWith('PROPFIND ') || line.startsWith('GET '),
      ),
      isTrue,
    );
    expect(server.files, remote);
    expect(await file.readAsBytes(), original);
    expect((await vault.dir.list().toList()).whereType<Directory>(), isEmpty);
  });

  test('same-size corruption is detected by full verification, never repaired implicitly', () async {
    final file = await local('one.jpg');
    final service = SyncService(vault, client);
    await service.sync();
    final original = await file.readAsBytes();
    final broken = [...server.files['one.jpg.shtr']!];
    broken[broken.length - 1] ^= 1;
    server.files['one.jpg.shtr'] = broken;
    await service
        .sync(); // Presence alone must not become a verification claim.
    server.log.clear();
    await expectLater(service.verify(), throwsA(anything));
    expect(server.files['one.jpg.shtr'], broken);
    expect(await file.readAsBytes(), original);
    expect(
      server.log.every(
        (line) => line.startsWith('PROPFIND ') || line.startsWith('GET '),
      ),
      isTrue,
    );
    expect((await vault.dir.list().toList()).whereType<Directory>(), isEmpty);
  });

  test('verification reports missing uploads and pending deletions without mutating NAS', () async {
    final file = await local('one.jpg');
    final service = SyncService(vault, client);
    await expectLater(service.verify(), throwsA(isA<BackupCheckException>()));
    expect(server.files, isEmpty);
    await service.sync();
    await vault.delete(file);
    final remote = {
      for (final entry in server.files.entries) entry.key: [...entry.value],
    };
    server.log.clear();
    await expectLater(service.verify(), throwsA(isA<BackupCheckException>()));
    expect(server.files, remote);
    expect(
      server.log.where(
        (line) => line.startsWith('PUT ') || line.startsWith('DELETE '),
      ),
      isEmpty,
    );
  });

  test(
    'valid same-key conflicting copy is preserved before uploads or deletions',
    () async {
      final file = await local('one.jpg');
      final service = SyncService(vault, client);
      await service.sync();
      final original = await file.readAsBytes();
      final source = await File('${root.path}/other')
          .writeAsBytes([4, 5, 6, 7]);
      final other = await vault.ingestAs(source, 'other.jpg');
      final conflicting = await other.readAsBytes();
      await other.delete();
      server.files['one.jpg.shtr'] = conflicting;
      server.log.clear();
      await expectLater(
        service.sync(),
        throwsA(isA<BackupConflictException>()),
      );
      expect(server.files['one.jpg.shtr'], conflicting);
      expect(await file.readAsBytes(), original);
      expect(
        server.log.where(
          (line) => line.startsWith('PUT ') || line.startsWith('DELETE '),
        ),
        isEmpty,
      );
    },
  );

  test(
    'metadata-only backup is fully verified without inventing media counts',
    () async {
      await vault.catalog.createAlbum('Empty album');
      final service = SyncService(vault, client);
      await service.sync();
      server.log.clear();
      final report = await service.verify();
      expect(report.media, 0);
      expect(report.catalog, isTrue);
      expect(server.files.keys, [PrivateCatalog.fileName]);
      expect(
        server.log.every(
          (line) => line.startsWith('PROPFIND ') || line.startsWith('GET '),
        ),
        isTrue,
      );
    },
  );

  test(
    'next backup check cleans only owned interrupted encrypted staging',
    () async {
      await local('one.jpg');
      final service = SyncService(vault, client);
      await service.sync();
      final orphan = await Directory('${vault.dir.path}/.backup-work-orphan')
          .create();
      await File('${orphan.path}/incomplete.part').writeAsBytes([1]);
      final unrelated = await Directory('${vault.dir.path}/unrelated').create();
      final original = await File('${unrelated.path}/keep').writeAsBytes([8]);
      await service.verify();
      expect(await orphan.exists(), isFalse);
      expect(await original.readAsBytes(), [8]);
    },
  );

  test(
    'bounded download rejects actual body and preserves existing destination',
    () async {
      server.files['oversized.bin'] = List.filled(1001, 0);
      final target = await File('${root.path}/existing').writeAsBytes([9]);
      await expectLater(
        client.get('oversized.bin', target, maxBytes: 1000),
        throwsFormatException,
      );
      expect(await target.readAsBytes(), [9]);
      expect(await File('${target.path}.part').exists(), isFalse);
      expect(server.files['oversized.bin'], hasLength(1001));
    },
  );

  test('wrong-key source never replays local deletion journal against foreign folder', () async {
    final file = await local('own.jpg');
    await vault.delete(file);
    server.files[PrivateCatalog.fileName] = [0, 1, 2];
    server.files['own.jpg.shtr'] = [4, 5, 6];
    final original = {
      for (final entry in server.files.entries) entry.key: [...entry.value],
    };
    await expectLater(SyncService(vault, client).sync(), throwsA(anything));
    expect(server.files, original);
    expect(
      server.log.where(
        (line) => line.startsWith('PUT ') || line.startsWith('DELETE '),
      ),
      isEmpty,
    );
    expect(await vault.deletedNames(), {'own.jpg.shtr'});
  });
  test(
    'cancel during local authentication cannot report a completed check',
    () async {
      final file = await local('one.jpg');
      final original = await file.readAsBytes();
      await SyncService(vault, client).sync();
      late SyncController checking;
      final probe = _CancelReadVault(
        vault,
        () => checking.cancelVerification(),
      );
      checking = SyncController(
        probe,
        loadSettings: () async => SyncSettings(
          url: server.url.toString(),
          username: server.username,
          password: server.password,
        ),
      );
      try {
        await checking.verify();
        expect(checking.state, SyncState.pending);
        expect(checking.verificationResult, contains('cancelled'));
        expect(checking.verificationCurrent, isFalse);
        expect(checking.lastVerification, isNull);
        expect(await file.readAsBytes(), original);
        expect(
          (await vault.dir.list().toList()).whereType<Directory>(),
          isEmpty,
        );
      } finally {
        await checking.close();
        await probe.catalog.close();
        probe.dispose();
      }
    },
  );
}
