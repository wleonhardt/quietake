import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/portable_backup.dart';
import 'package:quietake/backup/archive_worker.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Directory root;
  late Vault vault;
  late SecureKey key;
  late PortableBackup backup;
  late File archive;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('portable-backup-test');
    final sodium = await SodiumSumoInit.init();
    key = sodium.crypto.secretBox.keygen();
    vault = Vault(
      VaultCrypto(sodium),
      key.copy(),
      await Directory('${root.path}/vault').create(),
    );
    backup = PortableBackup(vault, key);
    archive = File('${root.path}/backup.zip');
    final input = await File('${root.path}/input').writeAsBytes([1, 2, 3, 4]);
    final item = await vault.ingestAs(input, 'private-title.jpg');
    await vault.catalog.renameItem(
      item.uri.pathSegments.last,
      'Private display name',
    );
  });
  tearDown(() async {
    await vault.catalog.close();
    vault.dispose();
    key.dispose();
    await root.delete(recursive: true);
  });

  test('encrypted ZIP round trip preserves media and catalog without exposing original names', () async {
    final before = await (await vault.list()).single.readAsBytes();
    await backup.export(archive);
    final input = InputFileStream(archive.path);
    try {
      final zip = ZipDirectory()..read(input);
      expect(zip.fileHeaders.every((h) => h.compressionMethod == 99), isTrue);
      expect(
        zip.fileHeaders.map((h) => h.filename).join(),
        isNot(contains('private')),
      );
      expect(
        await archive.readAsBytes(),
        isNot(containsAllInOrder('Private display name'.codeUnits)),
      );
    } finally {
      await input.close();
    }
    final stage = await backup.stage(archive, root);
    final restored = Vault(vault.crypto, key.copy(), stage);
    try {
      final file = (await restored.list()).single;
      expect(await restored.readAll(file), [1, 2, 3, 4]);
      expect(await file.readAsBytes(), before);
      await restored.catalog.load();
      expect(
        restored.catalog.details(file.uri.pathSegments.last).title,
        'Private display name',
      );
    } finally {
      await restored.catalog.close();
      restored.dispose();
    }
    expect(await (await vault.list()).single.readAsBytes(), before);
  });

  test('wrong key rejects before staging becomes visible and preserves source archive', () async {
    await backup.export(archive);
    final original = await archive.readAsBytes();
    final foreign = vault.crypto.generateMasterKey();
    try {
      await expectLater(
        PortableBackup(vault, foreign).stage(archive, root),
        throwsA(anything),
      );
    } finally {
      foreign.dispose();
    }
    expect(await archive.readAsBytes(), original);
    expect(
      root.listSync().whereType<Directory>().map(
        (d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last,
      ),
      ['vault'],
    );
  });

  test(
    'truncated ZIP and modified encrypted entry are rejected, originals remain',
    () async {
      await backup.export(archive);
      final original = await archive.readAsBytes();
      await archive.writeAsBytes(original.sublist(0, original.length - 5));
      await expectLater(backup.stage(archive, root), throwsA(anything));
      final changed = [...original];
      changed[80] ^= 1;
      await archive.writeAsBytes(changed);
      await expectLater(backup.stage(archive, root), throwsA(anything));
      expect(await vault.readAll((await vault.list()).single), [1, 2, 3, 4]);
    },
  );

  test('cancelled export removes only its own staging and preserves existing destination', () async {
    await archive.writeAsBytes([9]);
    await expectLater(
      backup.export(archive, isCancelled: () => true),
      throwsA(anything),
    );
    expect(await archive.readAsBytes(), [9]);
    expect(await vault.readAll((await vault.list()).single), [1, 2, 3, 4]);
  });

  test(
    'unknown ZIP paths are rejected without extracting outside owned staging',
    () async {
      final zip = ZipEncoder().encode(
        Archive()..add(ArchiveFile.string('../escape', 'not allowed')),
      );
      await archive.writeAsBytes(zip);
      await expectLater(backup.stage(archive, root), throwsA(anything));
      expect(await File('${root.path}/escape').exists(), isFalse);
      expect(await vault.readAll((await vault.list()).single), [1, 2, 3, 4]);
    },
  );
  test('the final ZIP authentication code is checked even after a complete payload', () async {
    await backup.export(archive);
    final bytes = await archive.readAsBytes();
    final input = InputFileStream(archive.path);
    late int lastMac;
    try {
      final zip = ZipDirectory()..read(input);
      final header = zip.fileHeaders.first;
      final local = ByteData.sublistView(bytes, header.localHeaderOffset);
      lastMac =
          header.localHeaderOffset +
          30 +
          local.getUint16(26, Endian.little) +
          local.getUint16(28, Endian.little) +
          header.compressedSize -
          1;
    } finally {
      await input.close();
    }
    bytes[lastMac] ^= 1;
    await archive.writeAsBytes(bytes);
    await expectLater(backup.stage(archive, root), throwsFormatException);
    expect(await vault.readAll((await vault.list()).single), [1, 2, 3, 4]);
  });

  test(
    'duplicate central-directory records cannot be merged and accepted',
    () async {
      await backup.export(archive);
      final bytes = await archive.readAsBytes();
      final footer = ByteData.sublistView(bytes, bytes.length - 22);
      final start = footer.getUint32(16, Endian.little);
      final header = ByteData.sublistView(bytes, start);
      final length =
          46 +
          header.getUint16(28, Endian.little) +
          header.getUint16(30, Endian.little) +
          header.getUint16(32, Endian.little);
      final duplicate = Uint8List.fromList([
        ...bytes.sublist(0, bytes.length - 22),
        ...bytes.sublist(start, start + length),
        ...bytes.sublist(bytes.length - 22),
      ]);
      final changed = ByteData.sublistView(duplicate, duplicate.length - 22);
      changed.setUint16(
        8,
        footer.getUint16(8, Endian.little) + 1,
        Endian.little,
      );
      changed.setUint16(
        10,
        footer.getUint16(10, Endian.little) + 1,
        Endian.little,
      );
      changed.setUint32(
        12,
        footer.getUint32(12, Endian.little) + length,
        Endian.little,
      );
      await archive.writeAsBytes(duplicate);
      await expectLater(backup.stage(archive, root), throwsFormatException);
    },
  );

  test(
    'an authenticated manifest rejects a ZIP missing one of its media entries',
    () async {
      await backup.export(archive);
      final password = MasterKeyStore.archivePassword(key);
      final input = InputFileStream(archive.path);
      final edited = Archive();
      try {
        final zip = ZipDirectory()..read(input, password: password);
        for (final header in zip.fileHeaders) {
          if (header.filename.startsWith('item-')) continue;
          final bytes = header.file!.getStream(decompress: false).toUint8List();
          edited.add(
            ArchiveFile.bytes(header.filename, bytes)
              ..compression = CompressionType.none,
          );
        }
      } finally {
        await input.close();
      }
      await archive.writeAsBytes(ZipEncoder(password: password).encode(edited));
      await expectLater(backup.stage(archive, root), throwsA(anything));
      expect(await vault.readAll((await vault.list()).single), [1, 2, 3, 4]);
    },
  );

  test(
    'ZIP crypto stays off UI isolate and its active worker can be cancelled',
    () async {
      final source = File('${root.path}/large-synthetic-container');
      final file = await source.open(mode: FileMode.write);
      await file.truncate(64 * 1024 * 1024);
      await file.close();
      var cancelled = false;
      var started = false;
      await expectLater(
        runArchiveWorker(
          {
            'encode': true,
            'target': '${root.path}/worker-part.zip',
            'password': 'synthetic-worker-test-password',
            'files': [
              {'path': source.path, 'entry': 'item-00000.shtr'},
            ],
          },
          isCancelled: () => cancelled,
          onProgress: (done, total) {
            if (done == 0) {
              started = true;
              cancelled = true;
            }
          },
        ).timeout(const Duration(seconds: 10)),
        throwsStateError,
      );
      expect(started, isTrue);
      expect(await source.length(), 64 * 1024 * 1024);
    },
  );
}
