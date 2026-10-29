import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import 'package:quietake/crypto/vault_crypto.dart';

/// Temporary synthetic data only. Never rewrites the frozen format vectors.
Future<void> main() async {
  final sodium = await SodiumSumoInit.init();
  final crypto = VaultCrypto(sodium);
  // Public test bytes, not a user recovery key.
  final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
  final key = SecureKey.fromList(sodium, publicKey);
  final root = await Directory.systemTemp.createTemp('quietake-interop-');
  try {
    final containers = await Directory('${root.path}/containers').create();
    final restored = await Directory('${root.path}/restored').create();
    final cases = <String, int>{};
    for (final chunk in [
      64,
      VaultCrypto.defaultChunkSize,
      VaultCrypto.maxChunkSize,
    ]) {
      final sizes = {
        0,
        1,
        chunk - 1,
        chunk,
        for (var tail = 1; tail <= 16; tail++) chunk + tail,
        chunk * 3 + 17,
      };
      for (final size in sizes) {
        final name = 'chunk-$chunk-size-$size.bin';
        cases[name] = size;
        final plain = await File(
          '${root.path}/input',
        ).writeAsBytes(Uint8List.fromList(List.generate(size, (i) => i % 251)));
        final sink = File('${containers.path}/$name.shtr').openWrite();
        try {
          await sink.addStream(
            crypto.encrypt(plain.openRead(), key, chunkSize: chunk),
          );
        } finally {
          await sink.close();
        }
      }
    }
    final manifest = utf8.encode(
      '{"version":1,"albums":{"synthetic":"Private tag","action":"Running"},'
      '"items":{"synthetic.jpg.shtr":{"title":"Synthetic capture",'
      '"favorite":true,"albums":["synthetic","action"]}}}',
    );
    final metadata = File('${containers.path}/quietake.catalog').openWrite();
    try {
      await metadata.addStream(crypto.encrypt(Stream.value(manifest), key));
    } finally {
      await metadata.close();
    }
    final binary = '${root.path}/recover';
    final build = await Process.run('go', [
      'build',
      '-o',
      binary,
      '.',
    ], workingDirectory: 'recover');
    if (build.exitCode != 0) {
      throw StateError('Recovery build failed: ${build.stderr}');
    }
    final recovery = await Process.run(binary, [
      '-key',
      base64Encode(publicKey),
      '-dir',
      containers.path,
      '-out',
      restored.path,
    ]);
    if (recovery.exitCode != 0) {
      throw StateError('Synthetic recovery failed: ${recovery.stderr}');
    }
    if ((await restored.list().length) != cases.length + 1) {
      throw StateError('Recovery file count differs');
    }
    final recoveredManifest = await File(
      '${restored.path}/quietake.catalog.json',
    ).readAsBytes();
    if (base64Encode(recoveredManifest) != base64Encode(manifest)) {
      throw StateError('Private catalog recovery differs');
    }
    for (final entry in cases.entries) {
      var offset = 0;
      await for (final bytes in File(
        '${restored.path}/${entry.key}',
      ).openRead()) {
        for (final byte in bytes) {
          if (byte != offset % 251) {
            throw StateError('Recovery bytes differ: ${entry.key}');
          }
          offset++;
        }
      }
      if (offset != entry.value) {
        throw StateError('Recovery length differs: ${entry.key}');
      }
    }
    final emptyFolder = await Directory('${root.path}/empty-catalog').create();
    final emptyOutput = await Directory('${root.path}/empty-restored').create();
    final emptyManifest = utf8.encode('{"version":1,"albums":{},"items":{}}');
    final emptySink = File('${emptyFolder.path}/quietake.catalog').openWrite();
    try {
      await emptySink.addStream(
        crypto.encrypt(Stream.value(emptyManifest), key),
      );
    } finally {
      await emptySink.close();
    }
    final emptyRecovery = await Process.run(binary, [
      '-key',
      base64Encode(publicKey),
      '-dir',
      emptyFolder.path,
      '-out',
      emptyOutput.path,
    ]);
    if (emptyRecovery.exitCode != 0 ||
        await emptyOutput.list().length != 1 ||
        base64Encode(
              await File('${emptyOutput.path}/quietake.catalog.json')
                  .readAsBytes(),
            ) !=
            base64Encode(emptyManifest)) {
      throw StateError('Empty ownership catalog recovery differs');
    }
    stdout.writeln(
      'Verified ${cases.length} Dart-to-Go v1 media containers and two encrypted catalog cases, all final-block remainders, 64 B / 256 KiB / 1 MiB chunks.',
    );
    final recoveryBox = await Process.run('flutter', [
      'test',
      'test/nas_recovery_interop_test.dart',
    ]);
    if (recoveryBox.exitCode != 0) {
      throw StateError(
        'Synthetic NAS envelope interoperability failed: ${recoveryBox.stdout} ${recoveryBox.stderr}',
      );
    }
    stdout.writeln(
      'Verified NAS envelope recovery with masked Go CLI, folder and loopback WebDAV.',
    );
  } finally {
    key.dispose();
    await root.delete(recursive: true);
  }
}
