import 'dart:convert';
import 'dart:io';

import 'package:sodium/sodium_sumo.dart';
import 'package:crypto/crypto.dart' as hashes;

import '../compat/legacy_identity.dart';
import '../library/private_catalog.dart';
import '../vault/file_name.dart';
import '../vault/master_key_store.dart';
import '../vault/vault.dart';
import 'archive_worker.dart';

/// An encrypted, validated snapshot. Reading never adopts it into a live vault.
class PortableBackup {
  PortableBackup(this.vault, this.key);
  final Vault vault;
  final SecureKey key;
  static const maxBytes = 2 * 1024 * 1024 * 1024;
  static const maxFiles = 10000;
  static const _manifest = 'manifest.shtr';

  void _check(bool Function()? cancelled) {
    if (cancelled?.call() == true) throw StateError('Backup cancelled');
  }

  Future<String> _authenticateAndDigest(
    File file,
    bool Function()? cancelled,
  ) async {
    final result = DigestSink();
    final hash = hashes.sha256.startChunkedConversion(result);
    try {
      await vault.crypto
          .decrypt(
            file.openRead().map((bytes) {
              _check(cancelled);
              hash.add(bytes);
              return bytes;
            }),
            key,
          )
          .drain<void>();
    } finally {
      hash.close();
    }
    return result.value!.toString();
  }

