import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/locked_capture_store.dart';
import 'package:quietake/crypto/pending_crypto.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/pending_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late SodiumSumo sodium;
  late Directory root;
  late Vault vault;
  late PendingKeyStore keys;
  late LockedCaptureStore locked;

  setUpAll(() async => sodium = await SodiumSumoInit.init());
  setUp(() async {
    root = await Directory.systemTemp.createTemp('locked-capture');
    final master = sodium.crypto.secretBox.keygen();
    vault = Vault(VaultCrypto(sodium), master, root);
    keys = PendingKeyStore(sodium, root);
    await keys.ensure(master);
    locked = LockedCaptureStore(PendingCrypto(sodium), root);
  });
  tearDown(() async {
    vault.dispose();
    await root.delete(recursive: true);
  });

  Future<File> source(List<int> bytes, [String name = 'cam.jpg']) async =>
      File('${root.path}/$name')..writeAsBytesSync(bytes);

  Future<List<int>> plaintext(File c) async {
    final b = BytesBuilder();
    await for (final x in vault.read(c)) {
      b.add(x);
    }
    return b.takeBytes();
  }

  test('a locked save seals the capture and removes the plaintext', () async {
    final src = await source([1, 2, 3, 4]);
    final sealed = await locked.save(
      src,
      extension: 'jpg',
      publicKey: (await keys.publicKey())!,
    );
    expect(await src.exists(), isFalse);
    expect(sealed.path, startsWith(locked.directory.path));
    expect(sealed.readAsBytesSync().sublist(0, 4), PendingCrypto.magic);
    expect(await locked.count(), 1);
  });

  test('two saves in the same instant never overwrite each other', () async {
    final pub = (await keys.publicKey())!;
    final fixed = DateTime.utc(2026, 11, 16, 12);
    final same = LockedCaptureStore(
      PendingCrypto(sodium),
      root,
      clock: () => fixed,
    );
    final a = await same.save(
      await source([1], 'a.jpg'),
      extension: 'jpg',
      publicKey: pub,
    );
    final b = await same.save(
      await source([2], 'b.jpg'),
      extension: 'jpg',
      publicKey: pub,
    );
    expect(a.path, isNot(b.path));
    expect(await same.count(), 2);
  });

  test('a pending capture never shows in the library listing', () async {
    final pub = (await keys.publicKey())!;
    await locked.save(
      await source([1, 2, 3]),
      extension: 'jpg',
      publicKey: pub,
    );
    expect(await vault.list(), isEmpty);
  });

  test('unlock publishes each pending capture as a normal container', () async {
    final pub = (await keys.publicKey())!;
    await locked.save(
      await source([1, 2, 3]),
      extension: 'jpg',
      publicKey: pub,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await locked.save(
      await source([9, 8], 'v.mp4'),
      extension: 'mp4',
      publicKey: pub,
    );
    final secret = await keys.secretKey(vault.masterKeyForTests);
    final result = await locked.publishAll(vault, pub, secret);
    secret.dispose();
    expect(result.published, 2);
    expect(result.failed, 0);
    expect(await locked.count(), 0);
    final shtr =
        root
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.shtr'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(shtr, hasLength(2));
    expect(shtr[0].path, endsWith('.jpg.shtr'));
    expect(await plaintext(shtr[0]), [1, 2, 3]);
    expect(await plaintext(shtr[1]), [9, 8]);
  });

  test(
    'a pending capture whose name was deleted is discarded, not published',
    () async {
      final pub = (await keys.publicKey())!;
      final sealed = await locked.save(
        await source([5]),
        extension: 'jpg',
        publicKey: pub,
      );
      final name = sealed.uri.pathSegments.last.replaceAll('.pending', '.shtr');
      final f = File('${root.path}/$name')..writeAsBytesSync([0]);
      await vault.delete(f);
      final secret = await keys.secretKey(vault.masterKeyForTests);
      final result = await locked.publishAll(vault, pub, secret);
      secret.dispose();
      expect(await locked.count(), 0);
      expect(File('${root.path}/$name').existsSync(), isFalse);
      expect(result.published, 0);
    },
  );

  test('a wrong secret keeps the pending file and reports a failure', () async {
    final pub = (await keys.publicKey())!;
    await locked.save(await source([1]), extension: 'jpg', publicKey: pub);
    final other = PendingCrypto(sodium).generateKeyPair();
    final result = await locked.publishAll(
      vault,
      other.publicKey,
      other.secretKey,
    );
    expect(result.failed, 1);
    expect(await locked.count(), 1);
    expect(
      root.listSync().whereType<File>().where((f) => f.path.endsWith('.shtr')),
      isEmpty,
    );
  });

  test('a failed seal keeps the plaintext source', () async {
    final src = await source([1, 2]);
    await expectLater(
      locked.save(src, extension: 'jpg', publicKey: Uint8List(3)),
      throwsA(anything),
    );
    expect(await src.exists(), isTrue);
    expect(await locked.count(), 0);
  });
}
