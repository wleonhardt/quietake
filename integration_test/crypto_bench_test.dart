import '../test_support/integration_binding.dart';
import '../test_support/test_vault.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

/// On-device throughput of the .shtr container. Prints BENCH lines; the
/// number to watch is encrypt MB/s on the OnePlus 13 (target >= 200).
void main() {
  initializeIntegrationBinding();

  testWidgets('NAS recovery KDF wrap and open at fixed production cost', (
    tester,
  ) async {
    final sodium = await SodiumSumoInit.init();
    final tmp = await getTemporaryDirectory();
    final dir = await tmp.createTemp('quietake-kdf-');
    final store = MasterKeyStore(sodium, dir);
    const phrase = 'synthetic river violet paper lantern canyon';
    final mode = kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release');
    try {
      for (var sample = 0; sample < 3; sample++) {
        final key = sodium.crypto.secretBox.keygen();
        try {
          final sw = Stopwatch()..start();
          final envelope = await store.wrapBackupKey(key, phrase);
          sw.stop();
          final wrapMs = sw.elapsedMilliseconds;
          final bytes = utf8.encode(envelope);
          final fields = MasterKeyStore.validateBackupBox(bytes);
          expect(fields['ops'], 3);
          expect(fields['mem'], 268435456);
          sw
            ..reset()
            ..start();
          final restored = await store.openBackupKey(bytes, phrase);
          sw.stop();
          try {
            expect(
              key.runUnlockedSync(
                (original) => restored.runUnlockedSync(
                  (opened) => listEquals(original, opened),
                ),
              ),
              isTrue,
              reason: 'Measured recovery must preserve the synthetic key',
            );
          } finally {
            restored.dispose();
          }
          debugPrint(
            'BENCH NAS_KDF sample=$sample mode=$mode ops=3 mem_mib=256 '
            'wrap_ms=$wrapMs open_ms=${sw.elapsedMilliseconds}',
          );
        } finally {
          key.dispose();
        }
      }
      expect(await dir.list().isEmpty, isTrue);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  testWidgets('encrypt and decrypt 64 MiB', (tester) async {
    final vault = await openTestVault();
    final tmp = await getTemporaryDirectory();
    final plain = File('${tmp.path}/bench.bin');
    const size = 64 * 1024 * 1024;
    final block = Uint8List.fromList(List.generate(1 << 20, (i) => i & 0xff));
    final sink = plain.openWrite();
    for (var i = 0; i < size ~/ block.length; i++) {
      sink.add(block);
    }
    await sink.close();

    final sw = Stopwatch()..start();
    final enc = await vault.ingest(plain, extension: 'bin');
    sw.stop();
    final encMbps = size / 1e6 / (sw.elapsedMilliseconds / 1000);
    debugPrint(
      'BENCH encrypt ${encMbps.toStringAsFixed(0)} MB/s '
      '(${sw.elapsedMilliseconds} ms, ${Platform.operatingSystem})',
    );

    sw
      ..reset()
      ..start();
    var n = 0;
    await for (final c in vault.read(enc)) {
      n += c.length;
    }
    sw.stop();
    expect(n, size);
    final decMbps = size / 1e6 / (sw.elapsedMilliseconds / 1000);
    debugPrint(
      'BENCH decrypt ${decMbps.toStringAsFixed(0)} MB/s '
      '(${sw.elapsedMilliseconds} ms)',
    );
    await enc.delete();
    expect(encMbps, greaterThan(20), reason: 'something is badly wrong');
  });
}
