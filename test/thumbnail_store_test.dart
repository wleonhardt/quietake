import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/preview.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const channel = MethodChannel('quietake/previews');
  late Directory dir;
  late Vault vault;
  late MediaServer server;
  late Uint8List jpg;
  var encodes = 0;
  var videos = 0;

  /// Runs [body] on a fresh vault with the platform preview channel faked.
  Future<void> withVault(
    WidgetTester tester,
    Future<void> Function() body, {
    bool platformEncodes = true,
  }) async {
    encodes = 0;
    videos = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'video') {
        videos++;
        return {'bytes': jpg, 'durationMs': 65000};
      }
      if (!platformEncodes) throw MissingPluginException();
      encodes++;
      return jpg;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-thumbs');
      jpg = await File('test_fixtures/tiny.jpg').readAsBytes();
      vault = Vault(VaultCrypto(sodium), sodium.crypto.secretBox.keygen(), dir);
      server = await MediaServer.start(vault);
      try {
        await body();
      } finally {
        await server.close();
        await dir.delete(recursive: true);
      }
    });
  }

  Future<File> capture(String name) async =>
      vault.ingestAs(await File('${dir.path}/input').writeAsBytes(jpg), name);
  File thumbnailOf(File container) =>
      File('${dir.path}/.thumbs/${container.uri.pathSegments.last}.thumb');

  testWidgets('a photo preview is stored encrypted and then served alone', (
    tester,
  ) async {
    await withVault(tester, () async {
      final file = await capture('2026-10-27T12-00-00.000Z.jpg');
      final item = VaultItem(file);
      final first = await loadPreview(vault, server, item);
      expect(encodes, 1);
      final stored = thumbnailOf(file);
      // On disk it is a container, not a picture.
      final onDisk = await stored.readAsBytes();
      expect(onDisk.sublist(0, 2), isNot([0xff, 0xd8]));
      expect(onDisk.sublist(0, 4), (await file.readAsBytes()).sublist(0, 4));
      final plain = (await vault.readThumbnail(file))!;
      expect(plain[0], 1);
      expect(plain.sublist(1, 5), [255, 255, 255, 255]);
      expect(plain.sublist(5), jpg);
      // The library still lists one capture.
      expect(await vault.list(), hasLength(1));

      // A damaged thumbnail is built again from the capture.
      await stored.writeAsBytes([1, 2, 3]);
      (await loadPreview(vault, server, item)).image.dispose();
      expect(encodes, 2);
      expect((await vault.readThumbnail(file))!.sublist(5), jpg);

      // From now on the capture itself is not read.
      await file.writeAsBytes([1, 2, 3]);
      final again = await loadPreview(vault, server, item);
      expect(encodes, 2);
      expect(again.image.width, first.image.width);
      expect(again.duration, isNull);
      first.image.dispose();
      again.image.dispose();

      // Deleting the capture deletes its thumbnail.
      await vault.delete(file);
      expect(await stored.exists(), isFalse);
    });
  });

  testWidgets('a video preview keeps its duration without another frame grab', (
    tester,
  ) async {
    await withVault(tester, () async {
      final item = VaultItem(await capture('2026-10-27T12-00-00.000Z.mp4'));
      final first = await loadPreview(vault, server, item);
      final again = await loadPreview(vault, server, item);
      expect(videos, 1);
      expect(encodes, 0);
      expect(first.duration, const Duration(seconds: 65));
      expect(again.duration, const Duration(seconds: 65));
      first.image.dispose();
      again.image.dispose();
    });
  });

  testWidgets(
    'without a platform encoder the preview shows and nothing is stored',
    (tester) async {
      await withVault(tester, platformEncodes: false, () async {
        final file = await capture('2026-10-27T12-00-00.000Z.jpg');
        final preview = await loadPreview(vault, server, VaultItem(file));
        expect(preview.image.width, greaterThan(0));
        preview.image.dispose();
        expect(await thumbnailOf(file).exists(), isFalse);
      });
    },
  );
}
