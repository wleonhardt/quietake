import '../test_support/test_vault.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// On-device throughput of the .shtr container. Prints BENCH lines; the
/// number to watch is encrypt MB/s on the OnePlus 13 (target >= 200).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    debugPrint('BENCH encrypt ${encMbps.toStringAsFixed(0)} MB/s '
        '(${sw.elapsedMilliseconds} ms, ${Platform.operatingSystem})');

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
    debugPrint('BENCH decrypt ${decMbps.toStringAsFixed(0)} MB/s '
        '(${sw.elapsedMilliseconds} ms)');
    await enc.delete();
    expect(encMbps, greaterThan(20), reason: 'something is badly wrong');
  });
}
