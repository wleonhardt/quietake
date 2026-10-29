import 'dart:async';
import 'dart:io';

import '../crypto/random_token.dart';
import '../vault/vault.dart';

/// HTTP server that decrypts containers on the fly. Each container is served
/// under an unguessable token path. Supports HEAD and single-range GET so
/// ExoPlayer, AVPlayer and Cast receivers can probe and seek.
///
/// Two instances exist: the app-lifetime one on 127.0.0.1 for the in-app
/// player, and a short-lived one reachable on the Wi-Fi address while a cast
/// session is open (see CastController). Plaintext crosses the LAN only
/// through the second one, only for the duration of the session.
///
/// secretstream chains chunks, so a Range that starts late still decrypts
/// from the first chunk and discards the prefix (see docs/container-format.md).
class MediaServer {
  MediaServer._(this._vault, this._servers, this.address);

  final Vault _vault;

  /// One socket on [address]; a cast server adds loopback on the same port so
  /// the in-process player and tests can reach it without opening any other
  /// interface (decision 040).
  final List<HttpServer> _servers;
  final _routes = <String, File>{};
  final _requests = <Future<void>>{};
  Future<void>? _closing;

  /// Host that URLs from [register] carry.
  final InternetAddress address;

  /// Loopback-only by default. With [lanAddress] set, the server listens on
  /// that address only, plus loopback on the same port; URLs carry the LAN
  /// address so a TV can fetch them. VPN and tunnel interfaces never serve.
  static Future<MediaServer> start(
    Vault vault, {
    InternetAddress? lanAddress,
  }) async {
    final primary = await HttpServer.bind(
      lanAddress ?? InternetAddress.loopbackIPv4,
      0,
    );
    final servers = [primary];
    if (lanAddress != null) {
      try {
        servers.add(
          await HttpServer.bind(InternetAddress.loopbackIPv4, primary.port),
        );
      } catch (_) {
        // Loopback on this port is taken; in-app playback uses the
        // app-lifetime loopback server anyway.
      }
    }
    final ms = MediaServer._(
      vault,
      servers,
      lanAddress ?? InternetAddress.loopbackIPv4,
    );
    for (final server in servers) {
      server.listen((request) {
        final pending = ms._handle(request);
        ms._requests.add(pending);
        pending.whenComplete(() => ms._requests.remove(pending));
      });
    }
    return ms;
  }

  /// Private Wi-Fi/Ethernet IPv4 address, excluding VPN/tunnel interfaces.
  static Future<InternetAddress?> lanAddress() async {
    final ifs = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    return selectLanAddress([
      for (final i in ifs)
        for (final a in i.addresses) (i.name, a),
    ]);
  }

  static InternetAddress? selectLanAddress(
    Iterable<(String, InternetAddress)> addresses,
  ) {
    for (final (name, a) in addresses) {
      // Android Wi-Fi, Apple network interfaces, and wired Android/Linux LANs.
      if (!name.startsWith('wlan') &&
          !name.startsWith('en') &&
          !name.startsWith('eth')) {
        continue;
      }
      if (!a.isLoopback && _isPrivate(a)) return a;
    }
    return null;
  }

  static bool _isPrivate(InternetAddress a) {
    final b = a.rawAddress;
    return b[0] == 10 ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31);
  }

  int get port => _servers.first.port;

  /// Registers [container] and returns its playback URL.
  Uri register(File container) {
    final token = randomHexToken(_vault.crypto.sodium);
    _routes[token] = container;
    return Uri.parse('http://${address.address}:$port/$token');
  }

  void unregister(Uri url) => _routes.remove(url.pathSegments.last);

  /// Forgets every token; existing URLs stop working immediately.
  void revokeAll() => _routes.clear();

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    revokeAll();
    for (final server in _servers) {
      await server.close(force: true);
    }
    // A closed socket can still have a decrypt stream using the session key.
    // Finish those handlers before Session disposes the vault.
    while (_requests.isNotEmpty) {
      await Future.wait(_requests.toList());
    }
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      await _serve(req);
    } catch (_) {
      // Disconnects and corrupt containers must not escape the HTTP listener.
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serve(HttpRequest req) async {
    final res = req.response;
    // Cast receivers run as web apps and preflight some requests.
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Range, Content-Type')
      ..set(
        'Access-Control-Expose-Headers',
        'Content-Length, Content-Range, Accept-Ranges',
      );
    if (req.method == 'OPTIONS') {
      res.statusCode = HttpStatus.noContent;
      await res.close();
      return;
    }
    final file = _routes[req.uri.path.substring(1)];
    if (file == null || (req.method != 'GET' && req.method != 'HEAD')) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final total = await _vault.crypto.plaintextLength(file);
    var start = 0;
    var end = total - 1;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      final m = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
      var valid = m != null && total > 0;
      if (valid) {
        final first = int.tryParse(m[1]!);
        final last = int.tryParse(m[2]!);
        if (m[1]!.isEmpty) {
          valid = last != null && last > 0;
          if (valid) start = (total - last).clamp(0, total);
        } else {
          valid = first != null && (m[2]!.isEmpty || last != null);
          if (valid) {
            start = first;
            if (last != null) end = last.clamp(0, total - 1);
          }
        }
      }
      if (!valid || start >= total || end < start) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$total',
      );
    }
    res.headers
      ..contentType = _contentType(file.path)
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..contentLength = end - start + 1;
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    final reader = StreamIterator(_vault.read(file));
    try {
      await res.addStream(_slice(reader, start, end + 1));
    } finally {
      await reader.cancel();
      await res.close();
    }
  }

  static Stream<List<int>> _slice(
    StreamIterator<List<int>> reader,
    int start,
    int endExclusive,
  ) async* {
    var pos = 0;
    while (await reader.moveNext()) {
      final chunk = reader.current;
      final a = (start - pos).clamp(0, chunk.length);
      final b = (endExclusive - pos).clamp(0, chunk.length);
      if (b > a) yield chunk.sublist(a, b);
      pos += chunk.length;
      if (pos >= endExclusive) return;
    }
  }

  static ContentType _contentType(String path) {
    final name = path.split('/').last;
    final ext = name.split('.').reversed.skip(1).first;
    return switch (ext) {
      'mp4' || 'mov' => ContentType('video', 'mp4'),
      'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
      'png' => ContentType('image', 'png'),
      _ => ContentType.binary,
    };
  }
}
