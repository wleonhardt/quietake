import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

void main() {
  test('new Dart envelope recovers through independent masked Go CLI, folder and WebDAV', () async {
    final root = await Directory.systemTemp.createTemp(
      'quietake-backup-interop-',
    );
    final sodium = await SodiumSumoInit.init();
    final key = SecureKey.fromList(
      sodium,
      Uint8List.fromList(List.generate(32, (i) => i)),
    );
    final server = await FakeWebDavServer.start();
    try {
      final containers = await Directory('${root.path}/containers').create();
      final box = await MasterKeyStore(
        sodium,
        root,
      ).wrapBackupKey(key, 'synthetic river violet paper lantern canyon');
      await File('${containers.path}/${MasterKeyStore.recoveryBoxName}')
          .writeAsString(box);
      final cases = {
        'photo.bin.shtr': <int>[1, 2, 3],
        'quietake.catalog': utf8.encode(
          '{"version":1,"albums":{},"items":{}}',
        ),
      };
      for (final item in cases.entries) {
        final sink = File('${containers.path}/${item.key}').openWrite();
        try {
          await sink.addStream(
            VaultCrypto(sodium).encrypt(Stream.value(item.value), key),
          );
        } finally {
          await sink.close();
        }
      }
      final binary = '${root.path}/recover-fixture';
      final build = await Process.run('go', [
        'build',
        '-o',
        binary,
        '.',
      ], workingDirectory: 'recover');
      expect(build.exitCode, 0, reason: '${build.stderr}');
      server.collectionExists = true;
      await for (final file in containers.list()) {
        server.files[file.uri.pathSegments.last] = await (file as File)
            .readAsBytes();
      }
      for (final mode in [
        <String>[],
        [server.url.toString()],
        ['wrong'],
      ]) {
        final run = await Process.run('python3', [
          'tool/backup_prompt_check.py',
          binary,
          root.path,
          ...mode,
        ]);
        expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
        final folder = mode.isEmpty
            ? 'local'
            : mode.first == 'wrong'
            ? 'wrong'
            : 'remote';
        if (folder == 'wrong') {
          expect(await Directory('${root.path}/wrong').exists(), isFalse);
          continue;
        }
        expect(await File('${root.path}/$folder/photo.bin').readAsBytes(), [
          1,
          2,
          3,
        ]);
        expect(
          await File('${root.path}/$folder/quietake.catalog.json')
              .readAsBytes(),
          cases['quietake.catalog'],
        );
      }
      // Exact UTF-8, including accents and a non-BMP scalar, must agree across
      // Dart, the masked terminal and the independent Argon2id implementation.
      await File('${containers.path}/${MasterKeyStore.recoveryBoxName}')
          .writeAsString(
            await MasterKeyStore(sodium, root).wrapBackupKey(
              key,
              'synthetic café violet 🦉 paper lantern canyon',
            ),
          );
      final unicode = await Process.run('python3', [
        'tool/backup_prompt_check.py',
        binary,
        root.path,
        'unicode',
      ]);
      expect(
        unicode.exitCode,
        0,
        reason: '${unicode.stdout}\n${unicode.stderr}',
      );
      expect(await File('${root.path}/unicode/photo.bin').readAsBytes(), [
        1,
        2,
        3,
      ]);
      final conflict = await Process.run(binary, [
        '-backup-passphrase-prompt',
        '-key-prompt',
        '-check',
        '-dir',
        containers.path,
      ]);
      expect(conflict.exitCode, 2);
    } finally {
      await server.close();
      key.dispose();
      await root.delete(recursive: true);
    }
  });
}
