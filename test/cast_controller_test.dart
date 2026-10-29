import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_backend.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Vault vault;
  late FakeCastBackend backend;
  late CastController cast;
  late VaultItem photo;
  late VaultItem video;
  final client = HttpClient();

  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    dir = await Directory.systemTemp.createTemp('quietake-cast');
    vault = Vault(
      crypto,
      crypto.generateMasterKey(),
      Directory('${dir.path}/vault')..createSync(),
    );
    photo = VaultItem(
      await vault.ingestAs(
        File('${dir.path}/a.jpg')..writeAsBytesSync(Uint8List(5000)),
        'a.jpg',
      ),
    );
    video = VaultItem(
      await vault.ingestAs(
        File('${dir.path}/b.mp4')..writeAsBytesSync(Uint8List(9000)),
        'b.mp4',
      ),
    );
    backend = FakeCastBackend();
    cast = CastController(vault, backend);
  });

  tearDown(() async {
    await cast.stop();
    await dir.delete(recursive: true);
  });

  Future<int> fetchStatus(Uri url) async {
    final req = await client.getUrl(url);
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  test('LAN address is private and not loopback when present', () async {
    final lan = await MediaServer.lanAddress();
    if (lan == null) return; // CI box without a LAN
    expect(lan.isLoopback, isFalse);
    expect(lan.rawAddress.first, isIn([10, 172, 192]));
  });

  test(
    'start binds a LAN server, loads the item, and the receiver can fetch it',
    () async {
      if (await MediaServer.lanAddress() == null) return;
      await cast.start(const CastDevice('tv-1', 'Living Room TV'), photo);
      expect(cast.isCasting, isTrue);
      expect(cast.error, isNull);
      expect(backend.loadedType, 'image/jpeg');
      final url = backend.loadedUrl!;
      expect(url.host, isNot('127.0.0.1'));
      expect(await fetchStatus(url), 200);

      // Switching items revokes the earlier URL.
      await cast.show(video);
      expect(backend.loadedType, 'video/mp4');
      expect(await fetchStatus(url), 404);
      expect(await fetchStatus(backend.loadedUrl!), 200);

      // Stopping closes the LAN server entirely.
      final last = backend.loadedUrl!;
      await cast.stop();
      expect(cast.isCasting, isFalse);
      expect(backend.connected, isNull);
      await expectLater(
        fetchStatus(last),
        throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
      );
      expect(backend.log, [
        'connect tv-1',
        'load image/jpeg a.jpg.shtr',
        'load video/mp4 b.mp4.shtr',
        'disconnect',
      ]);
    },
  );

  test('a refused connection leaves no server behind', () async {
    if (await MediaServer.lanAddress() == null) return;
    backend.failConnect = true;
    await cast.start(const CastDevice('tv-1', 'Living Room TV'), photo);
    expect(cast.isCasting, isFalse);
    expect(cast.error, contains('receiver refused'));
    expect(backend.loadedUrl, isNull);
  });

  test(
    'a discovery failure is reported without becoming a cast error',
    () async {
      backend.failDiscovery = true;
      expect(await cast.startDiscovery(), isFalse);
      expect(cast.error, isNull);
      await cast.stopDiscovery();
      expect(cast.error, isNull);
    },
  );

  test('a second stop waits for the first teardown', () async {
    if (await MediaServer.lanAddress() == null) return;
    await cast.start(const CastDevice('tv', 'TV'), photo);
    final first = cast.stop();
    await cast.stop();
    expect(backend.log.last, 'disconnect');
    expect(backend.connected, isNull);
    await first;
  });

  test('a receiver that never answers a load reports an error', () async {
    if (await MediaServer.lanAddress() == null) return;
    final hanging = _HangingLoadBackend();
    final controller = CastController(
      vault,
      hanging,
      loadTimeout: const Duration(milliseconds: 50),
    );
    try {
      await controller.start(const CastDevice('tv', 'TV'), photo);
      expect(controller.isCasting, isTrue);
      expect(controller.error, contains('TimeoutException'));
    } finally {
      await controller.stop();
      controller.dispose();
    }
  });

  test('the LAN server exists only after the receiver connected', () async {
    if (await MediaServer.lanAddress() == null) return;
    final delayed = _DelayedBackend();
    final controller = CastController(vault, delayed);
    final start = controller.start(const CastDevice('tv', 'TV'), photo);
    await delayed.entered.future;
    expect(controller.lastUrl, isNull);
    delayed.release.complete();
    await start;
    expect(controller.lastUrl, isNotNull);
    expect(await fetchStatus(controller.lastUrl!), 200);
    await controller.stop();
    controller.dispose();
  });

  test('stop during connection rejects a late completion', () async {
    if (await MediaServer.lanAddress() == null) return;
    final delayed = _DelayedBackend();
    final controller = CastController(vault, delayed);
    final start = controller.start(const CastDevice('tv', 'TV'), photo);
    await delayed.entered.future;
    await controller.stop();
    delayed.release.complete();
    await start;
    expect(controller.isCasting, isFalse);
    expect(controller.lastUrl, isNull);
    expect(delayed.connected, isNull);
    controller.dispose();
  });

  test('receiver disconnect closes the LAN server and clears state', () async {
    if (await MediaServer.lanAddress() == null) return;
    await cast.start(const CastDevice('tv', 'TV'), photo);
    final url = cast.lastUrl!;
    final stopped = Completer<void>();
    cast.addListener(() {
      if (!cast.isCasting && !stopped.isCompleted) stopped.complete();
    });
    backend.endFromReceiver();
    await stopped.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cast.lastUrl, isNull);
    await expectLater(
      fetchStatus(url),
      throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
    );
  });

  test('CORS preflight and headers on the media server', () async {
    final server = await MediaServer.start(vault);
    final url = server.register(photo.file);
    final pre = await (await client.openUrl('OPTIONS', url)).close();
    await pre.drain<void>();
    expect(pre.statusCode, 204);
    expect(pre.headers.value('Access-Control-Allow-Origin'), '*');
    final res = await (await client.getUrl(url)).close();
    await res.drain<void>();
    expect(res.headers.value('Access-Control-Allow-Origin'), '*');
    expect(
      res.headers.value('Access-Control-Expose-Headers'),
      contains('Content-Range'),
    );
    await server.close();
  });
}

class _DelayedBackend extends FakeCastBackend {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> connect(CastDevice device) async {
    entered.complete();
    await release.future;
    await super.connect(device);
  }
}

class _HangingLoadBackend extends FakeCastBackend {
  @override
  Future<void> load(Uri url, String contentType, {required String title}) =>
      Completer<void>().future;
}
