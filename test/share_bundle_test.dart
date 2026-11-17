import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/share_bundle.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late ShareBundle bundle;
  late Directory dir;
  late Directory dest;
  late File out;

  setUpAll(() async {
    bundle = ShareBundle(await SodiumSumoInit.init());
  });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('share_bundle');
    dest = Directory('${dir.path}/out')..createSync();
    out = File('${dir.path}/a.quietake-share');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Uint8List data(int n, int seed) =>
      Uint8List.fromList(List.generate(n, (i) => (i * 7 + seed) & 0xff));

  ShareEntry entry(String name, Uint8List bytes) {
    final f = File('${dir.path}/src-${name.hashCode}')..writeAsBytesSync(bytes);
    return ShareEntry(name, f);
  }

  Future<void> write(List<ShareEntry> e, {int chunk = 64}) => bundle.write(
    out,
    'correct horse',
    e,
    ops: 1,
    mem: 8192,
    chunkSize: chunk,
  );

  Future<List<String>> open({String pass = 'correct horse', int? max}) =>
      bundle.extract(out, pass, dest, maxTotal: max ?? 1 << 20);

  test(
    'a bundle with more entries than allowed is rejected and cleaned up',
    () async {
      await write([
        for (var i = 0; i <= ShareBundle.maxEntries; i++)
          entry('f-$i.jpg', Uint8List(0)),
      ]);
      await expectLater(open(), throwsA(isA<ShareBundleException>()));
      expect(dest.listSync(), isEmpty);
    },
  );

  test('a bundle at the entry limit is accepted', () async {
    await write([
      for (var i = 0; i < ShareBundle.maxEntries; i++)
        entry('f-$i.jpg', Uint8List(0)),
    ]);
    expect(await open(), hasLength(ShareBundle.maxEntries));
  });

  test(
    'round trip keeps names, order and bytes across chunk boundaries',
    () async {
      final inputs = {
        'photo-01.jpg': data(0, 1),
        'photo-02.jpg': data(1, 2),
        'video-03.mp4': data(64, 3),
        'video-04.mp4': data(1000, 4),
      };
      await write([for (final e in inputs.entries) entry(e.key, e.value)]);
      expect(await open(), inputs.keys.toList());
      for (final e in inputs.entries) {
        expect(File('${dest.path}/${e.key}').readAsBytesSync(), e.value);
      }
    },
  );

  test('a bundle with no entries is valid', () async {
    await write([]);
    expect(await open(), isEmpty);
    expect(dest.listSync(), isEmpty);
  });

  test('the file has the documented header and no plaintext names', () async {
    await write([entry('secret-name.jpg', data(10, 1))]);
    final b = out.readAsBytesSync();
    expect(b.sublist(0, 6), [0x53, 0x48, 0x53, 0x42, 1, 0]);
    final v = ByteData.sublistView(b);
    expect([v.getUint32(6), v.getUint32(10), v.getUint32(14)], [64, 1, 8192]);
    expect(String.fromCharCodes(b).contains('secret-name'), isFalse);
    // header 148 + one FINAL chunk: 4 + 15 + 8 + 10 bytes plus 17.
    expect(b.length, 148 + 37 + 17);
    expect(File('${out.path}.part').existsSync(), isFalse);
  });

  test('a wrong passphrase fails before extracting anything', () async {
    await write([entry('a.jpg', data(100, 1))]);
    await expectLater(
      open(pass: 'wrong'),
      throwsA(isA<ShareBundleException>()),
    );
    expect(dest.listSync(), isEmpty);
  });

  test(
    'random damage only raises ShareBundleException and leaves no files',
    () async {
      await write([entry('a.jpg', data(300, 1)), entry('b.jpg', data(5, 2))]);
      final good = out.readAsBytesSync();
      final random = Random(20261117);
      for (var run = 0; run < 200; run++) {
        final bad = Uint8List.fromList(good);
        for (var i = random.nextInt(3); i >= 0; i--) {
          var at = random.nextInt(bad.length);
          // Offset 5 is the reserved byte and offset 17 the low byte of the
          // memory cost, which Argon2 rounds down to whole KiB; neither changes
          // the derived key or the content.
          if (at == 5 || at == 17) at = 6;
          bad[at] ^= 1 + random.nextInt(255);
        }
        out.writeAsBytesSync(bad);
        await expectLater(
          open(),
          throwsA(isA<ShareBundleException>()),
          reason: 'run $run',
        );
        expect(dest.listSync(), isEmpty, reason: 'run $run');
      }
    },
  );

  test('a changed byte anywhere fails and leaves no files', () async {
    await write([entry('a.jpg', data(300, 1)), entry('b.jpg', data(5, 2))]);
    final good = out.readAsBytesSync();
    for (final at in [0, 4, 20, 40, 100, 130, 148, 200, good.length - 1]) {
      final bad = Uint8List.fromList(good)..[at] ^= 1;
      out.writeAsBytesSync(bad);
      await expectLater(
        open(),
        throwsA(isA<ShareBundleException>()),
        reason: '$at',
      );
      expect(dest.listSync(), isEmpty, reason: '$at');
    }
  });

  test(
    'truncation at any length fails, including on a chunk boundary',
    () async {
      await write([entry('a.jpg', data(300, 1))]);
      final good = out.readAsBytesSync();
      final cuts = [0, 10, 147, 148, 148 + 81, 148 + 2 * 81, good.length - 1];
      for (final n in cuts) {
        out.writeAsBytesSync(good.sublist(0, n));
        await expectLater(
          open(),
          throwsA(isA<ShareBundleException>()),
          reason: '$n',
        );
        expect(dest.listSync(), isEmpty, reason: '$n');
      }
    },
  );

  test('data after the final chunk is rejected', () async {
    await write([entry('a.jpg', data(10, 1))]);
    final good = out.readAsBytesSync();
    out.writeAsBytesSync([...good, ...List.filled(81, 7)]);
    await expectLater(open(), throwsA(isA<ShareBundleException>()));
  });

  test('unsafe or duplicate names are refused by the writer', () async {
    for (final name in [
      '',
      '.',
      '..',
      'a/b',
      r'a\b',
      'a\nb',
      'a\x00b',
      'x' * 256,
    ]) {
      await expectLater(
        write([entry(name, data(1, 1))]),
        throwsA(isA<ShareBundleException>()),
        reason: name,
      );
    }
    await expectLater(
      write([entry('A.jpg', data(1, 1)), entry('a.JPG', data(1, 2))]),
      throwsA(isA<ShareBundleException>()),
    );
    expect(out.existsSync(), isFalse);
  });

  test('a reader refuses costs and sizes outside the limits', () async {
    await write([entry('a.jpg', data(10, 1))]);
    final good = out.readAsBytesSync();
    void poke(int at, int value) {
      final b = Uint8List.fromList(good);
      ByteData.sublistView(b).setUint32(at, value);
      out.writeAsBytesSync(b);
    }

    for (final (at, v) in [
      (6, 0),
      (6, (1 << 20) + 1),
      (10, 0),
      (10, 4),
      (14, 8191),
      (14, (256 << 20) + 1),
    ]) {
      poke(at, v);
      await expectLater(
        open(),
        throwsA(isA<ShareBundleException>()),
        reason: '$at=$v',
      );
    }
  });

  test('the extraction cap stops an oversized bundle', () async {
    await write([entry('a.jpg', data(500, 1)), entry('b.jpg', data(500, 2))]);
    await expectLater(open(max: 999), throwsA(isA<ShareBundleException>()));
    expect(dest.listSync(), isEmpty);
    expect(await open(max: 1000), ['a.jpg', 'b.jpg']);
  });

  test('passphrases of 0 or more than 1024 bytes are refused', () async {
    for (final p in ['', 'x' * 1025]) {
      await expectLater(
        bundle.write(out, p, [], ops: 1, mem: 8192),
        throwsA(isA<ShareBundleException>()),
      );
    }
  });
}
