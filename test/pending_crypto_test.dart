import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/pending_crypto.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:sodium/sodium_sumo.dart';

Future<Uint8List> _collect(Stream<List<int>> s) async {
  final b = BytesBuilder(copy: false);
  await for (final c in s) {
    b.add(c);
  }
  return b.takeBytes();
}

void main() {
  late SodiumSumo sodium;
  late VaultCrypto vault;
  late PendingCrypto pending;
  late SecureKey master;
  late Directory dir;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    vault = VaultCrypto(sodium);
    pending = PendingCrypto(sodium);
    master = vault.generateMasterKey();
  });

  setUp(() => dir = Directory.systemTemp.createTempSync('pending_crypto'));
  tearDown(() => dir.deleteSync(recursive: true));

  Uint8List data(int n) =>
      Uint8List.fromList(List.generate(n, (i) => (i * 11 + 5) & 0xff));

  for (final n in [0, 1, VaultCrypto.defaultChunkSize, 700000]) {
    test(
      'a sealed capture of $n bytes publishes as an ordinary container',
      () async {
        final keys = pending.generateKeyPair();
        final plain = File('${dir.path}/plain')..writeAsBytesSync(data(n));
        final sealed = File('${dir.path}/a.pending');
        final out = File('${dir.path}/a.shtr');
        await pending.seal(plain, sealed, keys.publicKey);
        await pending.publish(
          sealed,
          out,
          keys.publicKey,
          keys.secretKey,
          master,
        );
        final back = await _collect(vault.decrypt(out.openRead(), master));
        expect(back, data(n));
        expect(await vault.plaintextLength(out), n);
      },
    );
  }

  test(
    'a sealed file does not contain the plaintext and needs the secret key',
    () async {
      final keys = pending.generateKeyPair();
      final other = pending.generateKeyPair();
      final plain = File('${dir.path}/plain')
        ..writeAsBytesSync(Uint8List.fromList(List.filled(4096, 0x41)));
      final sealed = File('${dir.path}/a.pending');
      await pending.seal(plain, sealed, keys.publicKey);
      final raw = sealed.readAsBytesSync();
      expect(raw.sublist(0, 4), PendingCrypto.magic);
      expect(
        raw.contains(0x41) && raw.where((b) => b == 0x41).length < 200,
        isTrue,
      );
      await expectLater(
        pending.publish(
          sealed,
          File('${dir.path}/b.shtr'),
          other.publicKey,
          other.secretKey,
          master,
        ),
        throwsA(anything),
      );
      expect(File('${dir.path}/b.shtr').existsSync(), isFalse);
    },
  );

  test('a damaged or truncated pending file never publishes', () async {
    final keys = pending.generateKeyPair();
    final plain = File('${dir.path}/plain')..writeAsBytesSync(data(1000));
    final sealed = File('${dir.path}/a.pending');
    await pending.seal(plain, sealed, keys.publicKey);
    final raw = sealed.readAsBytesSync();
    final cases = {
      'magic': Uint8List.fromList(raw)..[0] ^= 1,
      'header': Uint8List.fromList(raw.sublist(0, 40)),
      'sealed key': Uint8List.fromList(raw)..[10] ^= 1,
    };
    for (final e in cases.entries) {
      final bad = File('${dir.path}/${e.key}.pending')
        ..writeAsBytesSync(e.value);
      final out = File('${dir.path}/${e.key}.shtr');
      await expectLater(
        pending.publish(bad, out, keys.publicKey, keys.secretKey, master),
        throwsA(anything),
        reason: e.key,
      );
      expect(out.existsSync(), isFalse, reason: e.key);
    }
  });
}
