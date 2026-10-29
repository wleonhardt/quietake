import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/nas_recovery.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

const phrase = 'synthetic river violet paper lantern canyon';
const nextPhrase = 'another meadow silver lantern river canopy';
void main() {
  late Directory dir;
  late MasterKeyStore store;
  late Vault vault;
  late FakeWebDavServer server;
  late WebDavClient dav;
  late NasRecovery recovery;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final sodium = await SodiumSumoInit.init();
    dir = await Directory.systemTemp.createTemp('nas-recovery-');
    store = MasterKeyStore(sodium, dir);
    final key = await store.createWithPasscode('local-pin');
    vault = Vault(
      VaultCrypto(sodium),
      key,
      await Directory('${dir.path}/vault').create(),
    );
    server = await FakeWebDavServer.start();
    dav = WebDavClient(
      base: server.url,
      username: server.username,
      password: server.password,
    );
    recovery = NasRecovery(store, dav);
    await SyncService(vault, dav).sync();
  });
  tearDown(() async {
    dav.close();
    await server.close();
    vault.dispose();
    await dir.delete(recursive: true);
  });
  Future<MasterKeyStore> fresh() async {
    FlutterSecureStorage.setMockInitialValues({});
    return MasterKeyStore(
      store.sodium,
      await Directory('${dir.path}/fresh').create(),
    );
  }

  for (final mode in ['unsupported', 'shallow', 'infinite']) {
    test('recovery fails closed for $mode collection lease', () async {
      final original = Map<String, List<int>>.of(server.files);
      server.lockSupported = mode != 'unsupported';
      server.lockDepth = mode == 'shallow' ? '0' : 'infinity';
      server.lockTimeout = mode == 'infinite' ? 'Infinite' : 'Second-300';
      await expectLater(
        recovery.change(vault, 'local-pin', phrase),
        throwsA(anything),
      );
      expect(server.files, original);
      expect(
        server.log
            .where(
              (v) =>
                  v.startsWith('PUT ') ||
                  v.startsWith('MOVE ') ||
                  v.startsWith('DELETE '),
            )
            .toList(),
        [
          startsWith('PUT /vault/.quietake-upload-'),
          startsWith('MOVE /vault/.quietake-upload-'),
        ],
        reason: 'only the setUp sync wrote, through a staged upload',
      );
      expect(server.lease, isNull);
    });
  }
  test(
    'collection lease prevents a second client from replacing ownership',
    () async {
      final other = WebDavClient(
        base: server.url,
        username: server.username,
        password: server.password,
      );
      final incoming = await File('${dir.path}/foreign').writeAsBytes([0]);
      var denied = false;
      server.beforeRequest = (request) async {
        if (request.method == 'GET' &&
            request.uri.path.endsWith('quietake.catalog')) {
          try {
            await other.put('quietake.catalog', incoming);
          } on WebDavException catch (e) {
            denied = e.status == 423;
          }
        }
      };
      try {
        await recovery.change(vault, 'local-pin', phrase);
        expect(denied, isTrue);
        expect(server.lease, isNull);
      } finally {
        other.close();
      }
    },
  );
  test(
    'expired lease cannot finalize and owned cleanup retries later',
    () async {
      await recovery.change(vault, 'local-pin', phrase);
      final original = List<int>.of(
        server.files[MasterKeyStore.recoveryBoxName]!,
      );
      server.beforeRequest = (request) async {
        if (request.method == 'MOVE') server.lease = null;
      };
      await expectLater(
        recovery.change(vault, 'local-pin', nextPhrase),
        throwsA(isA<WebDavException>()),
      );
      expect(server.files[MasterKeyStore.recoveryBoxName], original);
      expect(
        server.files.keys.where(
          (name) => name.startsWith('.quietake-recovery-'),
        ),
        hasLength(1),
      );
      await recovery.change(vault, 'local-pin', null);
      expect(
        server.files.keys.where(
          (name) => name.startsWith('.quietake-recovery-'),
        ),
        isEmpty,
      );
      expect(server.files.containsKey(MasterKeyStore.recoveryBoxName), isFalse);
    },
  );

  test('a failed recovery read still releases the collection lease', () async {
    server.respond = (request) async {
      if (request.method == 'GET' &&
          request.uri.path.endsWith('quietake.catalog')) {
        request.response.statusCode = 503;
        await request.drain<void>();
        await request.response.close();
        return true;
      }
      return false;
    };
    await expectLater(
      recovery.change(vault, 'local-pin', phrase),
      throwsA(isA<WebDavException>()),
    );
    expect(
      server.log.where((line) => line.startsWith('UNLOCK ')),
      hasLength(1),
    );
    expect(server.lease, isNull);
  });

  for (final status in [200, 500]) {
    test(
      'restore aborts untrusted streaming media before disk exhaustion HTTP $status',
      () async {
        final plain = await File('${dir.path}/plain').writeAsBytes([1, 2, 3]);
        await vault.ingestAs(plain, 'photo.jpg');
        await SyncService(vault, dav).sync();
        await recovery.change(vault, 'local-pin', phrase);
        var sent = 0;
        final finished = Completer<void>();
        server.respond = (request) async {
          if (request.method != 'GET' ||
              !request.uri.path.endsWith('photo.jpg.shtr')) {
            return false;
          }
          request.response.statusCode = status;
          try {
            for (var i = 0; i < 256; i++) {
              request.response.add(List<int>.filled(16384, 0));
              await request.response.flush().timeout(
                const Duration(seconds: 1),
              );
              sent += 16384;
              await Future<void>.delayed(const Duration(milliseconds: 2));
            }
          } catch (_) {
            // A rejected stream must close its connection before consuming junk.
          } finally {
            try {
              await request.response.close().timeout(
                const Duration(seconds: 1),
              );
            } catch (_) {}
            finished.complete();
          }
          return true;
        };
        final target = await fresh();
        await expectLater(
          NasRecovery(target, dav).restore(phrase, 'new-pin'),
          throwsA(anything),
        );
        expect(
          sent,
          lessThan(1024 * 1024),
          reason: 'Must reject before buffering all unauthenticated junk',
        );
        await finished.future.timeout(const Duration(seconds: 5));
        expect(await target.hasKeyfile, isFalse);
        expect(await target.dir.list().toList(), isEmpty);
      },
    );
  }

  test('enable, replace and disable preserve media and never get recreated by sync', () async {
    final plain = await File('${dir.path}/plain').writeAsBytes([1, 2, 3]);
    final capture = await vault.ingestAs(plain, 'photo.jpg');
    await SyncService(vault, dav).sync();
    final bytes = await capture.readAsBytes();
    final keyfile = await store.keyfile.readAsBytes();
    await recovery.change(vault, 'local-pin', phrase);
    final old = List<int>.of(server.files[MasterKeyStore.recoveryBoxName]!);
    expect(utf8.decode(old), isNot(contains(phrase)));
    await recovery.change(vault, 'local-pin', nextPhrase);
    final current = server.files[MasterKeyStore.recoveryBoxName]!;
    await expectLater(
      store.openBackupKey(current, phrase),
      throwsFormatException,
    );
    final opened = await store.openBackupKey(current, nextPhrase);
    try {
      expect(vault.matchesKey(opened), isTrue);
    } finally {
      opened.dispose();
    }
    await vault.delete(capture); // The confirmed removal is still pending, and key disable must leave media alone.
    await recovery.change(vault, 'local-pin', null);
    expect(server.files['photo.jpg.shtr'], bytes);
    expect(server.files.containsKey(MasterKeyStore.recoveryBoxName), isFalse);
    expect(await store.keyfile.readAsBytes(), keyfile);
    await SyncService(vault, dav).sync();
    expect(server.files.containsKey(MasterKeyStore.recoveryBoxName), isFalse);
  });
  test(
    'failed or concurrent replacement preserves the previous envelope',
    () async {
      await recovery.change(vault, 'local-pin', phrase);
      final old = List<int>.of(server.files[MasterKeyStore.recoveryBoxName]!);
      server.failMoves = true;
      await expectLater(
        recovery.change(vault, 'local-pin', nextPhrase),
        throwsA(isA<WebDavException>()),
      );
      expect(server.files[MasterKeyStore.recoveryBoxName], old);
      server.failMoves = false;
      var changed = false;
      final concurrent = [...old, 32];
      server.beforeRequest = (request) async {
        if (request.method == 'MOVE' && !changed) {
          changed = true;
          server.files[MasterKeyStore.recoveryBoxName] = concurrent;
        }
      };
      await expectLater(
        recovery.change(vault, 'local-pin', nextPhrase),
        throwsA(isA<WebDavException>()),
      );
      expect(server.files[MasterKeyStore.recoveryBoxName], concurrent);
      expect(
        server.files.keys.any((n) => n.startsWith('.quietake-recovery-')),
        isFalse,
      );
    },
  );
  test('interrupted owned staging is retried without deleting unknown remote copies', () async {
    await recovery.change(vault, 'local-pin', phrase);
    final unknown = '.quietake-recovery-${'A' * 24}';
    server.files[unknown] = List<int>.of(
      server.files[MasterKeyStore.recoveryBoxName]!,
    );
    server.failMoves = true;
    server.failDeletes = true;
    await expectLater(
      recovery.change(vault, 'local-pin', nextPhrase),
      throwsA(isA<WebDavException>()),
    );
    expect(
      server.files.keys.where((n) => n.startsWith('.quietake-recovery-')),
      hasLength(2),
    );
    server.failMoves = false;
    server.failDeletes = false;
    await recovery.change(vault, 'local-pin', null);
    expect(
      server.files.keys.where((n) => n.startsWith('.quietake-recovery-')),
      [unknown],
    );
  });

  test('wrong passcode, weak phrase, unknown schema and foreign catalog make no remote changes', () async {
    await expectLater(
      recovery.change(vault, 'wrong', phrase),
      throwsA(isA<WrongPasscodeException>()),
    );
    await expectLater(
      recovery.change(vault, 'local-pin', '1234'),
      throwsFormatException,
    );
    final old = Map<String, List<int>>.of(server.files);
    server.weakEtags = true;
    await expectLater(
      recovery.change(vault, 'local-pin', phrase),
      throwsFormatException,
    );
    expect(server.files, old);
    server.weakEtags = false;
    server.files[MasterKeyStore.recoveryBoxName] = utf8.encode('{"v":2}');
    await expectLater(
      recovery.change(vault, 'local-pin', phrase),
      throwsFormatException,
    );
    expect(
      server.files[MasterKeyStore.recoveryBoxName],
      utf8.encode('{"v":2}'),
    );
    server.files.remove(MasterKeyStore.recoveryBoxName);
    server.files['quietake.catalog'] = [1, 2, 3];
    await expectLater(
      recovery.change(vault, 'local-pin', phrase),
      throwsA(anything),
    );
    expect(server.files.keys.toSet(), old.keys.toSet());
    expect(server.files['quietake.catalog'], [1, 2, 3]);
  });
  for (final hasMedia in [false, true]) {
    test(
      'fresh read-only NAS restore authenticates ${hasMedia ? 'media and catalog' : 'metadata-only vault'}',
      () async {
        if (hasMedia) {
          final plain = await File('${dir.path}/plain').writeAsBytes([1, 2, 3]);
          await vault.ingestAs(plain, 'photo.jpg');
          await SyncService(vault, dav).sync();
        }
        await recovery.change(vault, 'local-pin', phrase);
        final original = Map<String, List<int>>.fromEntries(
          server.files.entries.map(
            (e) => MapEntry(e.key, List<int>.of(e.value)),
          ),
        );
        final target = await fresh();
        final operation = NasRecovery(target, dav);
        await expectLater(
          operation.restore(nextPhrase, 'new-pin'),
          throwsFormatException,
        );
        expect(await target.hasKeyfile, isFalse);
        server.log.clear();
        await operation.restore(phrase, 'new-pin');
        expect(server.files, original);
        expect(
          server.log.every(
            (v) => v.startsWith('GET ') || v.startsWith('PROPFIND '),
          ),
          isTrue,
        );
        expect(await target.hasCachedKey, isFalse);
        final key = await target.unlockWithPasscode('new-pin');
        final restored = Vault(
          VaultCrypto(store.sodium),
          key,
          Directory('${target.dir.path}/vault'),
        );
        try {
          expect(restored.matchesKey(vault.masterKeyForTests), isTrue);
          final files = await restored.list();
          expect(files, hasLength(hasMedia ? 1 : 0));
          if (hasMedia) expect(await restored.readAll(files.single), [1, 2, 3]);
        } finally {
          restored.dispose();
        }
        await expectLater(
          operation.restore(phrase, 'other-pin'),
          throwsFormatException,
        );
      },
    );
  }
  test(
    'corruption and cancellation preserve fresh destination and every source',
    () async {
      final plain = await File('${dir.path}/plain').writeAsBytes([1, 2, 3]);
      await vault.ingestAs(plain, 'photo.jpg');
      await SyncService(vault, dav).sync();
      await recovery.change(vault, 'local-pin', phrase);
      final target = await fresh();
      final bad = server.files['photo.jpg.shtr']!.toList();
      bad[bad.length - 1] ^= 1;
      server.files['photo.jpg.shtr'] = bad;
      await expectLater(
        NasRecovery(target, dav).restore(phrase, 'new-pin'),
        throwsA(anything),
      );
      expect(await target.hasKeyfile, isFalse);
      expect(server.files['photo.jpg.shtr'], bad);
      await expectLater(
        NasRecovery(
          target,
          dav,
          isCancelled: () => true,
        ).restore(phrase, 'new-pin'),
        throwsStateError,
      );
      expect(await target.dir.list().toList(), isEmpty);
    },
  );
}
