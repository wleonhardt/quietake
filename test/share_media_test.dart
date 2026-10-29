import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/share_media.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/exif_fixture.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Vault vault;
  late VaultItem item;
  final original = List<int>.generate(1024 * 1024 + 17, (i) => i % 251);
  const origin = Rect.fromLTWH(10, 10, 48, 48);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quietake-share-test');
    final sodium = await SodiumSumoInit.init();
    vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      await Directory('${root.path}/vault').create(),
    );
    final plain = await File('${root.path}/input.mp4').writeAsBytes(original);
    item = VaultItem(await vault.ingestAs(plain, 'test.mp4'));
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      paths,
      (_) async => root.path,
    );
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
    vault.dispose();
    await root.delete(recursive: true);
  });

  test('normal media and correct MIME reach sharing; both temporary copies are removed', () async {
    var calls = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls++;
      final args = call.arguments as Map;
      expect(args['mimeTypes'], ['video/mp4']);
      final file = File((args['paths'] as List).single as String);
      expect(
        file.uri.pathSegments.last,
        matches(RegExp(r'^video-[0-9a-f]{32}\.mp4$')),
      );
      expect(await file.readAsBytes(), original);
      final plugin = await Directory('${root.path}/share_plus').create();
      await file.copy('${plugin.path}/${file.uri.pathSegments.last}');
      return ''; // Native chooser dismissed.
    });
    await shareMedia(vault, item, origin: origin, isActive: () => true);
    expect(calls, 1);
    expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
    expect(await Directory('${root.path}/share_plus').exists(), isFalse);
    expect(await vault.list(), hasLength(1));
    expect(await vault.readAll(item.file), original);
  });

  test('leaving the viewer during export prevents the share sheet', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      fail('A closed or locked viewer must not share');
    });
    await shareMedia(vault, item, origin: origin, isActive: () => false);
    expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
  });

  test(
    'decryption failure never opens sharing and removes partial plaintext',
    () async {
      await item.file.writeAsBytes([0, 1, 2]);
      await expectLater(
        shareMedia(vault, item, origin: origin, isActive: () => true),
        throwsA(isA<SharePreparationException>()),
      );
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
    },
  );

  test(
    'native failure cleans up and does not block the next attempt',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw PlatformException(code: 'failed');
      });
      await expectLater(
        shareMedia(vault, item, origin: origin, isActive: () => true),
        throwsA(isA<PlatformException>()),
      );
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => '',
      );
      await shareMedia(vault, item, origin: origin, isActive: () => true);
    },
  );
  test('recipient retains access until app returns; overlapping exports are blocked', () async {
    final chosen = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      chosen.complete();
      return 'test.recipient';
    });
    final pending = shareMedia(
      vault,
      item,
      origin: origin,
      isActive: () => true,
    );
    await chosen.future;
    await pumpEventQueue();
    expect(await Directory('${root.path}/quietake-share').exists(), isTrue);
    await expectLater(
      shareMedia(vault, item, origin: origin, isActive: () => true),
      throwsStateError,
    );
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await pending;
    expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
  });

  test(
    'startup cleanup removes interrupted exports without touching the vault',
    () async {
      for (final name in ['quietake-share', 'share_plus']) {
        final directory = await Directory('${root.path}/$name').create();
        await File('${directory.path}/interrupted.jpg').writeAsBytes([1, 2, 3]);
      }
      await clearShareFiles();
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
      expect(await Directory('${root.path}/share_plus').exists(), isFalse);
      expect(await vault.list(), hasLength(1));
    },
  );
  test('each export has a fresh filename so old URI grants cannot read a later share', () async {
    final names = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final args = call.arguments as Map;
      names.add((args['paths'] as List).single as String);
      return '';
    });
    await shareMedia(vault, item, origin: origin, isActive: () => true);
    await shareMedia(vault, item, origin: origin, isActive: () => true);
    expect(names.toSet(), hasLength(2));
  });
  test('mixed batch snapshots selection, preserves MIME, reports progress and cleans copies', () async {
    final selected = <VaultItem>[item];
    for (final extension in ['jpg', 'png']) {
      final plain = await File('${root.path}/input.$extension')
          .writeAsBytes([1, 2, 3]);
      selected.add(VaultItem(await vault.ingestAs(plain, 'test.$extension')));
    }
    final progress = <int>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final args = call.arguments as Map;
      expect(args['mimeTypes'], ['video/mp4', 'image/jpeg', 'image/png']);
      final files = (args['paths'] as List).cast<String>();
      expect(files.toSet(), hasLength(3));
      expect(await File(files[0]).readAsBytes(), original);
      expect(await File(files[1]).readAsBytes(), [1, 2, 3]);
      expect(await File(files[2]).readAsBytes(), [1, 2, 3]);
      return '';
    });
    await shareMediaCopies(
      vault,
      selected,
      origin: origin,
      isActive: () => true,
      onProgress: (done, total) {
        expect(total, 3);
        progress.add(done);
        selected.clear();
      },
    );
    expect(progress, [0, 1, 2, 3]);
    expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
    expect(await vault.list(), hasLength(3));
  });

  test('empty and over-count selections fail before preparation', () async {
    for (final selected in [<VaultItem>[], List.filled(11, item)]) {
      await expectLater(
        shareMediaCopies(vault, selected, origin: origin, isActive: () => true),
        throwsA(isA<SharePreparationException>()),
      );
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
    }
  });

  test(
    'batch byte bound is checked before decrypting or making copies',
    () async {
      final large = await item.file.copy('${vault.dir.path}/large.mp4.shtr');
      const plainBytes = maxShareBatchBytes + 1;
      final handle = await large.open(mode: FileMode.append);
      await handle.truncate(
        vault.crypto.headerLength +
            plainBytes +
            (plainBytes ~/ VaultCrypto.defaultChunkSize + 1) * 17,
      );
      await handle.close();
      await expectLater(
        shareMediaCopies(
          vault,
          [item, VaultItem(large)],
          origin: origin,
          isActive: () => true,
        ),
        throwsA(
          isA<SharePreparationException>().having(
            (e) => e.message,
            'limit',
            contains('256 MiB'),
          ),
        ),
      );
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
    },
  );

  test(
    'damaged last item prevents chooser and cleans already prepared files',
    () async {
      final broken = await item.file.copy('${vault.dir.path}/broken.mp4.shtr');
      final bytes = await broken.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await broken.writeAsBytes(bytes);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => fail('Partial batch must not be sent'),
      );
      await expectLater(
        shareMediaCopies(
          vault,
          [item, VaultItem(broken)],
          origin: origin,
          isActive: () => true,
        ),
        throwsA(
          isA<SharePreparationException>().having(
            (e) => e.item!.name,
            'failed item',
            'broken.mp4.shtr',
          ),
        ),
      );
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
      expect(await vault.readAll(item.file), original);
    },
  );

  test(
    'cancellation during streaming prevents chooser and removes partial output',
    () async {
      var checks = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => fail('Cancelled export must not be sent'),
      );
      await shareMediaCopies(
        vault,
        [item, item],
        origin: origin,
        isActive: () => ++checks < 4,
      );
      expect(checks, 4);
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
      // The unlinked plaintext copy must not stay readable through a handle.
      expect(_openHandles(), 0);
    },
  );

  test(
    'photo copies lose their GPS directory unless the caller keeps it',
    () async {
      final photo = VaultItem(
        await vault.ingestAs(
          await File('${root.path}/gps.jpg').writeAsBytes(jpegWithGps()),
          'gps.jpg',
        ),
      );
      final sent = <List<int>>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        final path = (args['paths'] as List).single as String;
        sent.add(await File(path).readAsBytes());
        return ''; // Native chooser dismissed.
      });
      await shareMediaCopies(
        vault,
        [photo],
        origin: origin,
        isActive: () => true,
      );
      expect(gpsEntryCount(Uint8List.fromList(sent.single)), 0);
      expect(sent.single.sublist(12 + 38, 12 + 92), everyElement(0));
      expect(sent.single.length, jpegWithGps().length);
      await shareMediaCopies(
        vault,
        [photo],
        origin: origin,
        isActive: () => true,
        stripLocation: false,
      );
      expect(gpsEntryCount(Uint8List.fromList(sent.last)), 2);
      expect(await vault.readAll(photo.file), jpegWithGps());
    },
  );

  test(
    'unsafe GPS metadata aborts the entire batch and clears prepared copies',
    () async {
      final malformed = jpegWithGps();
      ByteData.sublistView(malformed).setUint32(12 + 60, 8, Endian.little);
      final photo = VaultItem(
        await vault.ingestAs(
          await File('${root.path}/unsafe.jpg').writeAsBytes(malformed),
          'unsafe.jpg',
        ),
      );
      final original = await photo.file.readAsBytes();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        fail('Unsafe metadata must not reach the chooser');
      });
      await expectLater(
        shareMediaCopies(
          vault,
          [item, photo],
          origin: origin,
          isActive: () => true,
        ),
        throwsA(isA<SharePreparationException>()),
      );
      expect(await photo.file.readAsBytes(), original);
      expect(await vault.readAll(photo.file), malformed);
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
    },
  );

  test('missing item identifies failure without opening chooser', () async {
    await item.file.delete();
    await expectLater(
      shareMediaCopies(vault, [item], origin: origin, isActive: () => true),
      throwsA(
        isA<SharePreparationException>().having(
          (e) => e.item,
          'failed item',
          item,
        ),
      ),
    );
    expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
  });

  test(
    'single video larger than batch bound still streams to the chooser',
    () async {
      const total = 257 * 1024 * 1024;
      final large = File('${vault.dir.path}/large.mp4.shtr');
      Stream<List<int>> source() async* {
        final block = Uint8List(1024 * 1024);
        for (var i = 0; i < 257; i++) {
          yield block;
        }
      }

      final sink = large.openWrite();
      await sink.addStream(
        vault.crypto.encrypt(source(), vault.masterKeyForTests),
      );
      await sink.close();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        expect(
          await File((args['paths'] as List).single as String).length(),
          total,
        );
        expect(args['mimeTypes'], ['video/mp4']);
        return '';
      });
      await shareMedia(
        vault,
        VaultItem(large),
        origin: origin,
        isActive: () => true,
      );
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
    },
  );
}

/// Open handles under the share directory, from lsof when available.
int _openHandles() {
  final result = Process.runSync('lsof', ['-p', '$pid']);
  if (result.exitCode != 0) return 0;
  return (result.stdout as String)
      .split('\n')
      .where((line) => line.contains('quietake-share'))
      .length;
}
