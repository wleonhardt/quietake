import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:sodium/sodium_sumo.dart';

Future<Uint8List> collect(Stream<List<int>> s) async {
  final b = BytesBuilder(copy: false);
  await for (final c in s) {
    b.add(c);
  }
  return b.takeBytes();
}

void main() {
  late SodiumSumo sodium;
  late VaultCrypto vault;
  late SecureKey key;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    vault = VaultCrypto(sodium);
    key = vault.generateMasterKey();
  });

  Uint8List bytes(int n) =>
      Uint8List.fromList(List.generate(n, (i) => (i * 7 + 3) & 0xff));

  const chunk = 1024;
  for (final n in [
    0,
    1,
    chunk - 1,
    chunk,
    chunk + 1,
    chunk * 3,
    chunk * 3 + 17,
  ]) {
    test('round trip $n bytes', () async {
      final plain = bytes(n);
      final cipher = await collect(
        vault.encrypt(Stream.value(plain), key, chunkSize: chunk),
      );
      final fullChunks = n ~/ chunk;
      final finalLen = n - fullChunks * chunk;
      expect(
        cipher.length,
        vault.headerLength + fullChunks * (chunk + 17) + finalLen + 17,
      );
      final back = await collect(vault.decrypt(Stream.value(cipher), key));
      expect(back, plain);
    });
  }

  test('decrypts when the cipher stream arrives in odd pieces', () async {
    final plain = bytes(chunk * 2 + 5);
    final cipher = await collect(
      vault.encrypt(Stream.value(plain), key, chunkSize: chunk),
    );
    final pieces = <List<int>>[];
    for (var i = 0; i < cipher.length; i += 37) {
      pieces.add(cipher.sublist(i, (i + 37).clamp(0, cipher.length)));
    }
    final back = await collect(vault.decrypt(Stream.fromIterable(pieces), key));
    expect(back, plain);
  });

  test('wrong master key fails', () async {
    final cipher = await collect(vault.encrypt(Stream.value(bytes(100)), key));
    final other = vault.generateMasterKey();
    await expectLater(
      collect(vault.decrypt(Stream.value(cipher), other)),
      throwsA(isA<SodiumException>()),
    );
    other.dispose();
  });

  test('tampered chunk fails', () async {
    final cipher = await collect(vault.encrypt(Stream.value(bytes(100)), key));
    cipher[cipher.length - 1] ^= 0x01;
    await expectLater(
      collect(vault.decrypt(Stream.value(cipher), key)),
      throwsA(isA<SodiumException>()),
    );
  });

  test('truncated file fails', () async {
    final cipher = await collect(
      vault.encrypt(Stream.value(bytes(chunk * 2)), key, chunkSize: chunk),
    );
    final cut = cipher.sublist(0, cipher.length - 17);
    await expectLater(
      collect(vault.decrypt(Stream.value(cut), key)),
      throwsA(anything),
    );
  });

  test('partial decryption cancels its source', () async {
    final cipher = await collect(
      vault.encrypt(Stream.value(bytes(chunk * 3)), key, chunkSize: chunk),
    );
    var cancelled = false;
    final source = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    source.add(cipher);
    await for (final _ in vault.decrypt(source.stream, key)) {
      break;
    }
    expect(cancelled, isTrue);
  });

  test('bad header cancels its source', () async {
    var cancelled = false;
    final source = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    source.add(List.filled(100, 0));
    await expectLater(
      collect(vault.decrypt(source.stream, key)),
      throwsFormatException,
    );
    expect(cancelled, isTrue);
  });

  test(
    'rejects trailing data, reordered chunks and malformed headers',
    () async {
      final cipher = await collect(
        vault.encrypt(
          Stream.value(bytes(chunk * 3 + 9)),
          key,
          chunkSize: chunk,
        ),
      );
      final reordered = Uint8List.fromList(cipher);
      final a = reordered.sublist(
        vault.headerLength,
        vault.headerLength + chunk + 17,
      );
      final b = reordered.sublist(
        vault.headerLength + chunk + 17,
        vault.headerLength + 2 * (chunk + 17),
      );
      reordered.setRange(
        vault.headerLength,
        vault.headerLength + chunk + 17,
        b,
      );
      reordered.setRange(
        vault.headerLength + chunk + 17,
        vault.headerLength + 2 * (chunk + 17),
        a,
      );
      final zeroChunk = Uint8List.fromList(cipher)..fillRange(6, 10, 0);
      final badVersion = Uint8List.fromList(cipher)..[4] = 99;
      for (final bad in [
        Uint8List.fromList([...cipher, 0]),
        reordered,
        zeroChunk,
        badVersion,
        cipher.sublist(0, 50),
      ]) {
        await expectLater(
          collect(vault.decrypt(Stream.value(bad), key)),
          throwsA(anything),
        );
      }
    },
  );

  test(
    'oversized chunk metadata is rejected before stream allocation',
    () async {
      final cipher = await collect(
        vault.encrypt(Stream.value(bytes(100)), key),
      );
      ByteData.sublistView(cipher, 6, 10).setUint32(0, (1 << 20) + 1);
      await expectLater(
        collect(vault.decrypt(Stream.value(cipher), key)),
        throwsFormatException,
      );
      final dir = await Directory.systemTemp.createTemp('quietake-budget');
      try {
        final file = await File('${dir.path}/oversized.shtr')
            .writeAsBytes(cipher);
        await expectLater(vault.plaintextLength(file), throwsFormatException);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'one MiB chunks stay compatible and writers reject unsupported sizes',
    () async {
      final plain = bytes((1 << 20) + 17);
      final cipher = await collect(
        vault.encrypt(Stream.value(plain), key, chunkSize: 1 << 20),
      );
      expect(await collect(vault.decrypt(Stream.value(cipher), key)), plain);
      for (final invalid in [0, -1, (1 << 20) + 1]) {
        await expectLater(
          collect(vault.encrypt(const Stream.empty(), key, chunkSize: invalid)),
          throwsArgumentError,
        );
      }
    },
  );

  test('file round trip', () async {
    final dir = await Directory.systemTemp.createTemp('quietake');
    final plain = File('${dir.path}/in.bin')..writeAsBytesSync(bytes(300000));
    final enc = File('${dir.path}/out.shtr');
    final dec = File('${dir.path}/back.bin');
    await vault.encryptFile(plain, enc, key);
    final sink = dec.openWrite();
    await sink.addStream(vault.decrypt(enc.openRead(), key));
    await sink.close();
    expect(dec.readAsBytesSync(), plain.readAsBytesSync());
    await dir.delete(recursive: true);
  });
}
