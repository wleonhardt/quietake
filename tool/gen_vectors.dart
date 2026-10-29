// Writes docs/vectors/*.json from the Dart (libsodium) implementation so an
// independent reader can prove it follows docs/container-format.md.
//
//   dart run tool/gen_vectors.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:quietake/crypto/vault_crypto.dart';
import 'package:sodium/sodium_sumo.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<void> main() async {
  final sodium = await SodiumSumoInit.init();
  final crypto = VaultCrypto(sodium);
  final out = Directory('docs/vectors')..createSync(recursive: true);

  // Fixed master key so the vectors are reproducible from the recovery key.
  final masterBytes = Uint8List.fromList(List.generate(32, (i) => (i * 37 + 11) & 0xff));
  final master = SecureKey.fromList(sodium, masterBytes);

  final cases = <Map<String, Object>>[];
  Future<void> add(String name, int n, int chunk) async {
    final plain = Uint8List.fromList(List.generate(n, (i) => (i * 7 + 3) & 0xff));
    final b = BytesBuilder(copy: false);
    await for (final c in crypto.encrypt(Stream.value(plain), master, chunkSize: chunk)) {
      b.add(c);
    }
    cases.add({'name': name, 'chunk_size': chunk, 'plaintext_hex': hex(plain), 'container_hex': hex(b.takeBytes())});
  }

  await add('empty', 0, 64);
  await add('one_byte', 1, 64);
  await add('chunk_minus_one', 63, 64);
  await add('exact_chunk', 64, 64);
  await add('chunk_plus_one', 65, 64);
  await add('three_chunks_tail', 3 * 64 + 17, 64);
  await add('exact_three_chunks', 3 * 64, 64);
  await add('default_chunk_small_file', 1000, VaultCrypto.defaultChunkSize);

  File('${out.path}/containers.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'format': 'shtr v1, see docs/container-format.md',
    'master_key_hex': hex(masterBytes),
    'recovery_key': base64Encode(masterBytes),
    'cases': cases,
  }));

  // Keyfile vector: fixed salt, interactive limits so a test stays quick.
  final pw = sodium.crypto.pwhash;
  final salt = Uint8List.fromList(List.generate(pw.saltBytes, (i) => i));
  final kek = pw.callStr(
    outLen: 32,
    password: 'correct horse battery staple',
    salt: salt,
    opsLimit: pw.opsLimitInteractive,
    memLimit: pw.memLimitInteractive,
    alg: CryptoPwhashAlgorithm.argon2id13,
  );
  final nonce = Uint8List.fromList(List.generate(24, (i) => 0xa0 + i));
  final wrapped = sodium.crypto.secretBox.easy(message: masterBytes, nonce: nonce, key: kek);
  File('${out.path}/keyfile.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'passcode': 'correct horse battery staple',
    'expected_master_key_hex': hex(masterBytes),
    'keyfile': {
      'v': 1,
      'kdf': 'argon2id13',
      'salt': base64Encode(salt),
      'ops': pw.opsLimitInteractive,
      'mem': pw.memLimitInteractive,
      'nonce': base64Encode(nonce),
      'wrapped': base64Encode(wrapped),
    },
  }));
  stdout.writeln('wrote ${cases.length} container vectors and 1 keyfile vector');
}
