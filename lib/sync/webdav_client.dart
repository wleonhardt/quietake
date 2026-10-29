import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:math';

import 'package:xml/xml.dart';

import '../vault/file_name.dart';

/// One file on the WebDAV share.
class RemoteEntry {
  const RemoteEntry(this.name, this.size, {this.etag});

  final String name;
  final int size;

  /// As the server sent it; only a quoted strong tag is usable as a
  /// precondition (see [WebDavClient.putStaged]).
  final String? etag;
}

class WebDavException implements Exception {
  WebDavException(this.method, this.status, this.path);

  final String method;
  final int status;
  final String path;

  @override
  String toString() => 'WebDAV $method $path failed: HTTP $status';
}

/// Minimal WebDAV client: list one collection, PUT, GET, DELETE, MKCOL.
/// Basic auth over whatever scheme [base] uses; the NAS must be HTTPS.
class WebDavClient {
  WebDavClient({
    required Uri base,
    required this.username,
    required this.password,
    HttpClient? client,
    this.timeout = const Duration(minutes: 2),
  }) : base = base.path.endsWith('/')
           ? base
           : base.replace(path: '${base.path}/'),
       _client = client ?? HttpClient() {
    if (base.scheme != 'https' &&
        !(base.scheme == 'http' &&
            (base.host == '127.0.0.1' || base.host == 'localhost'))) {
      throw const FormatException('Use an HTTPS WebDAV folder URL');
    }
    if (base.host.isEmpty || base.userInfo.isNotEmpty) {
      throw const FormatException('Invalid WebDAV folder URL');
    }
    _client.connectionTimeout = timeout;
  }

  /// Collection URL, always with a trailing slash.
  final Uri base;
  final String username;
  final String password;
  final HttpClient _client;

  /// Maximum wait for a connection, response headers or progress on a body.
  final Duration timeout;

  String get _auth =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  Uri _url(String name) =>
      base.resolve(Uri.encodeComponent(checkedFileName(name)));

  Future<HttpClientRequest> _open(String method, Uri url) async {
    final req = await _client.openUrl(method, url).timeout(timeout);
    req.followRedirects = false;
    req.headers.set(HttpHeaders.authorizationHeader, _auth);
    return req;
  }

  Future<T> _wait<T>(Future<T> operation, HttpClientRequest request) =>
      operation.timeout(
        timeout,
        onTimeout: () {
          request.abort();
          throw TimeoutException('WebDAV request timed out', timeout);
        },
      );

  Future<void> _finish(
    String method,
    HttpClientResponse response,
    String path,
    List<int> accepted,
  ) async {
    try {
      var received = 0;
      await for (final chunk in response.timeout(timeout)) {
        received += chunk.length;
        if (received > 65536) {
          throw const FormatException('WebDAV control response exceeds limit');
        }
      }
    } catch (_) {
      _client.close(force: true);
      rethrow;
    }
    if (!accepted.contains(response.statusCode)) {
      throw WebDavException(method, response.statusCode, path);
    }
  }

  /// Files directly inside the collection (sub-collections are skipped).
  Future<List<RemoteEntry>> list({int? maxBytes}) async {
    final req = await _open('PROPFIND', base);
    req.headers
      ..set('Depth', '1')
      ..contentType = ContentType('application', 'xml', charset: 'utf-8');
    req.write(
      '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:resourcetype/><d:getcontentlength/><d:getetag/></d:prop></d:propfind>',
    );
    final res = await _wait(req.close(), req);
    if (res.statusCode != 207) {
      await _finish('PROPFIND', res, base.path, const []);
    }
    var received = 0;
    final body = await utf8.decodeStream(
      res.timeout(timeout).map((chunk) {
        received += chunk.length;
        if (maxBytes != null && received > maxBytes) {
          _client.close(force: true);
          throw const FormatException('Backup directory exceeds limit');
        }
        return chunk;
      }),
    );
    final doc = XmlDocument.parse(body);
    final out = <RemoteEntry>[];
    for (final r in doc.findAllElements('response', namespaceUri: 'DAV:')) {
      final href = r.getElement('href', namespaceUri: 'DAV:')!.innerText.trim();
      final isDir = r
          .findAllElements('resourcetype', namespaceUri: 'DAV:')
          .any((e) => e.getElement('collection', namespaceUri: 'DAV:') != null);
      if (isDir) continue;
      final name = checkedFileName(
        Uri.parse(href).pathSegments.where((s) => s.isNotEmpty).last,
      );
      final len = r.findAllElements('getcontentlength', namespaceUri: 'DAV:');
      final tag = r.findAllElements('getetag', namespaceUri: 'DAV:');
      // Some servers send an empty getcontentlength for files they cannot size.
      out.add(
        RemoteEntry(
          name,
          len.isEmpty ? 0 : int.tryParse(len.first.innerText.trim()) ?? 0,
          etag: tag.isEmpty ? null : tag.first.innerText.trim(),
        ),
      );
    }
    return out;
  }

