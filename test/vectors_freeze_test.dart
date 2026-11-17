import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/share_bundle.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:sodium/sodium_sumo.dart';

/// docs/vectors/ is the contract with the recovery CLI. If this fails, the
/// format changed: bump the version byte, do not regenerate the vectors.
void main() {
  late VaultCrypto crypto;
  late SecureKey master;
  late Map<String, dynamic> v;

  Uint8List hex(String s) =>
      Uint8List.fromList([for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);

  setUpAll(() async {
    final sodium = await SodiumSumoInit.init();
    crypto = VaultCrypto(sodium);
    v = jsonDecode(File('docs/vectors/containers.json').readAsStringSync()) as Map<String, dynamic>;
    master = SecureKey.fromList(sodium, base64Decode(v['recovery_key'] as String));
    expect(master.extractBytes(), hex(v['master_key_hex'] as String));
  });

  test('vector files are byte-identical to the frozen set', () {
    // A regenerated set that still decrypts would pass the other tests.
    for (final entry in {
      'docs/vectors/containers.json':
          '2cbd9774cbd93a82e9870d2a4c2acd1aff35998fcc3d3b6dacd7c5e4d0944723',
      'docs/vectors/keyfile.json':
          '227bcb2662e936c24cb8bc688d84fadfdc559ba0abc8bea43022c4ed645a3ffe',
      'docs/vectors/share.json':
          'd9d5787ad1fe0f1551bc8a5a8d19c811debde2a39b06f4ed7b2912929392a6ee',
      'docs/recovery-vectors/v1.json':
          'a06ee3fcb6a9a73243be5e8097dc213ce060b40f1ba41554731ea46d19431940',
    }.entries) {
      expect(
        sha256.convert(File(entry.key).readAsBytesSync()).toString(),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('every container vector still decrypts to its plaintext', () async {
    for (final c in (v['cases'] as List).cast<Map<String, dynamic>>()) {
      final b = BytesBuilder(copy: false);
      await for (final x in crypto.decrypt(Stream.value(hex(c['container_hex'] as String)), master)) {
        b.add(x);
      }
      expect(b.takeBytes(), hex(c['plaintext_hex'] as String), reason: c['name'] as String);
    }
  });

  test('every share bundle vector opens to its entries', () async {
    final sv = jsonDecode(File('docs/vectors/share.json').readAsStringSync())
        as Map<String, dynamic>;
    final bundle = ShareBundle(crypto.sodium);
    final dir = Directory.systemTemp.createTempSync('share_vec');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final c in (sv['cases'] as List).cast<Map<String, dynamic>>()) {
      final name = c['name'] as String;
      final out = Directory('${dir.path}/$name')..createSync();
      final file = File('${dir.path}/$name.bin')
        ..writeAsBytesSync(hex(c['bundle_hex'] as String));
      final entries = (c['entries'] as List).cast<Map<String, dynamic>>();
      expect(
        await bundle.extract(file, sv['passphrase'] as String, out),
        [for (final e in entries) e['name']],
        reason: name,
      );
      for (final e in entries) {
        expect(
          File('${out.path}/${e['name']}').readAsBytesSync(),
          hex(e['content_hex'] as String),
          reason: name,
        );
      }
    }
  });

  test('keyfile vector unwraps with its passcode', () async {
    final k = jsonDecode(File('docs/vectors/keyfile.json').readAsStringSync()) as Map<String, dynamic>;
    final kf = k['keyfile'] as Map<String, dynamic>;
    final pw = crypto.sodium.crypto.pwhash;
    final kek = pw.callStr(
      outLen: 32,
      password: k['passcode'] as String,
      salt: base64Decode(kf['salt'] as String),
      opsLimit: kf['ops'] as int,
      memLimit: kf['mem'] as int,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
    final raw = crypto.sodium.crypto.secretBox.openEasy(
      cipherText: base64Decode(kf['wrapped'] as String),
      nonce: base64Decode(kf['nonce'] as String),
      key: kek,
    );
    expect(raw, hex(k['expected_master_key_hex'] as String));
  });
}
