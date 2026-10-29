import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';

/// Synthetic v1 archive, deliberately independent of the current export writer.
Future<File> writeLegacyArchive(
  Vault vault,
  SecureKey key,
  File target,
  List<int> catalog,
  Map<String, List<int>> media,
) async {
  final work = await target.parent.createTemp('legacy-fixture-');
  try {
    final files = {'catalog.shtr': catalog};
    final records = <Map<String, Object>>[];
    var index = 0;
    for (final entry in {'tucklight.catalog': catalog, ...media}.entries) {
      final opaque = entry.key == 'tucklight.catalog'
          ? 'catalog.shtr'
          : 'item-${(index++).toString().padLeft(5, '0')}.shtr';
      files[opaque] = entry.value;
      records.add({
        'entry': opaque,
        'name': entry.key,
        'size': entry.value.length,
        'digest': sha256.convert(entry.value).toString(),
      });
    }
    final manifest = File('${work.path}/manifest');
    await vault.writeMetadata(
      manifest,
      utf8.encode(
        jsonEncode({'version': 1, 'hash': 'sha256', 'files': records}),
      ),
    );
    files['manifest.shtr'] = await manifest.readAsBytes();
    final archive = Archive();
    for (final entry in files.entries) {
      archive.add(
        ArchiveFile.bytes(entry.key, List<int>.of(entry.value))
          ..compression = CompressionType.none,
      );
    }
    return await target.writeAsBytes(
      ZipEncoder(password: MasterKeyStore.archivePassword(key)).encode(archive),
    );
  } finally {
    await work.delete(recursive: true);
  }
}
