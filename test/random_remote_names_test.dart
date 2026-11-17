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

  test(
    'a lost mapping is rebuilt by matching ciphertext, not adopted as a copy',
    () async {
      final sync = SyncService(vault, dav, useRandomNames: true);
      await sync.sync();
      final remoteName = server.files.keys.firstWhere(
        (n) => n != 'quietake.catalog',
      );
      // An older app version saved the catalog without the mapping.
      server.files.remove('quietake.catalog');
      await vault.catalog.file.delete();
      final fresh = open('again', key);
      addTearDown(fresh.dispose);
      // Same captures on the phone, but its catalog never knew the mapping.
      await File('${vault.dir.path}/photo.jpg.shtr')
          .copy('${fresh.dir.path}/photo.jpg.shtr');
      final report = await SyncService(fresh, dav, useRandomNames: true).sync();
      expect(report.pulled, 0);
      expect(report.pushed, 0);
      expect(report.remoteTotal, 1);
      expect((await fresh.list()).length, 1);
      expect(fresh.catalog.remoteNames.remoteFor('photo.jpg.shtr'), remoteName);
      expect(server.files.keys.where((n) => n.endsWith('.shtr')), [remoteName]);
    },
  );

  test(
    'a randomly named file that matches no phone capture is still pulled',
    () async {
      await SyncService(vault, dav, useRandomNames: true).sync();
      final stray = '00112233445566778899aabbccddeeff.shtr';
      final other = open('other', key);
      addTearDown(other.dispose);
      final plain = await File('${root.path}/other.jpg')
          .writeAsBytes([255, 216, 255, 2, 3]);
      final file = await other.ingestAs(plain, 'other.jpg');
      server.files[stray] = await file.readAsBytes();
      final fresh = open('fresh2', key);
      addTearDown(fresh.dispose);
      await File('${vault.dir.path}/photo.jpg.shtr')
          .copy('${fresh.dir.path}/photo.jpg.shtr');
      server.files.remove('quietake.catalog');
      final report = await SyncService(fresh, dav, useRandomNames: true).sync();
      expect(report.pulled, 1);
      expect((await fresh.list()).length, 2);
    },
  );

  group('renaming files already on the NAS', () {
    test('a dry run counts candidates and changes nothing', () async {
      await SyncService(vault, dav).sync();
      final before = server.files.keys.toSet();
      final report = await SyncService(vault, dav).renameRemote(dryRun: true);
      expect(report.candidates, 1);
      expect(report.renamed, 0);
      expect(server.files.keys.toSet(), before);
    });

    test(
      'a rename moves the file, keeps the bytes and the next sync is quiet',
      () async {
        await SyncService(vault, dav).sync();
        final bytes = server.files['photo.jpg.shtr']!.toList();
        final report = await SyncService(vault, dav).renameRemote();
        expect(report.renamed, 1);
        expect(server.files.keys, isNot(contains('photo.jpg.shtr')));
        final media = server.files.keys.where((n) => n != 'quietake.catalog');
        expect(media.single, matches(hexName));
        expect(server.files[media.single]!.toList(), bytes);
        final quiet = await SyncService(vault, dav).sync();
        expect(quiet.pushed, 0);
        expect(quiet.pulled, 0);
        // A fresh phone restores the capture under its own name.
        final fresh = open('fresh', key);
        addTearDown(fresh.dispose);
        final restored = await SyncService(fresh, dav).sync();
        expect(restored.pulled, 1);
        expect((await fresh.list()).map((f) => f.uri.pathSegments.last), [
          'photo.jpg.shtr',
        ]);
      },
    );

    test('a second run has nothing left to rename', () async {
      await SyncService(vault, dav).sync();
      await SyncService(vault, dav).renameRemote();
      final again = await SyncService(vault, dav).renameRemote();
      expect(again.candidates, 0);
      expect(again.renamed, 0);
    });

    test(
      'a run interrupted after saving the mapping resumes with it',
      () async {
        await SyncService(vault, dav).sync();
        final saved = await vault.catalog.assignRemoteNames(['photo.jpg.shtr']);
        final report = await SyncService(vault, dav).renameRemote();
        expect(report.renamed, 1);
        expect(server.files.keys, contains(saved.remoteFor('photo.jpg.shtr')));
        expect(server.files.keys, isNot(contains('photo.jpg.shtr')));
      },
    );

    test('a capture missing on the phone is never renamed', () async {
      await SyncService(vault, dav).sync();
      final fresh = open('fresh', key);
      addTearDown(fresh.dispose);
      final report = await SyncService(fresh, dav).renameRemote();
      expect(report.renamed, 0);
      expect(server.files.keys, contains('photo.jpg.shtr'));
    });
  });
}
