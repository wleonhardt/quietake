import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

class _FailedDelete extends WebDavClient {
  _FailedDelete(Uri url)
    : super(base: url, username: 'vaultapp', password: 'secret');
  @override
  Future<void> delete(String name, {String? lease}) async =>
      throw WebDavException('DELETE', 503, name);
}

void main() {
  late Directory root;
  late Vault vault;
  late FakeWebDavServer server;
  late WebDavClient dav;
  late File photo;

  setUp(() async {
    final crypto = VaultCrypto(await SodiumSumoInit.init());
    root = await Directory.systemTemp.createTemp('quietake-delete');
    vault = Vault(
      crypto,
      crypto.generateMasterKey(),
      await Directory('${root.path}/vault').create(),
    );
    final plain = await File('${root.path}/photo.jpg')
        .writeAsBytes([255, 216, 255, 1]);
    photo = await vault.ingestAs(plain, 'photo.jpg');
    server = await FakeWebDavServer.start();
    dav = WebDavClient(
      base: server.url,
      username: 'vaultapp',
      password: 'secret',
    );
  });
  tearDown(() async {
    dav.close();
    await server.close();
    vault.dispose();
    await root.delete(recursive: true);
  });

  // An already-confirmed deletion journal, including a crash before unlink.
  Future<void> journal({bool unlink = true}) async {
    final directory = await Directory('${vault.dir.path}/.deletions').create();
    await File('${directory.path}/photo.jpg.del').writeAsBytes([], flush: true);
    if (unlink && await photo.exists()) await photo.delete();
  }

  test(
    'confirmed deletion removes phone and NAS copies without resurrection',
    () async {
      final sync = SyncService(vault, dav);
      await sync.sync();
      await journal();
      await sync.sync();
      expect(await photo.exists(), isFalse);
      expect(await vault.list(), isEmpty);
      expect(server.files.keys, ['quietake.catalog']);
      // An old restored backup must not undo this device's deletion decision.
      server.files['photo.jpg.shtr'] = [1, 2, 3];
      await sync.sync();
      expect(await vault.list(), isEmpty);
      expect(server.files.keys, ['quietake.catalog']);
    },
  );

  test('unfinished local unlink is replayed before an offline sync', () async {
    await journal(unlink: false);
    final offline = WebDavClient(
      base: server.url,
      username: 'vaultapp',
      password: 'wrong',
    );
    try {
      await expectLater(
        SyncService(vault, offline).sync(),
        throwsA(isA<WebDavException>()),
      );
      expect(await photo.exists(), isFalse);
    } finally {
      offline.close();
    }
  });

  test(
    'failed NAS deletion stays journaled and retries after reopening vault',
    () async {
      await SyncService(vault, dav).sync();
      await journal();
      final failed = _FailedDelete(server.url);
      try {
        await expectLater(
          SyncService(vault, failed).sync(),
          throwsA(isA<WebDavException>()),
        );
      } finally {
        failed.close();
      }
      expect(await photo.exists(), isFalse);
      expect(server.files, contains('photo.jpg.shtr'));
      final reopened = Vault(
        vault.crypto,
        vault.masterKeyForTests.copy(),
        vault.dir,
      );
      try {
        await SyncService(reopened, dav).sync();
        expect(await reopened.list(), isEmpty);
        expect(server.files.keys, ['quietake.catalog']);
      } finally {
        reopened.dispose();
      }
    },
  );

  for (final method in ['PUT', 'GET']) {
    test('deletion wins over an in-flight $method', () async {
      if (method == 'GET') {
        await SyncService(vault, dav).sync();
        await photo.delete();
      }
      final started = Completer<void>();
      final release = Completer<void>();
      server.beforeRequest = (request) async {
        if (request.method == method && !started.isCompleted) {
          started.complete();
          await release.future;
        }
      };
      final running = SyncService(vault, dav).sync();
      await started.future;
      await journal();
      release.complete();
      await running;
      expect(await photo.exists(), isFalse);
      expect(server.files.keys, ['quietake.catalog']);
    });
  }

  test('remote deletion-like files never authorize local deletion', () async {
    await SyncService(vault, dav).sync();
    server.files['photo.jpg.del'] = [];
    await SyncService(vault, dav).sync();
    expect(await vault.readAll(photo), [255, 216, 255, 1]);
    expect(server.files, contains('photo.jpg.shtr'));
    expect(server.log.where((entry) => entry.startsWith('DELETE')), isEmpty);
  });
}
