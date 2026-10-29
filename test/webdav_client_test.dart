import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/sync/webdav_client.dart';

import '../test_support/fake_webdav_server.dart';

class _PacedFile implements File {
  _PacedFile(this.bytes, this.delay);
  final List<int> bytes;
  final Duration delay;
  @override
  Future<int> length() async => bytes.length;
  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    for (final byte in bytes) {
      await Future<void>.delayed(delay);
      yield [byte];
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final root in [
    null,
    '<d:lockroot/>',
    '<d:lockroot><d:href>http://other.invalid/</d:href></d:lockroot>',
  ]) {
    test(
      'LOCK accepts omitted legacy root but rejects explicit wrong root $root',
      () async {
        final server = await FakeWebDavServer.start();
        server.collectionExists = true;
        server.respond = (request) async {
          if (request.method != 'LOCK') return false;
          await request.drain<void>();
          server.lease = 'urn:uuid:synthetic-legacy';
          request.response.headers.set('Lock-Token', '<${server.lease}>');
          request.response.write(
            '<d:prop xmlns:d="DAV:"><d:lockdiscovery><d:activelock>'
            '<d:lockscope><d:exclusive/></d:lockscope><d:locktype><d:write/></d:locktype>'
            '<d:depth>infinity</d:depth><d:timeout>Second-300</d:timeout>'
            '<d:locktoken><d:href>${server.lease}</d:href></d:locktoken>'
            '${root ?? ''}</d:activelock></d:lockdiscovery></d:prop>',
          );
          await request.response.close();
          return true;
        };
        final client = WebDavClient(
          base: server.url,
          username: server.username,
          password: server.password,
        );
        try {
          if (root == null) {
            final token = await client.lockCollection();
            expect(token, server.lease);
            await client.unlockCollection(token);
          } else {
            await expectLater(client.lockCollection(), throwsFormatException);
          }
          expect(server.lease, isNull);
        } finally {
          client.close();
          await server.close();
        }
      },
    );
  }
  for (final method in [
    'MKCOL',
    'PUT',
    'DELETE',
    'MOVE',
    'conditional DELETE',
    'missing GET',
  ]) {
    for (final error in [false, true]) {
      test(
        '$method rejects unbounded ${error ? 'error' : 'control'} response body',
        () async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final finished = Completer<void>();
          var sent = 0;
          server.listen((request) async {
            await request.drain<void>();
            request.response.statusCode = error
                ? 500
                : method == 'missing GET'
                ? 404
                : method.contains('DELETE')
                ? 200
                : 201;
            try {
              for (var i = 0; i < 256; i++) {
                request.response.add(List<int>.filled(16384, 0));
                await request.response.flush().timeout(
                  const Duration(seconds: 1),
                );
                sent += 16384;
                await Future<void>.delayed(const Duration(milliseconds: 2));
              }
            } catch (_) {
              // The rejected body may close before the producer finishes.
            } finally {
              try {
                await request.response.close().timeout(
                  const Duration(seconds: 1),
                );
              } catch (_) {}
              finished.complete();
            }
          });
          final client = WebDavClient(
            base: Uri.parse('http://127.0.0.1:${server.port}/vault/'),
            username: 'u',
            password: 'p',
          );
          try {
            final Future<Object?> operation;
            switch (method) {
              case 'MKCOL':
                operation = client.ensureCollection();
              case 'PUT':
                operation = client.put('stage', _PacedFile([1], Duration.zero));
              case 'DELETE':
                operation = client.delete('stage');
              case 'MOVE':
                operation = client.move(
                  'stage',
                  'box',
                  replace: false,
                  lease: 'urn:uuid:test',
                );
              case 'conditional DELETE':
                operation = client.deleteConditional(
                  'box',
                  etag: '"old"',
                  lease: 'urn:uuid:test',
                );
              default:
                operation = client.readSmall('box', 4096);
            }
            await expectLater(operation, throwsA(anything));
            expect(
              sent,
              lessThan(1024 * 1024),
              reason:
                  'Unused response bodies must not be drained without a bound',
            );
          } finally {
            client.close();
            await finished.future.timeout(const Duration(seconds: 5));
            await server.close(force: true);
          }
        },
      );
    }
  }

  test('credentials require HTTPS except loopback test servers', () {
    expect(
      () => WebDavClient(
        base: Uri.parse('http://nas.local/vault/'),
        username: 'u',
        password: 'p',
      ),
      throwsFormatException,
    );
  });

  test('stalled response headers time out', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((_) {});
    final client = WebDavClient(
      base: Uri.parse('http://127.0.0.1:${server.port}/vault/'),
      username: 'u',
      password: 'p',
      timeout: const Duration(milliseconds: 100),
    );
    try {
      await expectLater(client.list(), throwsA(isA<TimeoutException>()));
    } finally {
      client.close();
      await server.close(force: true);
    }
  });

  test(
    'stalled download removes staging file and keeps old destination',
    () async {
      final dir = await Directory.systemTemp.createTemp('quietake-dav');
      final file = File('${dir.path}/clip.shtr')..writeAsBytesSync([9]);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        req.response.contentLength = 50;
        req.response.add([1, 2, 3]);
        await req.response.flush();
      });
      final client = WebDavClient(
        base: Uri.parse('http://127.0.0.1:${server.port}/vault/'),
        username: 'u',
        password: 'p',
        timeout: const Duration(milliseconds: 100),
      );
      try {
        await expectLater(
          client.get('clip.shtr', file),
          throwsA(isA<TimeoutException>()),
        );
        expect(file.readAsBytesSync(), [9]);
        expect(File('${file.path}.part').existsSync(), isFalse);
      } finally {
        client.close();
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    },
  );

  test('progressing upload can exceed the inactivity budget overall', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <int>[];
    server.listen((request) async {
      try {
        await for (final bytes in request) {
          received.addAll(bytes);
        }
        request.response.statusCode = HttpStatus.created;
        await request.response.close();
      } on HttpException {
        // The old total deadline aborts this request during the regression.
      }
    });
    final client = WebDavClient(
      base: Uri.parse('http://127.0.0.1:${server.port}/vault/'),
      username: 'u',
      password: 'p',
      timeout: const Duration(milliseconds: 200),
    );
    try {
      await client.put(
        'clip.shtr',
        _PacedFile([1, 2, 3, 4, 5, 6], const Duration(milliseconds: 70)),
      );
      expect(received, [1, 2, 3, 4, 5, 6]);
    } finally {
      client.close();
      await server.close(force: true);
    }
  });

  test('stalled upload source still times out', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((_) {});
    final client = WebDavClient(
      base: Uri.parse('http://127.0.0.1:${server.port}/vault/'),
      username: 'u',
      password: 'p',
      timeout: const Duration(milliseconds: 100),
    );
    try {
      await expectLater(
        client.put(
          'clip.shtr',
          _PacedFile([1], const Duration(milliseconds: 350)),
        ),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      client.close();
      await server.close(force: true);
    }
  });

  test('closing cancels an active request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final arrived = Completer<void>();
    server.listen((_) {
      arrived.complete();
    });
    final client = WebDavClient(
      base: Uri.parse('http://127.0.0.1:${server.port}/vault/'),
      username: 'u',
      password: 'p',
    );
    final pending = expectLater(client.list(), throwsA(isA<HttpException>()));
    await arrived.future;
    client.close();
    await pending;
    await server.close(force: true);
  });

  test('an empty getcontentlength lists the file with size 0', () async {
    final server = await FakeWebDavServer.start();
    final dav = WebDavClient(
      base: server.url,
      username: server.username,
      password: server.password,
    );
    try {
      server.collectionExists = true;
      server.files['a.jpg.shtr'] = [1, 2, 3];
      server.emptyContentLength = true;
      final entries = await dav.list();
      expect(entries.single.name, 'a.jpg.shtr');
      expect(entries.single.size, 0);
    } finally {
      dav.close();
      await server.close();
    }
  });
}
