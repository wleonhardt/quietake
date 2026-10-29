import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Just enough WebDAV for the sync tests: one flat collection under
/// [prefix], Basic auth, PROPFIND depth 1, MKCOL, PUT, GET, DELETE.
/// Runs in-process on loopback, on the host and inside the app on a device.
class FakeWebDavServer {
  FakeWebDavServer._(this._server, this.username, this.password, this.prefix);

  final HttpServer _server;
  final String username;
  final String password;
  final String prefix;
  final files = <String, List<int>>{};
  bool collectionExists = false;
  bool failMoves = false;
  bool failDeletes = false;
  bool weakEtags = false;
  bool emptyContentLength = false;
  bool lockSupported = true;
  String lockDepth = 'infinity';
  String lockTimeout = 'Second-300';
  String? lease;
  int _leases = 0;
  String etag(String name) =>
      '${weakEtags ? 'W/' : ''}"${sha256.convert(files[name]!)}"';
  final log = <String>[];
  final stalledGets = <String>{};
  Future<void> Function(HttpRequest)? beforeRequest;
  Future<bool> Function(HttpRequest)? respond;

  static Future<FakeWebDavServer> start({
    String username = 'vaultapp',
    String password = 'secret',
    String prefix = '/vault/',
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = FakeWebDavServer._(server, username, password, prefix);
    server.listen(s._handle);
    return s;
  }

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}$prefix');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    log.add('${req.method} ${req.uri.path}');
    await beforeRequest?.call(req);
    final auth = req.headers.value(HttpHeaders.authorizationHeader);
    final expected =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    if (auth != expected) {
      res.statusCode = 401;
      res.headers.set('WWW-Authenticate', 'Basic realm="fake"');
      await req.drain<void>();
      await res.close();
      return;
    }
    final path = req.uri.path;
    final inCollection = path.startsWith(prefix) || '$path/' == prefix;
    if (!inCollection) {
      res.statusCode = 404;
      await req.drain<void>();
      await res.close();
      return;
    }
    final name = Uri.decodeComponent(
      path.length > prefix.length ? path.substring(prefix.length) : '',
    );

    if (await respond?.call(req) == true) return;
    if (req.method == 'LOCK') {
      await req.drain<void>();
      if (!lockSupported || !collectionExists || lease != null) {
        res.statusCode = lease != null ? 423 : 405;
      } else {
        lease = 'urn:uuid:synthetic-${++_leases}';
        res.statusCode = 200;
        res.headers.set('Lock-Token', '<$lease>');
        res.write(
          '<d:prop xmlns:d="DAV:"><d:lockdiscovery><d:activelock>'
          '<d:lockscope><d:exclusive/></d:lockscope><d:locktype><d:write/></d:locktype>'
          '<d:depth>$lockDepth</d:depth><d:timeout>$lockTimeout</d:timeout>'
          '<d:locktoken><d:href>$lease</d:href></d:locktoken>'
          '<d:lockroot><d:href>$url</d:href></d:lockroot>'
          '</d:activelock></d:lockdiscovery></d:prop>',
        );
      }
      await res.close();
      return;
    }
    if (req.method == 'UNLOCK') {
      await req.drain<void>();
      res.statusCode =
          lease != null && req.headers.value('Lock-Token') == '<$lease>'
          ? 204
          : 409;
      if (res.statusCode == 204) lease = null;
      await res.close();
      return;
    }
    final condition = req.headers.value('If');
    if (condition != null) {
      final lists = RegExp(r'<([^>]+)> \(([^)]*)\)')
          .allMatches(condition)
          .toList();
      final matches = lists.any((list) {
        final target = Uri.parse(list.group(1)!);
        final predicates = RegExp(r'<([^>]+)>|\[("[^"\r\n]*")\]')
            .allMatches(list.group(2)!)
            .toList();
        return predicates.isNotEmpty &&
            predicates.every((p) {
              if (p.group(1) != null) {
                return lease != null &&
                    p.group(1) == lease &&
                    (target == url ||
                        files.containsKey(target.pathSegments.last));
              }
              final n = target.pathSegments.last;
              return files.containsKey(n) && etag(n) == p.group(2);
            });
      });
      // RFC 4918: different tagged lists OR; predicates inside one list AND.
      if (!matches) {
        res.statusCode = 412;
        await req.drain<void>();
        await res.close();
        return;
      }
    }
    if (lease != null &&
        ['PUT', 'MOVE', 'DELETE', 'MKCOL'].contains(req.method) &&
        !(condition?.contains('<$lease>') ?? false)) {
      res.statusCode = 423;
      await req.drain<void>();
      await res.close();
      return;
    }
    switch (req.method) {
      case 'MKCOL':
        await req.drain<void>();
        res.statusCode = collectionExists ? 405 : 201;
        collectionExists = true;
      case 'PROPFIND':
        await req.drain<void>();
        if (!collectionExists) {
          res.statusCode = 404;
          break;
        }
        res.statusCode = 207;
        res.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        final b = StringBuffer(
          '<?xml version="1.0"?><D:multistatus xmlns:D="DAV:">',
        );
        b.write(
          '<D:response><D:href>$prefix</D:href><D:propstat><D:prop>'
          '<D:resourcetype><D:collection/></D:resourcetype></D:prop>'
          '<D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>',
        );
        for (final e in files.entries) {
          b.write(
            '<D:response><D:href>$prefix${Uri.encodeComponent(e.key)}</D:href>'
            '<D:propstat><D:prop><D:resourcetype/>'
            '<D:getcontentlength>${emptyContentLength ? '' : e.value.length}</D:getcontentlength>'
            '<D:getetag>${etag(e.key)}</D:getetag></D:prop>'
            '<D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>',
          );
        }
        b.write('</D:multistatus>');
        res.write(b.toString());
      case 'PUT':
        final body = <int>[];
        await for (final c in req) {
          body.addAll(c);
        }
        res.statusCode = files.containsKey(name) ? 204 : 201;
        files[name] = body;
      case 'HEAD':
        await req.drain<void>();
        res.statusCode = files.containsKey(name) ? 200 : 404;
      case 'GET':
        await req.drain<void>();
        if (stalledGets.contains(name)) return;
        final data = files[name];
        if (data == null) {
          res.statusCode = 404;
        } else {
          res.headers.set(HttpHeaders.etagHeader, etag(name));
          res.contentLength = data.length;
          res.add(data);
        }
      case 'MOVE':
        await req.drain<void>();
        if (failMoves) {
          res.statusCode = 503;
          break;
        }
        final destination = Uri.parse(req.headers.value('Destination')!)
            .pathSegments
            .last;
        if (!files.containsKey(name)) {
          res.statusCode = 404;
          break;
        }
        if (files.containsKey(destination) &&
            req.headers.value('Overwrite') == 'F') {
          res.statusCode = 412;
          break;
        }
        res.statusCode = files.containsKey(destination) ? 204 : 201;
        files[destination] = files.remove(name)!;
      case 'DELETE':
        await req.drain<void>();
        if (failDeletes) {
          res.statusCode = 503;
          break;
        }
        res.statusCode = files.remove(name) == null ? 404 : 204;
      default:
        await req.drain<void>();
        res.statusCode = 405;
    }
    await res.close();
  }
}
