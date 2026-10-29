import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/library/import_media.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fixtures.dart';

class _FullDiskCrypto extends VaultCrypto {
  _FullDiskCrypto(super.sodium);
  @override
  Future<void> encryptFile(File plain, File out, SecureKey key) async {
    await out.writeAsBytes(VaultCrypto.magic);
    throw const FileSystemException('simulated full disk');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory staging;
  late Vault vault;
  late MediaImporter importer;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('private-import-test');
    staging = await Directory('${root.path}/quietake-import').create();
    final sodium = await SodiumSumoInit.init();
    vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      await Directory('${root.path}/vault').create(),
    );
    importer = MediaImporter(vault, staging, validate: (_, _) async {});
  });
  tearDown(() async {
    vault.dispose();
    await root.delete(recursive: true);
  });

  Future<ImportInput> source(String name, List<int> bytes) async {
    final file = await File('${staging.path}/$name').writeAsBytes(bytes);
    return ImportInput(name: name, path: file.path);
  }

  test('copy-only import preserves original, authenticates bytes and skips exact duplicates', () async {
    final bytes = Uint8List.fromList(List.generate(70001, (i) => i % 251));
    final original = await File('${root.path}/external.jpg')
        .writeAsBytes(bytes);
    final input = await source('a.jpg', bytes);
    final result = await importer.run([input, await source('b.jpg', bytes)]);
    expect(result.map((r) => r.status), [
      ImportStatus.imported,
      ImportStatus.duplicate,
    ]);
    expect(await original.readAsBytes(), bytes);
    expect(await vault.readAll((await vault.list()).single), bytes);
    expect(await staging.exists(), isFalse);
    await staging.create();
    expect(
      (await importer.run([await source('again.jpg', bytes)])).single.status,
      ImportStatus.duplicate,
    );
    expect(await vault.list(), hasLength(1));
  });

  test('same length with different bytes imports, corrupt candidates do not block new media', () async {
    await File('${vault.dir.path}/damaged.jpg.shtr').writeAsBytes([1, 2]);
    final result = await importer.run([
      await source('a.jpg', [1, 2, 3]),
      await source('b.jpg', [3, 2, 1]),
    ]);
    expect(result.every((r) => r.status == ImportStatus.imported), isTrue);
    expect(await vault.list(), hasLength(3));
  });

  test('cancellation keeps committed media and removes every remaining private copy', () async {
    var cancelled = false;
    final result = await importer.run(
      [
        await source('a.jpg', [1]),
        await source('b.mp4', [2]),
      ],
      isCancelled: () => cancelled,
      onResult: (_) => cancelled = true,
    );
    expect(result.map((r) => r.status), [
      ImportStatus.imported,
      ImportStatus.cancelled,
    ]);
    expect(await vault.list(), hasLength(1));
    expect(await staging.exists(), isFalse);
  });

  test('invalid formats, native copy failures and damaged media have separate outcomes', () async {
    importer = MediaImporter(
      vault,
      staging,
      validate: (_, _) async => throw const FormatException('damaged'),
    );
    final result = await importer.run([
      await source('a.heic', [1]),
      const ImportInput(name: 'b.jpg', error: 'Could not copy.'),
      await source('c.jpg', [1]),
    ]);
    expect(result.every((r) => r.status == ImportStatus.failed), isTrue);
    expect(result[0].message, contains('JPEG'));
    expect(await vault.list(), isEmpty);
    expect(await staging.exists(), isFalse);
  });

  test(
    'untrusted paths never authorize reading or deleting external sources',
    () async {
      final external = await File('${root.path}/external.jpg')
          .writeAsBytes([1, 2]);
      final result = await importer.run([
        ImportInput(name: 'external.jpg', path: external.path),
      ]);
      expect(result.single.status, ImportStatus.failed);
      expect(await external.readAsBytes(), [1, 2]);
      expect(await vault.list(), isEmpty);
    },
  );

  test(
    'oversized photos and more than twenty files leave no new containers',
    () async {
      final large = File('${staging.path}/large.jpg');
      final handle = await large.open(mode: FileMode.write);
      await handle.truncate(Vault.maxPhotoBytes + 1);
      await handle.close();
      final result = await importer.run([
        ImportInput(name: 'large.jpg', path: large.path),
      ]);
      expect(result.single.message, contains('limit'));
      await staging.create();
      final inputs = [
        for (var i = 0; i < 21; i++) await source('$i.jpg', [i]),
      ];
      expect(
        (await importer.run(inputs))
            .every((r) => r.status == ImportStatus.failed),
        isTrue,
      );
      expect(await vault.list(), isEmpty);
      expect(await staging.exists(), isFalse);
    },
  );

  testWidgets('oversized decoded photos fail without changing their original', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final original = File('test_fixtures/oversized.png');
      await expectLater(
        validateImport(original, 'png'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('resolution limit'),
          ),
        ),
      );
      expect(await original.length(), lessThan(32 * 1024));
    });
  });

  testWidgets(
    'native photo validation bounds tall/wide decode and rejects damaged headers',
    (tester) async {
      await tester.runAsync(() async {
        for (final name in ['tiny.jpg', 'tall.png', 'wide.png']) {
          final file = File((await source(name, fixtureBytes(name))).path!);
          await validateImport(file, name.endsWith('png') ? 'png' : 'jpg');
        }
        final damaged = File(
          (await source('damaged.jpg', [255, 216, 255, 0])).path!,
        );
        await expectLater(
          validateImport(damaged, 'jpg'),
          throwsFormatException,
        );
        final disguised = File(
          (await source('not.png', fixtureBytes('tiny.jpg'))).path!,
        );
        await expectLater(
          validateImport(disguised, 'png'),
          throwsFormatException,
        );
      });
    },
  );

  test(
    'symlink outside private staging cannot read or delete its external target',
    () async {
      final external = await File('${root.path}/original.jpg')
          .writeAsBytes([1]);
      final link = await Link('${staging.path}/link.jpg').create(external.path);
      expect(
        (await importer.run([ImportInput(name: 'link.jpg', path: link.path)]))
            .single
            .status,
        ImportStatus.failed,
      );
      expect(await external.readAsBytes(), [1]);
    },
  );

  test('one unreadable input does not block the next valid copy', () async {
    final valid = await source('valid.jpg', [1, 2, 3]);
    final results = await importer.run([
      ImportInput(name: 'missing.jpg', path: '${staging.path}/missing.jpg'),
      valid,
    ]);
    expect(results.map((r) => r.status), [
      ImportStatus.failed,
      ImportStatus.imported,
    ]);
    expect(await vault.readAll((await vault.list()).single), [1, 2, 3]);
    expect(await staging.exists(), isFalse);
  });

  test('write failure preserves source original and reports failure without partial vault files', () async {
    final original = await File('${root.path}/external.jpg')
        .writeAsBytes([1, 2, 3]);
    final input = await source('a.jpg', await original.readAsBytes());
    final sodium = vault.crypto.sodium;
    final directory = vault.dir;
    vault.dispose();
    vault = Vault(
      _FullDiskCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      directory,
    );
    importer = MediaImporter(vault, staging, validate: (_, _) async {});
    final result = await importer.run([input]);
    expect(result.single.status, ImportStatus.failed);
    expect(await staging.exists(), isFalse);
    expect(await vault.list(), isEmpty);
    expect(await vault.dir.list().toList(), isEmpty);
    expect(await original.readAsBytes(), [1, 2, 3]);
  });
}