  /// Creates the collection if missing. 405 means it already exists.
  Future<void> ensureCollection() async {
    final req = await _open('MKCOL', base);
    final res = await _wait(req.close(), req);
    await _finish('MKCOL', res, base.path, [201, 405]);
  }

  /// Uploads to a staging name, then finalizes with one atomic MOVE, so an
  /// interrupted transfer never leaves a truncated object under [name]
  /// (decision 039). Without [replace] the MOVE fails with 412 if [name]
  /// exists; with a strong [etag] it fails unless the destination still
  /// carries that tag. A weak or missing tag replaces unconditionally.
  Future<void> putStaged(
    String name,
    File file, {
    bool replace = false,
    String? etag,
  }) async {
    final random = Random.secure();
    final stage =
        '.quietake-upload-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    await put(stage, file);
    try {
      await move(
        stage,
        name,
        replace: replace,
        etag: etag != null && _strongTag(etag) ? etag : null,
      );
    } catch (_) {
      try {
        await delete(stage);
      } catch (_) {
        // The next pass removes leftover staging names by prefix.
      }
      rethrow;
    }
  }

  static const stagePrefix = '.quietake-upload-';

  static bool _strongTag(String etag) =>
      RegExp(r'^"[^"\r\n]*"$').hasMatch(etag) && etag.length <= 256;

  Future<void> put(String name, File file, {String? lease}) async {
    final req = await _open('PUT', _url(name));
    if (lease != null) req.headers.set('If', _condition(base, lease));
    req.contentLength = await file.length();
    req.headers.contentType = ContentType.binary;
    try {
      await for (final chunk in file.openRead().timeout(timeout)) {
        await _wait(req.addStream(Stream.value(chunk)), req);
      }
    } catch (_) {
      req.abort();
      rethrow;
    }
    final res = await _wait(req.close(), req);
    await _finish('PUT', res, name, [201, 204, 200]);
  }

