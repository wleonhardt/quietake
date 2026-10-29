import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

class DelayedVault extends Vault {
  DelayedVault(super.crypto, super.key, super.dir);
  final entered = Completer<void>();
  final release = Completer<void>();
  final finished = Completer<void>();

  @override
  Stream<List<int>> read(File container) async* {
    entered.complete();
    try {
      await release.future;
      yield* super.read(container);
    } finally {
      finished.complete();
    }
  }
}

void main() {
  test('server shutdown drains active reads before the vault can be disposed', () async {
    final sodium = await SodiumSumoInit.init();
    final dir = await Directory.systemTemp.createTemp('quietake-shutdown');
    final crypto = VaultCrypto(sodium);
    final vault = DelayedVault(crypto, crypto.generateMasterKey(), dir);
    final input = File('${dir.path}/input')
      ..writeAsBytesSync(List.filled(100, 7));
    final file = await vault.ingestAs(input, 'clip.mp4');
    final server = await MediaServer.start(vault);
    final client = HttpClient();
    var closed = false;
    Future<void>? closing;
    final request = () async {
      try {
        final req = await client.getUrl(server.register(file));
        final res = await req.close();
        await res.drain<void>();
      } on IOException {
        // Force-closing the listening socket may cancel the client's response.
      }
    }();
    try {
      await vault.entered.future.timeout(const Duration(seconds: 5));
      closing = server.close().then((_) => closed = true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        closed,
        isFalse,
        reason: 'An active read still uses the vault key',
      );
      vault.release.complete();
      await closing.timeout(const Duration(seconds: 5));
      expect(vault.finished.isCompleted, isTrue);
    } finally {
      if (!vault.release.isCompleted) vault.release.complete();
      await (closing ?? server.close());
      await request.timeout(const Duration(seconds: 5));
      await vault.finished.future.timeout(const Duration(seconds: 5));
      client.close(force: true);
      vault.dispose();
      await dir.delete(recursive: true);
    }
  });
}
