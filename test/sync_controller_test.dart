import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/sync/background_uploads.dart';
import 'package:quietake/vault/vault.dart' show Vault;
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_webdav_server.dart';

void main() {
  late Directory dir;
  late Vault vault;
  late FakeWebDavServer server;
  late SyncSettings settings;
  late SyncController controller;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final crypto = VaultCrypto(await SodiumSumoInit.init());
    dir = await Directory.systemTemp.createTemp('quietake-auto-sync');
    vault = Vault(
      crypto,
      crypto.generateMasterKey(),
      Directory('${dir.path}/vault')..createSync(),
    );
    server = await FakeWebDavServer.start();
    settings = SyncSettings(
      url: server.url.toString(),
      username: 'vaultapp',
      password: 'secret',
    );
    controller = SyncController(vault, loadSettings: () async => settings);
  });

  tearDown(() async {
    await controller.close();
    await server.close();
    vault.dispose();
    await dir.delete(recursive: true);
  });

  Future<File> capture(String name) async {
    final plain = File('${dir.path}/$name');
    await plain.writeAsBytes(Uint8List.fromList([255, 216, 255, 1]));
    final encrypted = await vault.ingestAs(plain, name);
    expect(await plain.exists(), isFalse);
    return encrypted;
  }

  test('disconnect reports busy during recovery and can be retried', () async {
    await settings.save();
    final entered = Completer<void>(), release = Completer<void>();
    final operation = controller.recoveryOperation((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    try {
      await expectLater(controller.disconnect(), throwsStateError);
      expect((await SyncSettings.load()).isConfigured, isTrue);
    } finally {
      release.complete();
      await operation;
    }
    await controller.disconnect();
    expect((await SyncSettings.load()).isConfigured, isFalse);
  });

  test(
    'session close waits for a recovery operation to release its key lifetime',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final operation = controller.recoveryOperation((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      var closed = false;
      final closing = controller.close().then((_) => closed = true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(closed, isFalse);
      release.complete();
      await operation;
      await closing;
      expect(closed, isTrue);
    },
  );

  test(
    'captures arriving during recovery receive a normal backup retry',
    () async {
      await controller.sync();
      final entered = Completer<void>(), release = Completer<void>();
      final operation = controller.recoveryOperation((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final file = await capture('during-recovery.jpg');
      await controller.sync();
      expect(server.files.containsKey('during-recovery.jpg.shtr'), isFalse);
      release.complete();
      await operation;
      await controller.sync();
      expect(
        server.files['during-recovery.jpg.shtr'],
        await file.readAsBytes(),
      );
    },
  );

  test(
    'uploads only completed encrypted captures and reports backup',
    () async {
      final file = await capture('a.jpg');
      await File('${vault.dir.path}/incomplete.shtr.part').writeAsBytes([1]);
      await controller.sync();
      expect(controller.state, SyncState.synced);
      expect(server.files.keys.toSet(), {'a.jpg.shtr', 'quietake.catalog'});
      expect(server.files['a.jpg.shtr'], await file.readAsBytes());
      expect(controller.label, 'Synced with NAS · not verified');
    },
  );

  test('a capture during upload queues a serialized second pass', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    server.beforeRequest = (request) async {
      if (request.method == 'PUT' && !started.isCompleted) {
        started.complete();
        await release.future;
      }
    };
    await capture('a.jpg');
    final first = controller.sync();
    await started.future;
    await capture('b.jpg');
    final next = controller.sync();
    expect(server.log.where((s) => s.startsWith('PROPFIND')).length, 1);
    release.complete();
    await Future.wait([first, next]);
    expect(server.files.keys.toSet(), {
      'a.jpg.shtr',
      'b.jpg.shtr',
      'quietake.catalog',
    });
    expect(controller.state, SyncState.synced);
  });

  test(
    'failed sync keeps capture and succeeds after settings recover',
    () async {
      final file = await capture('a.jpg');
      final correct = settings;
      settings = SyncSettings(
        url: correct.url,
        username: correct.username,
        password: 'wrong',
      );
      await controller.sync();
      expect(controller.state, SyncState.pending);
      expect(controller.label, 'NAS update pending');
      expect(await vault.readAll(file), [255, 216, 255, 1]);
      expect(server.files, isEmpty);
      settings = correct;
      await controller.sync();
      expect(controller.state, SyncState.synced);
      expect(server.files.length, 2);
    },
  );

  test('unconfigured backup makes no network request', () async {
    settings = const SyncSettings(url: '', username: '', password: '');
    await controller.sync();
    expect(controller.state, SyncState.unconfigured);
    expect(controller.label, 'On this device · backup off');
    expect(server.log, isEmpty);
  });

  test('new settings queued during a failed transfer are retried', () async {
    final correct = settings;
    settings = SyncSettings(
      url: correct.url,
      username: correct.username,
      password: 'wrong',
    );
    final started = Completer<void>();
    final release = Completer<void>();
    server.beforeRequest = (_) async {
      if (!started.isCompleted) {
        started.complete();
        await release.future;
      }
    };
    await capture('a.jpg');
    final first = controller.sync();
    await started.future;
    settings = correct;
    final next = controller.sync();
    release.complete();
    await Future.wait([first, next]);
    expect(controller.state, SyncState.synced);
    expect(server.files.length, 2);
  });

  test(
    'closing during settings load prevents subsequent network work',
    () async {
      await controller.close();
      final loading = Completer<SyncSettings>();
      controller = SyncController(vault, loadSettings: () => loading.future);
      final run = controller.sync();
      final close = controller.close();
      loading.complete(settings);
      await Future.wait([run, close]);
      await controller.sync();
      expect(server.log, isEmpty);
    },
  );

  test(
    'cancel during settings load leaves backup pending without requests',
    () async {
      await controller.close();
      final loading = Completer<SyncSettings>();
      controller = SyncController(vault, loadSettings: () => loading.future);
      final run = controller.sync();
      controller.cancel();
      loading.complete(settings);
      await run;
      expect(controller.state, SyncState.pending);
      expect(server.log, isEmpty);
    },
  );
  test('cancelling a queued check resets its status text', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    server.beforeRequest = (request) async {
      if (request.method == 'PROPFIND' && !started.isCompleted) {
        started.complete();
        await release.future;
      }
    };
    final first = controller.sync();
    await started.future;
    final check = controller.verify();
    expect(controller.isVerificationQueued, isTrue);
    expect(controller.verificationResult, 'Backup check queued…');
    controller.cancel();
    expect(controller.isVerificationQueued, isFalse);
    expect(controller.verificationResult, isNot('Backup check queued…'));
    release.complete();
    await Future.wait([first, check]);
  });

  test('cancel while idle leaves the state untouched', () async {
    await controller.sync();
    expect(controller.state, SyncState.synced);
    controller.cancel();
    expect(controller.state, SyncState.synced);
  });

  test(
    'a background scheduler failure after a finished pass stays synced',
    () async {
      await controller.close();
      settings = SyncSettings(
        url: settings.url,
        username: settings.username,
        password: settings.password,
        backgroundUploads: true,
      );
      controller = SyncController(
        vault,
        loadSettings: () async => settings,
        background: _FailingScheduler(),
      );
      await capture('a.jpg');
      await controller.sync();
      expect(server.files.keys, contains('a.jpg.shtr'));
      expect(controller.state, SyncState.synced);
    },
  );

  test('retry immediately after cancellation is not dropped', () async {
    await controller.close();
    final loading = Completer<SyncSettings>();
    var reads = 0;
    controller = SyncController(
      vault,
      loadSettings: () {
        return reads++ == 0 ? loading.future : Future.value(settings);
      },
    );
    await capture('a.jpg');
    final first = controller.sync();
    controller.cancel();
    final next = controller.sync();
    loading.complete(settings);
    await Future.wait([first, next]);
    expect(controller.state, SyncState.synced);
    expect(server.files.length, 2);
  });

  test('confirmed deletion schedules removal on the configured NAS', () async {
    final file = await capture('delete.jpg');
    await controller.sync();
    await controller.delete(file);
    await controller.sync();
    expect(await file.exists(), isFalse);
    expect(server.files.keys, ['quietake.catalog']);
    expect(controller.state, SyncState.synced);
    expect(controller.result, contains('0 on NAS'));
  });

  test('NAS failure keeps deletion pending until settings recover', () async {
    final file = await capture('delete.jpg');
    await controller.sync();
    final correct = settings;
    settings = SyncSettings(
      url: settings.url,
      username: settings.username,
      password: 'wrong',
    );
    await controller.delete(file);
    await controller.sync();
    expect(await file.exists(), isFalse);
    expect(controller.state, SyncState.pending);
    expect(controller.label, 'NAS update pending');
    expect(server.files, hasLength(2));
    settings = correct;
    await controller.sync();
    expect(controller.state, SyncState.synced);
    expect(server.files.keys, ['quietake.catalog']);
  });

  test(
    'deletion during upload queues a pass and never returns the capture',
    () async {
      final file = await capture('delete.jpg');
      final started = Completer<void>();
      final release = Completer<void>();
      server.beforeRequest = (request) async {
        if (request.method == 'PUT' && !started.isCompleted) {
          started.complete();
          await release.future;
        }
      };
      final first = controller.sync();
      await started.future;
      await controller.delete(file);
      release.complete();
      await first;
      expect(controller.state, SyncState.synced);
      expect(await vault.list(), isEmpty);
      expect(server.files.keys, ['quietake.catalog']);
    },
  );

  test('canceling sync never discards a confirmed deletion', () async {
    final file = await capture('delete.jpg');
    await controller.sync();
    await controller.close();
    final loaded = Completer<SyncSettings>();
    controller = SyncController(vault, loadSettings: () => loaded.future);
    await controller.delete(file);
    final pending = controller.sync();
    controller.cancel();
    loaded.complete(settings);
    await pending;
    expect(controller.state, SyncState.pending);
    expect(server.files, hasLength(2));
    expect(await file.exists(), isFalse);
    await controller.sync();
    expect(server.files.keys, ['quietake.catalog']);
  });
  test(
    'disconnect discards a stale settings load and queued automatic sync',
    () async {
      await controller.close();
      final loaded = Completer<SyncSettings>();
      controller = SyncController(vault, loadSettings: () => loaded.future);
      final captureFile = await capture('keep.jpg');
      final running = controller.sync();
      final disconnect = controller.disconnect();
      final queued = controller.sync();
      loaded.complete(settings);
      await Future.wait([running, disconnect, queued]);
      expect(controller.state, SyncState.unconfigured);
      expect(server.log, isEmpty);
      expect((await SyncSettings.load()).isConfigured, isFalse);
      expect(await vault.readAll(captureFile), [255, 216, 255, 1]);
    },
  );

  test('disconnect cancels active network work and retains deletion decisions on reconnect', () async {
    final keep = await capture('keep.jpg');
    final remove = await capture('remove.jpg');
    await controller.sync();
    final expectedKeep = await keep.readAsBytes();
    await controller.close();
    await vault.delete(remove);
    final deletions = await vault.deletedNames();
    final stalled = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final arrived = Completer<void>();
    final requests = <String>[];
    stalled.listen((request) {
      requests.add(request.method);
      if (!arrived.isCompleted) arrived.complete();
    });
    try {
      await SyncSettings(
        url: 'http://127.0.0.1:${stalled.port}/vault/',
        username: 'test',
        password: 'synthetic',
      ).save();
      controller = SyncController(vault);
      final running = controller.sync();
      await arrived.future;
      final disconnect = controller.disconnect();
      final newCapture = await capture('during.jpg');
      final queued = controller.sync();
      await Future.wait([disconnect, running, queued])
          .timeout(const Duration(seconds: 5));
      await controller.sync();
      expect(controller.state, SyncState.unconfigured);
      expect(requests, ['MKCOL']);
      expect(await keep.readAsBytes(), expectedKeep);
      expect(await newCapture.exists(), isTrue);
      expect(await vault.deletedNames(), deletions);
      expect(
        server.files,
        hasLength(3),
        reason: 'Disconnect must not delete NAS copies',
      );
      await settings.save();
      await controller.sync();
      expect(controller.state, SyncState.synced);
      expect(server.files.keys.toSet(), {
        'keep.jpg.shtr',
        'during.jpg.shtr',
        'quietake.catalog',
      });
      expect(await vault.deletedNames(), deletions);
      expect(await remove.exists(), isFalse);
    } finally {
      await stalled.close(force: true);
    }
  });
  test('verification is read-only, scoped to saved target and invalidated by later capture', () async {
    await capture('a.jpg');
    await controller.sync();
    server.log.clear();
    await controller.verify();
    expect(controller.verificationCurrent, isTrue);
    expect(controller.label, 'NAS backup verified');
    expect(controller.lastVerification!.media, 1);
    expect(
      server.log.every(
        (line) => line.startsWith('GET ') || line.startsWith('PROPFIND '),
      ),
      isTrue,
    );
    await capture('b.jpg');
    final next = controller.sync();
    expect(controller.verificationCurrent, isFalse);
    await next;
    expect(controller.label, contains('not verified'));
    expect(controller.lastVerification!.media, 1);
    await controller.verify();
    expect(controller.lastVerification!.media, 2);
    expect(controller.verificationCurrent, isTrue);
    final other = await FakeWebDavServer.start();
    try {
      settings = SyncSettings(
        url: other.url.toString(),
        username: other.username,
        password: other.password,
      );
      await controller.sync();
      expect(controller.lastVerification, isNull);
      expect(controller.verificationCurrent, isFalse);
    } finally {
      await other.close();
    }
  });

  test('capture during verification queues upload and makes checked snapshot stale', () async {
    await capture('a.jpg');
    await controller.sync();
    final started = Completer<void>();
    final release = Completer<void>();
    server.beforeRequest = (request) async {
      if (request.method == 'GET' &&
          request.uri.path.endsWith('a.jpg.shtr') &&
          !started.isCompleted) {
        started.complete();
        await release.future;
      }
    };
    final first = controller.verify();
    await started.future;
    final duplicate = controller.verify();
    await capture('b.jpg');
    final upload = controller.sync();
    release.complete();
    await Future.wait([first, duplicate, upload]);
    expect(controller.state, SyncState.synced);
    expect(controller.verificationCurrent, isFalse);
    expect(controller.lastVerification!.media, 1);
    expect(server.files.keys.toSet(), {
      'a.jpg.shtr',
      'b.jpg.shtr',
      'quietake.catalog',
    });
  });

  test(
    'cancelling queued verification leaves current upload running',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      server.beforeRequest = (request) async {
        if (request.method == 'PUT' && !started.isCompleted) {
          started.complete();
          await release.future;
        }
      };
      await capture('a.jpg');
      final uploading = controller.sync();
      await started.future;
      final check = controller.verify();
      expect(controller.isVerificationQueued, isTrue);
      controller.cancelVerification();
      release.complete();
      await Future.wait([uploading, check]);
      expect(controller.state, SyncState.synced);
      expect(controller.lastVerification, isNull);
      expect(server.files.keys.toSet(), {'a.jpg.shtr', 'quietake.catalog'});
      expect(server.log.where((line) => line.startsWith('GET ')), isEmpty);
    },
  );

  test('cancelling an active check stops network work and clears encrypted staging', () async {
    final file = await capture('a.jpg');
    final original = await file.readAsBytes();
    final stalled = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final arrived = Completer<void>();
    stalled.listen((request) {
      if (!arrived.isCompleted) arrived.complete();
    });
    settings = SyncSettings(
      url: 'http://127.0.0.1:${stalled.port}/vault/',
      username: 'test',
      password: 'synthetic',
    );
    try {
      final check = controller.verify();
      await arrived.future;
      expect(controller.isVerifying, isTrue);
      controller.cancelVerification();
      await check.timeout(const Duration(seconds: 5));
      expect(controller.state, SyncState.pending);
      expect(controller.verificationCurrent, isFalse);
      expect(controller.verificationResult, contains('cancelled'));
      expect(await file.readAsBytes(), original);
      expect((await vault.dir.list().toList()).whereType<Directory>(), isEmpty);
    } finally {
      await stalled.close(force: true);
    }
  });

  test('metadata edit while checking queues its encrypted backup and invalidates proof', () async {
    final file = await capture('a.jpg');
    await controller.sync();
    final started = Completer<void>();
    final release = Completer<void>();
    server.beforeRequest = (request) async {
      if (request.method == 'GET' &&
          request.uri.path.endsWith('a.jpg.shtr') &&
          !started.isCompleted) {
        started.complete();
        await release.future;
      }
    };
    final check = controller.verify();
    await started.future;
    await vault.catalog.renameItem(
      file.uri.pathSegments.last,
      'New private name',
    );
    final upload = controller.sync();
    release.complete();
    await Future.wait([check, upload]);
    expect(controller.verificationCurrent, isFalse);
    expect(
      server.files['quietake.catalog'],
      await vault.catalog.file.readAsBytes(),
    );
    await controller.verify();
    expect(controller.verificationCurrent, isTrue);
  });
}

/// Native scheduling that always fails after a successful foreground pass.
class _FailingScheduler extends BackgroundUploads {
  _FailingScheduler() : super(enabled: false);

  @override
  Future<void> configure(
    SyncSettings settings,
    Vault vault,
    String? proof,
    Set<String> confirmedMedia,
  ) async {
    throw PlatformException(code: 'background');
  }
}
