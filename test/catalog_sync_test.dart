import 'dart:async';
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

void main() {
  late Vault vault;
  late Directory dir;
  late FakeWebDavServer server;
  late WebDavClient dav;
  late SyncService sync;
  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    dir = await Directory.systemTemp.createTemp('catalog-sync-');
    vault = Vault(crypto, crypto.generateMasterKey(), dir);
    server = await FakeWebDavServer.start();
    dav = WebDavClient(
      base: server.url,
      username: 'vaultapp',
      password: 'secret',
    );
    sync = SyncService(vault, dav);
  });
  tearDown(() async {
    dav.close();
    await server.close();
    await vault.catalog.close();
    vault.dispose();
    await dir.delete(recursive: true);
  });
  test(
    'an interrupted upload leaves no final object and the next pass finishes',
    () async {
      final bytes = List<int>.filled(200000, 7);
      await vault.ingestAs(
        File('${dir.path}/a.jpg')..writeAsBytesSync(bytes),
        'a.jpg',
      );
      var aborted = false;
      server.respond = (request) async {
        final name = Uri.decodeComponent(request.uri.pathSegments.last);
        if (request.method != 'PUT' || aborted || name.endsWith('.catalog')) {
          return false;
        }
        aborted = true;
        // The NAS keeps what arrived before the transfer failed.
        final partial = <int>[];
        await for (final chunk in request) {
          if (partial.length < 4096) partial.addAll(chunk);
        }
        server.files[name] = partial;
        request.response.statusCode = 500;
        await request.response.close();
        return true;
      };
      await expectLater(sync.sync(), throwsA(anything));
      expect(server.files.containsKey('a.jpg.shtr'), isFalse);
      final report = await sync.sync();
      expect(report.pushed, 1);
      expect(server.files['a.jpg.shtr']!.length, greaterThan(bytes.length));
      expect(
        server.files.keys.where((n) => n.startsWith('.quietake-upload-')),
        isEmpty,
      );
    },
  );

  test('a catalog changed on the NAS during sync is not replaced', () async {
    final id = await vault.catalog.createAlbum('First');
    await sync.sync();
    final theirs = [...server.files[PrivateCatalog.fileName]!, 0];
    server.beforeRequest = (request) async {
      if ((request.method == 'MOVE' || request.method == 'PUT') &&
          request.headers.value('Destination')?.endsWith('.catalog') == true) {
        server.files[PrivateCatalog.fileName] = theirs;
      }
      if (request.method == 'PUT' && request.uri.path.endsWith('.catalog')) {
        server.files[PrivateCatalog.fileName] = theirs;
      }
    };
    await vault.catalog.renameAlbum(id, 'Other');
    await expectLater(sync.sync(), throwsA(isA<BackupConflictException>()));
    expect(server.files[PrivateCatalog.fileName], theirs);
  });

  test(
    'backs up same-length edits and restores metadata without media counts',
    () async {
      final id = await vault.catalog.createAlbum('First');
      await vault.catalog.organize(
        {'one.jpg.shtr'},
        favorite: true,
        albumId: id,
      );
      expect((await sync.sync()).remoteTotal, 0);
      final first = [...server.files[PrivateCatalog.fileName]!];
      await vault.catalog.renameAlbum(id, 'Other');
      expect((await sync.sync()).remoteTotal, 0);
      final second = server.files[PrivateCatalog.fileName]!;
      expect(second.length, first.length);
      expect(second, isNot(first));
      await vault.catalog.file.delete();
      await vault.catalog.load();
      await sync.sync();
      expect(vault.catalog.albums[id], 'Other');
      expect(vault.catalog.details('one.jpg.shtr').favorite, isTrue);
      expect(await vault.list(), isEmpty);
      expect(server.log.where((e) => e.startsWith('GET')), [
        'GET /vault/quietake.catalog',
        'GET /vault/quietake.catalog',
      ]);
    },
  );
  test(
    'local edit during restore wins; remote references never delete captures',
    () async {
      await vault.catalog.createAlbum('Remote');
      await sync.sync();
      await vault.catalog.file.delete();
      await vault.catalog.load();
      final capture = await File('${dir.path}/one.jpg.shtr')
          .writeAsBytes([1, 2]);
      final started = Completer<void>();
      final release = Completer<void>();
      server.beforeRequest = (request) async {
        if (request.method == 'GET' &&
            request.uri.path.endsWith(PrivateCatalog.fileName)) {
          started.complete();
          await release.future;
        }
      };
      final transfer = sync.sync();
      await started.future;
      final id = await vault.catalog.createAlbum('Local');
      release.complete();
      await transfer;
      expect(vault.catalog.albums, {id: 'Local'});
      expect(await capture.exists(), isTrue);
      expect(await vault.deletedNames(), isEmpty);
    },
  );
  test(
    'merged tags retain schema-one identities through encrypted backup restore',
    () async {
      final subject = await vault.catalog.createAlbum('Alex');
      final source = await vault.catalog.createAlbum('Running');
      final target = await vault.catalog.createAlbum('Run');
      await vault.catalog.organize(
        {'one.jpg.shtr', 'pending.mp4.shtr'},
        tagIds: {subject, source},
      );
      await vault.catalog.mergeTags(source, target);
      await sync.sync();
      await vault.catalog.file.delete();
      await vault.catalog.load();
      await sync.sync();
      expect(vault.catalog.albums, {subject: 'Alex', target: 'Run'});
      expect(vault.catalog.details('one.jpg.shtr').albums, {subject, target});
      expect(vault.catalog.details('pending.mp4.shtr').albums, {
        subject,
        target,
      });
      expect(await vault.list(), isEmpty);
      expect(await vault.deletedNames(), isEmpty);
    },
  );
  test(
    'in-flight snapshot is immutable and next sync backs up newer edits',
    () async {
      final id = await vault.catalog.createAlbum('Before');
      final started = Completer<void>();
      final release = Completer<void>();
      server.beforeRequest = (request) async {
        // The catalog publishes through a staged MOVE (decision 039).
        if (request.method == 'MOVE' &&
            request.headers
                    .value('Destination')
                    ?.endsWith(PrivateCatalog.fileName) ==
                true) {
          started.complete();
          await release.future;
        }
      };
      final transfer = sync.sync();
      await started.future;
      await vault.catalog.renameAlbum(id, 'After');
      release.complete();
      await transfer;
      final old = [...server.files[PrivateCatalog.fileName]!];
      server.beforeRequest = null;
      await sync.sync();
      expect(server.files[PrivateCatalog.fileName], isNot(old));
      expect(
        dir.listSync().whereType<Directory>(),
        isEmpty,
        reason: 'Snapshots cleaned after transfer',
      );
    },
  );
  for (final corrupt in [false, true]) {
    test(
      'confirmed deletion cleans metadata or preserves damaged bytes ($corrupt)',
      () async {
        final capture = await File('${dir.path}/one.jpg.shtr')
            .writeAsBytes([1]);
        final id = await vault.catalog.createAlbum('Keep album');
        await vault.catalog.organize(
          {'one.jpg.shtr', 'other.jpg.shtr'},
          favorite: true,
          albumId: id,
        );
        if (corrupt) {
          await vault.catalog.file.writeAsBytes([1, 2, 3]);
          await expectLater(vault.catalog.load(), throwsA(anything));
        }
        final controller = SyncController(
          vault,
          loadSettings: () async =>
              const SyncSettings(url: '', username: '', password: ''),
        );
        try {
          await controller.delete(capture);
          expect(await capture.exists(), isFalse);
          expect(await vault.deletedNames(), {'one.jpg.shtr'});
          if (corrupt) {
            expect(await vault.catalog.file.readAsBytes(), [1, 2, 3]);
          } else {
            expect(vault.catalog.items.containsKey('one.jpg.shtr'), isFalse);
            expect(vault.catalog.details('other.jpg.shtr').favorite, isTrue);
            expect(vault.catalog.albums[id], 'Keep album');
          }
        } finally {
          await controller.close();
        }
      },
    );
  }

  test(
    'invalid remote catalog fails without adopting bytes or deleting media',
    () async {
      server.files[PrivateCatalog.fileName] = [1, 2];
      server.collectionExists = true;
      final file = await File('${dir.path}/one.jpg.shtr').writeAsBytes([1]);
      await expectLater(sync.sync(), throwsA(anything));
      expect(await vault.catalog.file.exists(), isFalse);
      expect(
        await File('${vault.catalog.file.path}.incoming').exists(),
        isFalse,
      );
      expect(await file.exists(), isTrue);
      expect(await vault.deletedNames(), isEmpty);
    },
  );
}
