import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  test(
    'ingesting an existing name never replaces the earlier capture',
    () async {
      final sodium = await SodiumSumoInit.init();
      final crypto = VaultCrypto(sodium);
      final dir = await Directory.systemTemp.createTemp('quietake-vault');
      final vault = Vault(crypto, crypto.generateMasterKey(), dir);
      try {
        final first = await vault.ingestAs(
          File('${dir.path}/a')..writeAsBytesSync([1, 2, 3]),
          'same.jpg',
        );
        final second = File('${dir.path}/b')..writeAsBytesSync([9, 9, 9]);
        await expectLater(
          vault.ingestAs(second, 'same.jpg'),
          throwsA(isA<FileSystemException>()),
        );
        expect(await vault.readAll(first), [1, 2, 3]);
        expect(await File('${first.path}.part').exists(), isFalse);
      } finally {
        vault.dispose();
        await dir.delete(recursive: true);
      }
    },
  );
}