  /// Downloads to [file] via a temp sibling so a dropped connection never
  /// leaves a half-written container behind.
  Future<void> get(
    String name,
    File file, {
    int? maxBytes,
    Future<void> Function(Stream<List<int>> bytes)? authenticate,
  }) async {
    final req = await _open('GET', _url(name));
    final res = await _wait(req.close(), req);
    if (res.statusCode != 200) await _finish('GET', res, name, const []);
    final tmp = File('${file.path}.part');
    final sink = tmp.openWrite();
    try {
      Stream<List<int>> body = res.timeout(timeout);
      if (maxBytes != null) {
        var received = 0;
        body = body.map((bytes) {
          received += bytes.length;
          if (received > maxBytes) {
            _client.close(force: true);
            throw const FormatException('Download exceeds size limit');
          }
          return bytes;
        });
      }
      if (authenticate == null) {
        await sink.addStream(body);
      } else {
        Stream<List<int>> copy() async* {
          await for (final bytes in body) {
            await sink.addStream(Stream.value(bytes));
            yield bytes;
          }
        }

        // HttpClientRequest.abort has no effect after response headers. Close
        // this operation-owned client before awaiting cancellation, which Dart
        // may otherwise satisfy by draining the entire hostile response body.
        late StreamSubscription<List<int>> upstream;
        var finished = false;
        final forwarded = StreamController<List<int>>(sync: true);
        forwarded.onListen = () {
          upstream = copy().listen(
            forwarded.add,
            onError: forwarded.addError,
            onDone: () {
              finished = true;
              unawaited(forwarded.close());
            },
          );
        };
        forwarded.onPause = () => upstream.pause();
        forwarded.onResume = () => upstream.resume();
        forwarded.onCancel = () {
          if (!finished) _client.close(force: true);
          return upstream.cancel();
        };
        await authenticate(forwarded.stream);
      }
      await sink.close();
      await tmp.rename(file.path);
    } catch (_) {
      _client.close(force: true);
      // addStream may already close the file after a source error.
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  Future<void> delete(String name, {String? lease}) async {
    final req = await _open('DELETE', _url(name));
    if (lease != null) req.headers.set('If', _condition(base, lease));
    final res = await _wait(req.close(), req);
    await _finish('DELETE', res, name, [204, 200, 404]);
  }

  /// Small recovery metadata, including a strong replacement precondition.
  Future<({List<int> bytes, String? etag})?> readSmall(
    String name,
    int limit,
  ) async {
    final req = await _open('GET', _url(name));
    try {
      final res = await _wait(req.close(), req);
      if (res.statusCode == 404) {
        await _finish('GET', res, name, [404]);
        return null;
      }
      if (res.statusCode != 200) await _finish('GET', res, name, const []);
      final bytes = <int>[];
      await for (final chunk in res.timeout(timeout)) {
        if (bytes.length + chunk.length > limit) {
          _client.close(force: true);
          throw const FormatException('Recovery file exceeds limit');
        }
        bytes.addAll(chunk);
      }
      return (bytes: bytes, etag: res.headers.value(HttpHeaders.etagHeader));
    } on WebDavException {
      // Status errors drained the body; the connection stays usable for UNLOCK.
      rethrow;
    } catch (_) {
      _client.close(force: true);
      rethrow;
    }
  }

  static bool _validLease(String value) =>
      value.length <= 512 &&
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:[^\s<>\[\]()]+$').hasMatch(value);

  String _condition(Uri resource, String? lease, {String? etag}) {
    if (lease != null && !_validLease(lease) ||
        etag != null && !_strongTag(etag) ||
        lease == null && etag == null) {
      throw const FormatException('Unsupported recovery precondition');
    }
    // One resource/list: token AND destination ETag. Separate tags are OR.
    final predicates = [
      if (lease != null) '<$lease>',
      if (etag != null) '[$etag]',
    ].join(' ');
    return '<$resource> ($predicates)';
  }

  Future<String> lockCollection() async {
    final req = await _open('LOCK', base);
    req.headers
      ..set('Depth', 'infinity')
      ..set('Timeout', 'Second-300')
      ..contentType = ContentType('application', 'xml', charset: 'utf-8');
    req.write(
      '<d:lockinfo xmlns:d="DAV:"><d:lockscope><d:exclusive/>'
      '</d:lockscope><d:locktype><d:write/></d:locktype></d:lockinfo>',
    );
    String? lease;
    try {
      final res = await _wait(req.close(), req);
      if (res.statusCode != 200) {
        throw WebDavException('LOCK', res.statusCode, base.path);
      }
      final header = res.headers.value('Lock-Token') ?? '';
      if (!header.startsWith('<') || !header.endsWith('>')) {
        throw const FormatException('Invalid recovery lease');
      }
      final token = header.substring(1, header.length - 1);
      if (!_validLease(token)) {
        throw const FormatException('Invalid recovery lease');
      }
      lease = token;
      final bytes = <int>[];
      await for (final chunk in res.timeout(timeout)) {
        if (bytes.length + chunk.length > 65536) {
          _client.close(force: true);
          throw const FormatException('Oversized recovery lease');
        }
        bytes.addAll(chunk);
      }
      final doc = XmlDocument.parse(utf8.decode(bytes));
      final active = doc
          .findAllElements('activelock', namespaceUri: 'DAV:')
          .single;
      String text(String name) =>
          active.getElement(name, namespaceUri: 'DAV:')!.innerText.trim();
      // RFC 2518 omits lockroot; RFC 4918 section 14.12 says SHOULD.
      // This is the direct, non-redirected LOCK response for base, not discovery.
      final root = active.getElement('lockroot', namespaceUri: 'DAV:');
      final expiry = RegExp(r'^Second-([1-9][0-9]{0,2})$')
          .firstMatch(text('timeout'));
      final seconds = int.tryParse(expiry?.group(1) ?? '');
      if (text('depth') != 'infinity' ||
          seconds == null ||
          seconds < 1 ||
          seconds > 300 ||
          active
                  .getElement('lockscope', namespaceUri: 'DAV:')
                  ?.getElement('exclusive', namespaceUri: 'DAV:') ==
              null ||
          active
                  .getElement('locktype', namespaceUri: 'DAV:')
                  ?.getElement('write', namespaceUri: 'DAV:') ==
              null ||
          text('locktoken') != lease ||
          root != null && Uri.parse(root.innerText.trim()) != base) {
        throw const FormatException(
          'Exclusive finite collection lease required',
        );
      }
      return lease;
    } catch (_) {
      req.abort();
      if (lease != null) {
        try {
          await unlockCollection(lease);
        } catch (_) {}
      }
      _client.close(force: true);
      rethrow;
    }
  }

  Future<void> unlockCollection(String lease) async {
    if (!_validLease(lease)) {
      throw const FormatException('Invalid recovery lease');
    }
    final req = await _open('UNLOCK', base);
    req.headers.set('Lock-Token', '<$lease>');
    final res = await _wait(req.close(), req);
    await _finish('UNLOCK', res, base.path, [204]);
  }

  Future<void> move(
    String source,
    String target, {
    required bool replace,
    String? lease,
    String? etag,
  }) async {
    final req = await _open('MOVE', _url(source));
    req.headers.set('Destination', _url(target).toString());
    req.headers.set('Overwrite', replace ? 'T' : 'F');
    if (lease != null || etag != null) {
      req.headers.set(
        'If',
        _condition(etag == null ? base : _url(target), lease, etag: etag),
      );
    }
    final res = await _wait(req.close(), req);
    await _finish('MOVE', res, target, [201, 204]);
  }

  Future<void> deleteConditional(
    String name, {
    required String etag,
    required String lease,
  }) async {
    final condition = _condition(_url(name), lease, etag: etag);
    final req = await _open('DELETE', _url(name));
    req.headers.set('If', condition);
    final res = await _wait(req.close(), req);
    await _finish('DELETE', res, name, [204, 200]);
  }

  void close() => _client.close(force: true);
}