  Future<void> export(
    File target, {
    bool Function()? isCancelled,
    void Function(int, int)? onProgress,
  }) async {
    _check(isCancelled);
    if (!vault.matchesKey(key)) {
      throw const FormatException('Different vault key');
    }
    final work = await target.parent.createTemp('.portable-export-');
    File? catalogSnapshot;
    try {
      await vault.catalog.load();
      catalogSnapshot = await vault.catalog.snapshot();
      final catalog = File('${work.path}/catalog.shtr');
      if (catalogSnapshot != null) {
        await catalogSnapshot.copy(catalog.path);
      } else {
        await vault.writeMetadata(
          catalog,
          utf8.encode(
            jsonEncode({
              'version': 1,
              'albums': <String, String>{},
              'items': <String, Object>{},
            }),
          ),
        );
      }
      final media = await vault.list();
      if (media.length > maxFiles) {
        throw const FormatException('Backup file limit exceeded');
      }
      final files = <Map<String, Object>>[];
      final inputs = <Map<String, String>>[];
      var size = 0;
      for (var i = 0; i <= media.length; i++) {
        _check(isCancelled);
        final file = i == media.length ? catalog : media[i];
        final length = await file.length();
        size += length;
        if (size > maxBytes - 8 * 1024 * 1024) {
          throw const FormatException('Backup exceeds the 2 GiB ZIP limit');
        }
        // Authenticate and hash the same streamed read; no duplicate file pass.
        final digest = await _authenticateAndDigest(file, isCancelled);
        final entry = i == media.length
            ? 'catalog.shtr'
            : 'item-${i.toString().padLeft(5, '0')}.shtr';
        files.add({
          'entry': entry,
          'name': i == media.length
              ? PrivateCatalog.fileName
              : file.uri.pathSegments.last,
          'size': length,
          'digest': digest,
        });
        inputs.add({'entry': entry, 'path': file.path});
      }
      final manifest = File('${work.path}/$_manifest');
      final bytes = utf8.encode(
        jsonEncode({'version': 1, 'hash': 'sha256', 'files': files}),
      );
      if (bytes.length > 4 * 1024 * 1024 - 1024) {
        throw const FormatException('Backup manifest limit exceeded');
      }
      await vault.writeMetadata(manifest, bytes);
      inputs.add({'entry': _manifest, 'path': manifest.path});
      final output = File('${work.path}/backup.zip');
      await runArchiveWorker(
        {
          'encode': true,
          'target': output.path,
          'files': inputs,
          'password': MasterKeyStore.archivePassword(key),
        },
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      _check(isCancelled);
      if (await output.length() > maxBytes) {
        throw const FormatException('Backup size limit exceeded');
      }
      await output.rename(target.path);
    } finally {
      if (catalogSnapshot != null && await catalogSnapshot.parent.exists()) {
        await catalogSnapshot.parent.delete(recursive: true);
      }
      await work.delete(recursive: true);
    }
  }

  Future<Directory> stage(
    File source,
    Directory parent, {
    bool Function()? isCancelled,
    void Function(int, int)? onProgress,
  }) async {
    _check(isCancelled);
    if (await source.length() > maxBytes) {
      throw const FormatException('Backup size limit exceeded');
    }
    final work = await parent.createTemp('.portable-stage-');
    var complete = false;
    try {
      await runArchiveWorker(
        {
          'encode': false,
          'source': source.path,
          'directory': work.path,
          'password': MasterKeyStore.archivePassword(key),
        },
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      _check(isCancelled);
      final manifest = File('${work.path}/$_manifest');
      final clear = <int>[];
      await for (final chunk in vault.crypto.decrypt(
        manifest.openRead(),
        key,
      )) {
        _check(isCancelled);
        if (clear.length + chunk.length > 4 * 1024 * 1024) {
          throw const FormatException('Backup manifest limit exceeded');
        }
        clear.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != 1 ||
          decoded['hash'] != 'sha256' ||
          decoded['files'] is! List) {
        throw const FormatException('Unsupported backup manifest');
      }
      final records = decoded['files'] as List;
      if (records.isEmpty || records.length > maxFiles + 1) {
        throw const FormatException('Backup file limit exceeded');
      }
      final entries = <String>{_manifest};
      final names = <String>{};
      final renames = <(File, String)>[];
      for (final item in records) {
        _check(isCancelled);
        if (item is! Map<String, dynamic> ||
            item['entry'] is! String ||
            item['name'] is! String ||
            item['size'] is! int ||
            item['digest'] is! String) {
          throw const FormatException('Invalid backup manifest');
        }
        final entry = item['entry'] as String;
        final name = checkedFileName(item['name'] as String);
        if (!RegExp(r'^(catalog|item-[0-9]{5})\.shtr$').hasMatch(entry) ||
            !entries.add(entry) ||
            !names.add(name.toLowerCase()) ||
            (entry == 'catalog.shtr'
                ? name != PrivateCatalog.fileName &&
                      name != LegacyIdentity.catalog
                : !name.endsWith('.shtr')) ||
            name.startsWith('.') ||
            name == _manifest) {
          throw const FormatException('Invalid or duplicate backup entry');
        }
        final file = File('${work.path}/$entry');
        if (await file.length() != item['size'] ||
            await _authenticateAndDigest(file, isCancelled) != item['digest']) {
          throw const FormatException('Backup content differs from manifest');
        }
        renames.add((
          file,
          entry == 'catalog.shtr' ? PrivateCatalog.fileName : name,
        ));
      }
      if (!entries.contains('catalog.shtr') ||
          (await work.list().toList()).length != entries.length) {
        throw const FormatException('Incomplete or unexpected backup entries');
      }
      await manifest.delete();
      // Names differ from opaque ZIP entries. Rename through a second directory
      // so an original name cannot collide with another still-staged ZIP entry.
      final ready = await Directory('${work.path}/ready').create();
      for (final (file, name) in renames) {
        final target = File('${ready.path}/$name');
        if (await target.exists()) {
          throw const FormatException(
            'Backup filenames collide on this device',
          );
        }
        await file.rename(target.path);
      }
      final restored = Vault(vault.crypto, key.copy(), ready);
      try {
        await restored.catalog.load();
      } finally {
        await restored.catalog.close();
        restored.dispose();
      }
      _check(isCancelled);
      final result = await ready.rename('${work.path}.validated');
      complete = true;
      return result;
    } finally {
      // The returned validated directory is a sibling, never deleted here.
      if (await work.exists()) await work.delete(recursive: true);
      if (!complete) {
        final validated = Directory('${work.path}.validated');
        if (await validated.exists()) await validated.delete(recursive: true);
      }
    }
  }
}
