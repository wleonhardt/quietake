import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

void main() {
  late Directory root;
  late VaultCrypto crypto;
  late Vault vault;
  late FakeWebDavServer server;
  late WebDavClient dav;
  late File photo;
  final hexName = RegExp(r'^[0-9a-f]{32}\.shtr$');

  Vault open(String folder, Object key) => Vault(
    crypto,
    key as dynamic,
    Directory('${root.path}/$folder')..createSync(),
  );
  late dynamic key;

  setUp(() async {
    crypto = VaultCrypto(await SodiumSumoInit.init());
    key = crypto.generateMasterKey();
    root = await Directory.systemTemp.createTemp('quietake-random-names');
    vault = open('vault', key);
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

  test('by default the NAS still gets the capture name', () async {
    await SyncService(vault, dav).sync();
    expect(server.files.keys, contains('photo.jpg.shtr'));
  });

  test('a new upload gets a random name, and a second sync is quiet', () async {
    final sync = SyncService(vault, dav, useRandomNames: true);
    final first = await sync.sync();
    expect(first.pushed, 1);
    final media = server.files.keys.where((n) => n != 'quietake.catalog');
    expect(media.single, matches(hexName));
    final second = await sync.sync();
    expect(second.pushed, 0);
    expect(second.pulled, 0);
    expect(second.remoteTotal, 1);
    expect(server.files.keys.length, 2);
  });

  test('a fresh phone pulls the capture back under its own name', () async {
    await SyncService(vault, dav, useRandomNames: true).sync();
    final fresh = open('fresh', key);
    addTearDown(fresh.dispose);
    final report = await SyncService(fresh, dav, useRandomNames: true).sync();
    expect(report.pulled, 1);
    expect(report.pushed, 0);
    expect((await fresh.list()).map((f) => f.uri.pathSegments.last), [
      'photo.jpg.shtr',
    ]);
    expect(
      fresh.catalog.remoteNames.remoteFor('photo.jpg.shtr'),
      matches(hexName),
    );
  });

  test('a confirmed deletion removes the randomly named NAS copy', () async {
    final sync = SyncService(vault, dav, useRandomNames: true);
    await sync.sync();
    final directory = await Directory('${vault.dir.path}/.deletions').create();
    await File('${directory.path}/photo.jpg.del').writeAsBytes([], flush: true);
    await photo.delete();
    final report = await sync.sync();
    expect(report.deleted, 1);
    expect(server.files.keys, ['quietake.catalog']);
  });

  test('check backup authenticates randomly named copies', () async {
    final sync = SyncService(vault, dav, useRandomNames: true);
    await sync.sync();
    final report = await sync.verify();
    expect(report.media, 1);
    expect(report.catalog, isTrue);
  });
}
