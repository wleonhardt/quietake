import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/share_bundle.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/share_media.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/exif_fixture.dart';
import '../test_support/png_fixture.dart';

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

  test(
    'a passphrase shares one bundle with neutral names and no plain copies',
    () async {
      final second = VaultItem(
        await vault.ingestAs(
          await File('${root.path}/b.mp4').writeAsBytes([1, 2, 3]),
          'second.mp4',
        ),
      );
      late File bundleCopy;
      var shared = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shared++;
        final args = call.arguments as Map;
        final file = File((args['paths'] as List).single as String);
        expect(file.path, endsWith('.quietake-share'));
        expect(args['mimeTypes'], ['application/octet-stream']);
        // Nothing but the bundle may be in the folder handed to the chooser.
        expect(file.parent.listSync().map((e) => e.path), [file.path]);
        bundleCopy = await file.copy('${root.path}/copy.quietake-share');
        return '';
      });
      await shareMediaCopies(
        vault,
        [item, second],
        origin: origin,
        passphrase: 'correct horse battery staple',
        isActive: () => true,
      );
      expect(shared, 1);
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
      final out = await Directory('${root.path}/opened').create();
      final names = await ShareBundle(vault.crypto.sodium)
          .extract(bundleCopy, 'correct horse battery staple', out);
      expect(names, ['video-01.mp4', 'video-02.mp4']);
      expect(await File('${out.path}/video-01.mp4').readAsBytes(), original);
      expect(await File('${out.path}/video-02.mp4').readAsBytes(), [1, 2, 3]);
      await expectLater(
        ShareBundle(vault.crypto.sodium).extract(
          bundleCopy,
          'wrong passphrase wrong',
          await Directory('${root.path}/nope').create(),
        ),
        throwsA(isA<ShareBundleException>()),
      );
    },
  );

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
    'redacted photos share as a metadata-free PNG; others are untouched',
    () async {
      final png = await gradientPng();
      final photo = VaultItem(
        await vault.ingestAs(
          await File('${root.path}/g.png').writeAsBytes(png),
          'g.png',
        ),
      );
      final gps = VaultItem(
        await vault.ingestAs(
          await File('${root.path}/h.jpg').writeAsBytes(jpegWithGps()),
          'h.jpg',
        ),
      );
      final names = <String>[];
      final mimes = <dynamic>[];
      final sent = <Uint8List>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        mimes.addAll(args['mimeTypes'] as List);
        for (final path in args['paths'] as List) {
          names.add((path as String).split('/').last);
          sent.add(await File(path).readAsBytes());
        }
        return '';
      });
      await shareMediaCopies(
        vault,
        [photo, gps],
        origin: origin,
        redactions: {
          photo.name: [const Rect.fromLTRB(.25, .25, .75, .75)],
        },
        isActive: () => true,
      );
      expect(mimes, ['image/png', 'image/jpeg']);
      expect(names[0], matches(RegExp(r'^photo-[0-9a-f]{32}\.png$')));
      expect(sent[0].sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(sent[0], isNot(png));
      // The other photo only had its metadata reduced, still a JPEG.
      expect(names[1], endsWith('.jpg'));
      expect(sent[1].sublist(0, 2), [0xff, 0xd8]);
      // The vault original is unchanged.
      expect(await vault.readAll(photo.file), png);
    },
  );

  test(
    'a GPS JPEG that is redacted becomes a PNG even if metadata is kept',
    () async {
      final jpeg = jpegWithGps();
      final photo = VaultItem(
        await vault.ingestAs(
          await File('${root.path}/r.jpg').writeAsBytes(jpeg),
          'r.jpg',
        ),
      );
      final sent = <Uint8List>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        for (final path in args['paths'] as List) {
          sent.add(await File(path as String).readAsBytes());
        }
        return '';
      });
      await shareMediaCopies(
        vault,
        [photo],
        origin: origin,
        stripLocation: false,
        redactions: {
          photo.name: [const Rect.fromLTRB(0, 0, .5, .5)],
        },
        isActive: () => true,
      );
      expect(sent.single.sublist(0, 4), [137, 80, 78, 71]);
    },
  );

  test(
    'photo copies keep only orientation unless the caller keeps everything',
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
      final copy = Uint8List.fromList(sent.single);
      expect(copy.length, lessThan(jpegWithGps().length - 40));
      // The rebuilt EXIF segment holds one entry: orientation 6.
      expect(ByteData.sublistView(copy).getUint16(12 + 8), 1);
      expect(ByteData.sublistView(copy).getUint16(12 + 10), 0x0112);
      expect(ByteData.sublistView(copy).getUint16(12 + 18), 6);
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
    'unsafe metadata aborts the entire batch and clears prepared copies',
    () async {
      final malformed = jpegWithGps();
      ByteData.sublistView(malformed).setUint32(12 + 4, 5000, Endian.little);
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
