import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

void main() {
  late Directory dir;
  late Vault vault;
  late FakeWebDavServer server;
  late WebDavClient dav;
  late SyncService sync;

  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    dir = await Directory.systemTemp.createTemp('quietake-sync');
    vault = Vault(
      crypto,
      crypto.generateMasterKey(),
      Directory('${dir.path}/vault')..createSync(),
    );
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
    await dir.delete(recursive: true);
  });

  Future<File> addLocal(String name, int size) async {
    final plain = File('${dir.path}/$name')..writeAsBytesSync(Uint8List(size));
    return vault.ingestAs(plain, name);
  }

  test(
    'empty vault sync establishes authenticated recovery ownership',
    () async {
      await sync.sync();
      expect(server.files.keys, contains('quietake.catalog'));
      await vault.catalog.validate(vault.catalog.file);
      expect(sync.authenticatedCatalogHash, isNotNull);
    },
  );

  test('first sync creates the collection and pushes everything', () async {
    await addLocal('a.jpg', 1000);
    await addLocal('b.mp4', 5000);
    final r = await sync.sync();
    expect(r.pushed, 2);
    expect(r.pulled, 0);
    expect(server.files.keys.toSet(), {
      'a.jpg.shtr',
      'b.mp4.shtr',
      'quietake.catalog',
    });
    expect(server.log.first, 'MKCOL /vault/');
    expect(sync.confirmedMedia, {'a.jpg.shtr', 'b.mp4.shtr'});
  });

  test(
    'foreground receipts exclude captures arriving after enumeration',
    () async {
      await addLocal('first.jpg', 1000);
      var added = false;
      server.beforeRequest = (request) async {
        if (!added && request.method == 'PUT') {
          added = true;
          await addLocal('late.jpg', 1000);
        }
      };
      await sync.sync();
      expect(sync.confirmedMedia, {'first.jpg.shtr'});
      expect(server.files.containsKey('late.jpg.shtr'), isFalse);
      expect(await vault.list(), hasLength(2));
    },
  );

  test('second sync is a no-op', () async {
    await addLocal('a.jpg', 1000);
    await sync.sync();
    final before = server.log.length;
    final r = await sync.sync();
    expect(r.pushed, 0);
    expect(r.pulled, 0);
    expect(
      server.log.sublist(before).where((l) => l.startsWith('PUT')),
      isEmpty,
    );
  });

  test('pulls what only the share has, bytes intact', () async {
    final local = await addLocal('a.jpg', 1000);
    await sync.sync();
    final bytes = local.readAsBytesSync();
    await local.delete();
    final r = await sync.sync();
    expect(r.pulled, 1);
    expect(File('${vault.dir.path}/a.jpg.shtr').readAsBytesSync(), bytes);
    expect(
      Directory(vault.dir.path)
          .listSync()
          .where((e) => e.path.endsWith('.part')),
      isEmpty,
    );
  });

  test(
    'different-size remote copy is preserved instead of silently repaired',
    () async {
      final local = await addLocal('a.jpg', 1000);
      await sync.sync();
      final original = await local.readAsBytes();
      final partial = server.files['a.jpg.shtr']!.sublist(0, 100);
      server.files['a.jpg.shtr'] = partial;
      server.log.clear();
      await expectLater(sync.sync(), throwsA(anything));
      expect(server.files['a.jpg.shtr'], partial);
      expect(await local.readAsBytes(), original);
      expect(
        server.log.where(
          (line) => line.startsWith('PUT ') || line.startsWith('DELETE '),
        ),
        isEmpty,
      );
    },
  );

  test('ignores foreign files on the share', () async {
    server.collectionExists = true;
    server.files['readme.txt'] = [1, 2, 3];
    final r = await sync.sync();
    expect(r.pulled, 0);
    expect(r.remoteTotal, 0);
  });

  test('never uploads partial downloads', () async {
    await File('${vault.dir.path}/clip.mp4.shtr.part').writeAsBytes([1]);
    await sync.sync();
    expect(server.files.keys.toSet(), {'quietake.catalog'});
  });

  test('literal percent escapes round trip without double decoding', () async {
    await addLocal('photo%20name.jpg', 10);
    await sync.sync();
    expect(
      (await dav.list()).where((e) => e.name.endsWith('.shtr')).single.name,
      'photo%20name.jpg.shtr',
    );
  });

  test('remote path separators are rejected before download', () async {
    server.collectionExists = true;
    server.files['../escape.shtr'] = [1, 2, 3];
    await expectLater(sync.sync(), throwsFormatException);
    expect(File('${dir.path}/escape.shtr').existsSync(), isFalse);
  });

  test('wrong password surfaces as WebDavException', () async {
    final bad = WebDavClient(
      base: server.url,
      username: 'vaultapp',
      password: 'nope',
    );
    await expectLater(
      SyncService(vault, bad).sync(),
      throwsA(isA<WebDavException>()),
    );
    bad.close();
  });

  test('names with odd characters round trip through URL encoding', () async {
    await addLocal('2026-10-17T13-09-35.687974Z.jpg', 10);
    await sync.sync();
    expect(
      (await dav.list()).where((e) => e.name.endsWith('.shtr')).single.name,
      '2026-10-17T13-09-35.687974Z.jpg.shtr',
    );
  });
}
