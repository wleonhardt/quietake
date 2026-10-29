import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Directory dir;
  late Vault vault;
  late MediaServer server;
  late Uri url;
  late Uint8List plain;
  final client = HttpClient();

  setUpAll(() async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    dir = await Directory.systemTemp.createTemp('quietake-ms');
    vault = Vault(crypto, crypto.generateMasterKey(), dir);
    // Three full chunks plus a tail, with a small chunk size for speed.
    plain = Uint8List.fromList(
      List.generate(3 * 4096 + 123, (i) => (i * 31) & 0xff),
    );
    final src = File('${dir.path}/clip.bin')..writeAsBytesSync(plain);
    final out = File('${dir.path}/clip.mp4.shtr');
    final sink = out.openWrite();
    await sink.addStream(
      crypto.encrypt(src.openRead(), vaultKey(vault), chunkSize: 4096),
    );
    await sink.close();
    server = await MediaServer.start(vault);
    url = server.register(out);
  });

  tearDownAll(() async {
    await server.close();
    await dir.delete(recursive: true);
  });

  Future<(HttpClientResponse, Uint8List)> get(
    String method, {
    String? range,
  }) async {
    final req = await client.openUrl(method, url);
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    final res = await req.close();
    final b = BytesBuilder(copy: false);
    await for (final c in res) {
      b.add(c);
    }
    return (res, b.takeBytes());
  }

  test('plaintextLength matches', () async {
    expect(
      await vault.crypto.plaintextLength(
        File.fromUri(Uri.file('${dir.path}/clip.mp4.shtr')),
      ),
      plain.length,
    );
  });

  test('HEAD reports length, type and byte ranges', () async {
    final (res, body) = await get('HEAD');
    expect(res.statusCode, 200);
    expect(res.contentLength, plain.length);
    expect(res.headers.contentType.toString(), 'video/mp4');
    expect(res.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    expect(body, isEmpty);
  });

  test('GET whole file', () async {
    final (res, body) = await get('GET');
    expect(res.statusCode, 200);
    expect(body, plain);
  });

  test('GET bytes=100-199 crosses nothing, exact slice', () async {
    final (res, body) = await get('GET', range: 'bytes=100-199');
    expect(res.statusCode, 206);
    expect(
      res.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 100-199/${plain.length}',
    );
    expect(body, plain.sublist(100, 200));
  });

  test('GET range across chunk boundaries and open-ended', () async {
    final (res, body) = await get('GET', range: 'bytes=4000-');
    expect(res.statusCode, 206);
    expect(body, plain.sublist(4000));
  });

  test('GET suffix range', () async {
    final (res, body) = await get('GET', range: 'bytes=-50');
    expect(res.statusCode, 206);
    expect(body, plain.sublist(plain.length - 50));
  });

  test('range past the end is 416', () async {
    final (res, _) = await get('GET', range: 'bytes=999999-');
    expect(res.statusCode, 416);
  });

  for (final range in [
    'bytes=200-100',
    'bytes=-',
    'bytes=-0',
    'bytes=999999999999999999999999999999-',
    'bytes=0-1,3-4',
  ]) {
    test(
      'invalid range $range returns 416 without breaking playback',
      () async {
        final (res, body) = await get('GET', range: range);
        expect(res.statusCode, 416);
        expect(
          res.headers.value(HttpHeaders.contentRangeHeader),
          'bytes */${plain.length}',
        );
        expect(body, isEmpty);
        expect((await get('GET')).$2, plain);
      },
    );
  }

  test('decrypted responses are never cacheable', () async {
    final (res, _) = await get('GET');
    expect(res.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
  });

  test('a LAN-scoped server still answers on loopback', () async {
    final lan = await MediaServer.lanAddress();
    if (lan == null) return;
    final scoped = await MediaServer.start(vault, lanAddress: lan);
    try {
      final token = scoped.register(File('${dir.path}/clip.mp4.shtr'));
      final local = token.replace(host: '127.0.0.1');
      final res = await (await client.getUrl(local)).close();
      await res.drain<void>();
      expect(res.statusCode, 200);
    } finally {
      await scoped.close();
    }
  });

  test('unknown token is 404', () async {
    final req = await client.getUrl(url.replace(path: '/nope'));
    final res = await req.close();
    expect(res.statusCode, 404);
    await res.drain<void>();
  });
}

/// Test-only reach into the vault's key for building a custom-chunked file.
SecureKey vaultKey(Vault v) => v.masterKeyForTests;
