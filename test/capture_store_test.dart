import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quietake/camera/capture_store.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Vault vault;
  late CaptureStore captures;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('capture-recovery');
    final sodium = await SodiumSumoInit.init();
    vault = Vault(VaultCrypto(sodium), sodium.crypto.secretBox.keygen(), root);
    captures = CaptureStore(vault);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('quietake/captures'),
      null,
    );
    vault.dispose();
    await root.delete(recursive: true);
  });

  Future<({Directory work, File plain, File cipher, File out})> pending(
    String id,
  ) async {
    final work = await Directory('${captures.directory.path}/$id')
        .create(recursive: true);
    final plain = await File('${work.path}/capture.mp4')
        .writeAsBytes([1, 2, 3], flush: true);
    return (
      work: work,
      plain: plain,
      cipher: File('${plain.path}.shtr'),
      out: File('${root.path}/$id.mp4.shtr'),
    );
  }

  test(
    'capture snapshots multiple tags before asynchronous preparation',
    () async {
      final subject = await vault.catalog.createAlbum('Alex');
      final action = await vault.catalog.createAlbum('Running');
      final selected = {subject, action};
      final source = await File('${root.path}/camera.jpg')
          .writeAsBytes([1, 2, 3]);
      final saving = captures.ingest(
        source,
        extension: 'jpg',
        tagIds: selected,
      );
      selected.clear();
      final saved = await saving;
      await vault.catalog.load();
      expect(saved.albumApplied, isTrue);
      expect(
        vault.catalog.details(saved.container.uri.pathSegments.last).albums,
        {subject, action},
      );
      expect(await vault.readAll(saved.container), [1, 2, 3]);
      expect(await captures.directory.list(recursive: true).length, 0);
    },
  );

  test(
    'one stale tag rejects all metadata but still secures capture',
    () async {
      final subject = await vault.catalog.createAlbum('Alex');
      final action = await vault.catalog.createAlbum('Running');
      await vault.catalog.deleteAlbum(action);
      final source = await File('${root.path}/camera.jpg')
          .writeAsBytes([1, 2, 3]);
      final saved = await captures.ingest(
        source,
        extension: 'jpg',
        tagIds: {subject, action},
      );
      expect(saved.albumApplied, isFalse);
      expect(
        vault.catalog.details(saved.container.uri.pathSegments.last).albums,
        isEmpty,
      );
      expect(await vault.readAll(saved.container), [1, 2, 3]);
    },
  );

  test('new capture preserves timestamp and removes owned plaintext', () async {
    final source = await File('${root.path}/camera.jpg')
        .writeAsBytes([1, 2, 3]);
    final before = DateTime.now().toUtc();
    final saved = await captures.ingest(source, extension: 'jpg');
    final date = VaultItem(saved.container).capturedAt;
    expect(date, isNotNull);
    expect(date!.isBefore(before), isFalse);
    expect(await source.exists(), isFalse);
    expect(await captures.directory.list(recursive: true).length, 0);
  });

  test(
    'camera album is encrypted and survives reopen without media copies',
    () async {
      final id = await vault.catalog.createAlbum('Quiet weekend');
      final source = await File('${root.path}/camera.jpg')
          .writeAsBytes([1, 2, 3]);
      final saved = await captures.ingest(
        source,
        extension: 'jpg',
        albumId: id,
      );
      expect(saved.albumApplied, isTrue);
      final name = saved.container.uri.pathSegments.last;
      await vault.catalog.load();
      expect(vault.catalog.details(name).albums, {id});
      expect(await vault.readAll(saved.container), [1, 2, 3]);
      expect(await vault.list(), hasLength(1));
      expect(
        String.fromCharCodes(await vault.catalog.file.readAsBytes()),
        isNot(contains('Quiet weekend')),
      );
    },
  );

  test(
    'interruption after organization recovers the same album membership',
    () async {
      final id = await vault.catalog.createAlbum('Keep with capture');
      final action = await vault.catalog.createAlbum('Moving');
      final source = await File('${root.path}/camera.mp4')
          .writeAsBytes([1, 2, 3]);
      await expectLater(
        captures.ingest(
          source,
          extension: 'mp4',
          tagIds: {id, action},
          prepare: (_) async =>
              throw StateError('simulated process interruption'),
        ),
        throwsStateError,
      );
      expect(await vault.list(), isEmpty);
      final name = vault.catalog.items.keys.single;
      expect(vault.catalog.details(name).albums, {id, action});
      expect(await captures.recover(), (
        recovered: 1,
        pending: 0,
        unnormalized: 1,
      ));
      await vault.catalog.load();
      expect((await vault.list()).single.uri.pathSegments.last, name);
      expect(vault.catalog.details(name).albums, {id, action});
      expect(await captures.directory.list(recursive: true).length, 0);
    },
  );

  for (final corrupt in [false, true]) {
    test('album failure preserves secure media; corrupt=$corrupt', () async {
      final id = await vault.catalog.createAlbum('Removed');
      if (corrupt) {
        await vault.catalog.file.writeAsBytes([1, 2, 3]);
        await expectLater(vault.catalog.load(), throwsA(anything));
      } else {
        await vault.catalog.deleteAlbum(id);
      }
      final before = await vault.catalog.file.readAsBytes();
      final source = await File('${root.path}/camera.jpg')
          .writeAsBytes([1, 2, 3]);
      final saved = await captures.ingest(
        source,
        extension: 'jpg',
        albumId: id,
      );
      expect(saved.albumApplied, isFalse);
      expect(await vault.readAll(saved.container), [1, 2, 3]);
      expect(await vault.catalog.file.readAsBytes(), before);
      expect(await source.exists(), isFalse);
      expect(await captures.directory.list(recursive: true).length, 0);
    });
  }

  test(
    'retry encrypts pending original after interrupted encryption',
    () async {
      final item = await pending('2099-interrupted');
      await File('${item.cipher.path}.part').writeAsBytes(VaultCrypto.magic);
      expect(await vault.list(), isEmpty);
      final report = await captures.recover();
      expect(report, (recovered: 1, pending: 0, unnormalized: 1));
      expect(await vault.readAll(item.out), [1, 2, 3]);
      expect(await item.work.exists(), isFalse);
      expect(await captures.recover(), (
        recovered: 0,
        pending: 0,
        unnormalized: 0,
      ));
    },
  );

  test(
    'interrupted conversion promotes authenticated encrypted original',
    () async {
      final item = await pending('2099-converting');
      await vault.encryptFile(item.plain, item.cipher);
      final bytes = await item.cipher.readAsBytes();
      final report = await captures.recover();
      expect(report, (recovered: 1, pending: 0, unnormalized: 1));
      expect(await item.out.readAsBytes(), bytes);
      expect(await vault.readAll(item.out), [1, 2, 3]);
      expect(await item.work.exists(), isFalse);
    },
  );

  test('interrupted cleanup preserves published converted bytes', () async {
    final item = await pending('2099-published');
    final converted = await File('${root.path}/prepared').writeAsBytes([4, 5]);
    await vault.encryptFile(converted, item.out);
    final bytes = await item.out.readAsBytes();
    expect(await captures.recover(), (
      recovered: 0,
      pending: 0,
      unnormalized: 0,
    ));
    expect(await item.out.readAsBytes(), bytes);
    expect(await vault.readAll(item.out), [4, 5]);
    expect(await item.work.exists(), isFalse);
  });

  test(
    'one damaged published entry is repaired from its source beside others',
    () async {
      final broken = await pending('2099-broken');
      await broken.out.writeAsBytes(VaultCrypto.magic);
      final good = await pending('2099-good');
      expect(await captures.recover(), (
        recovered: 2,
        pending: 0,
        unnormalized: 2,
      ));
      expect(await vault.readAll(broken.out), [1, 2, 3]);
      expect(await vault.readAll(good.out), [1, 2, 3]);
    },
  );

  test(
    'a damaged committed container is replaced from the retained source',
    () async {
      final item = await pending('2099-damaged');
      await item.out.writeAsBytes([...VaultCrypto.magic, 0, 0, 0]);
      expect(await captures.recover(), (
        recovered: 1,
        pending: 0,
        unnormalized: 1,
      ));
      expect(await vault.readAll(item.out), [1, 2, 3]);
      expect(await item.work.exists(), isFalse);
    },
  );

  test('a damaged container with no retained source stays pending', () async {
    final item = await pending('2099-lost');
    await item.plain.delete();
    await item.out.writeAsBytes([...VaultCrypto.magic, 0, 0, 0]);
    expect(await captures.recover(), (
      recovered: 0,
      pending: 1,
      unnormalized: 0,
    ));
    expect(await item.out.exists(), isTrue, reason: 'damaged bytes are kept');
  });

  test('local confirmed deletion cannot be undone by pending replay', () async {
    final item = await pending('2099-deleted');
    await vault.encryptFile(item.plain, item.out);
    await vault.delete(item.out);
    expect(await captures.recover(), (
      recovered: 0,
      pending: 0,
      unnormalized: 0,
    ));
    expect(await vault.list(), isEmpty);
    expect(await item.work.exists(), isFalse);
  });

  test(
    'partial encrypted original is not trusted; intact source is retried',
    () async {
      final item = await pending('2099-partial');
      await item.cipher.writeAsBytes(VaultCrypto.magic);
      expect(await captures.recover(), (
        recovered: 1,
        pending: 0,
        unnormalized: 1,
      ));
      expect(await vault.readAll(item.out), [1, 2, 3]);
    },
  );
  test(
    'orphan CameraX handoff is recovered without reading unrelated cache',
    () async {
      final cache = await Directory('${root.path}/cache').create();
      final orphan = await File('${cache.path}/REC123456.mp4')
          .writeAsBytes([1, 2, 3]);
      final other = await File('${cache.path}/import.mp4').writeAsBytes([4, 5]);
      final subdir = await Directory('${cache.path}/other').create();
      final nested = await File('${subdir.path}/REC987.mp4').writeAsBytes([6]);
      final prepared = <String>[];
      expect(
        await captures.recover(
          cameraCache: cache,
          prepare: (plain) async {
            prepared.add(plain.path);
            return File('${root.path}/converted').writeAsBytes([7, 8, 9]);
          },
        ),
        (recovered: 1, pending: 0, unnormalized: 0),
      );
      expect(prepared, hasLength(1));
      expect(prepared.single, startsWith(captures.directory.path));
      expect(await orphan.exists(), isFalse);
      expect(await other.readAsBytes(), [4, 5]);
      expect(await nested.readAsBytes(), [6]);
      expect(await vault.readAll((await vault.list()).single), [7, 8, 9]);
    },
  );

  test(
    'orphan recovery keeps the original and warns when conversion fails',
    () async {
      final cache = await Directory('${root.path}/cache').create();
      await File('${cache.path}/REC1.mp4').writeAsBytes([1, 2, 3]);
      expect(
        await captures.recover(
          cameraCache: cache,
          prepare: (_) async =>
              throw const FormatException('No prepared video'),
        ),
        (recovered: 1, pending: 0, unnormalized: 1),
      );
      expect(await vault.readAll((await vault.list()).single), [1, 2, 3]);
    },
  );

  test(
    'iOS protection failure never moves plaintext into backed-up documents',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('quietake/captures'),
        (_) async => false,
      );
      final source = await File('${root.path}/camera.mp4')
          .writeAsBytes([1, 2, 3]);
      await expectLater(
        captures.ingest(source, extension: 'mp4'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
      expect(await captures.directory.list(recursive: true).length, 0);
      expect(await vault.list(), isEmpty);
    },
  );
}
