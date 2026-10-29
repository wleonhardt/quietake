import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

import '../crypto/vault_crypto.dart';
import '../library/private_catalog.dart';
import 'file_name.dart';

class PhotoTooLargeException extends FormatException {
  const PhotoTooLargeException()
    : super('Photo too large to preview. Share a copy to open it elsewhere.');
}

/// The on-device vault: a master key and a directory
/// of `.shtr` containers in the app's private documents folder.
class Vault {
  Vault(this.crypto, this._masterKey, this.dir);

  static const maxPhotoBytes = 32 * 1024 * 1024;

  final VaultCrypto crypto;
  final SecureKey _masterKey;
  final Directory dir;
  late final catalog = PrivateCatalog(this);

  /// Encrypts in-memory metadata without a plaintext file. Callers serialize
  /// writes to each destination; interrupted siblings are never authoritative.
  Future<void> writeMetadata(File out, List<int> bytes) async {
    final staging = File('${out.path}.part');
    final sink = staging.openWrite();
    try {
      await sink.addStream(crypto.encrypt(Stream.value(bytes), _masterKey));
      await sink.flush();
      await sink.close();
      await _publish(staging, out);
    } finally {
      try {
        await sink.close();
      } catch (_) {}
      if (await staging.exists()) await staging.delete();
    }
  }

  /// Durable replace: fsync the staged bytes, then rename over [out]. An
  /// IOSink flush alone only hands data to the OS, so power loss after the
  /// rename could still roll the file back.
  Future<File> _publish(File staging, File out) async {
    final handle = await staging.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    return staging.rename(out.path);
  }

  /// Containers live under `<documents>/vault`.
  static Future<Directory> defaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/vault')..createSync(recursive: true);
  }

  /// Encrypts [plain] into the vault and deletes the plaintext.
  Future<File> ingest(File plain, {required String extension}) async {
    final id = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return ingestAs(plain, '$id.$extension');
  }

  /// Like [ingest] with an explicit plaintext name (`stem.ext`).
  Future<File> ingestAs(File plain, String name) async {
    final out = File('${dir.path}/${checkedFileName(name)}.shtr');
    try {
      if (await out.exists()) {
        // Timestamp names can collide within one millisecond; never replace.
        throw FileSystemException('Capture name already exists', out.path);
      }
      return await encryptFile(plain, out);
    } finally {
      if (await plain.exists()) await plain.delete();
    }
  }

  /// Atomically writes a container without taking ownership of its source.
  /// Capture finalization retains that source until durable publication succeeds.
  Future<File> encryptFile(File plain, File out) async {
    final staging = File('${out.path}.part');
    try {
      if (await plain.length() == 0) {
        throw const FormatException('Camera returned an empty capture');
      }
      await crypto.encryptFile(plain, staging, _masterKey);
      return await _publish(staging, out);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  /// Binds recovery to this live session without exporting either key.
  bool matchesKey(SecureKey candidate) {
    if (identical(candidate, _masterKey)) return true;
    if (candidate.length != _masterKey.length) return false;
    return _masterKey.runUnlockedSync(
      (expected) => candidate.runUnlockedSync(
        (actual) => crypto.sodium.memcmp(expected, actual),
      ),
    );
  }

  /// Plaintext bytes of [container], held in memory. Photos only.
  Future<Uint8List> readAll(File container) async {
    final b = BytesBuilder(copy: false);
    await for (final c in read(container)) {
      if (b.length + c.length > maxPhotoBytes) {
        throw const PhotoTooLargeException();
      }
      b.add(c);
    }
    return b.takeBytes();
  }

  Future<List<File>> list() async {
    final deleted = await deletedNames();
    final files = await dir
        .list()
        .where(
          (e) =>
              e is File &&
              (e.path.endsWith('.shtr') || e.path.endsWith('.shtr.part')),
        )
        .cast<File>()
        .toList();
    for (final file in files) {
      var name = file.uri.pathSegments.last;
      if (name.endsWith('.part')) name = name.substring(0, name.length - 5);
      if (deleted.contains(name)) await delete(File('${dir.path}/$name'));
    }
    files.removeWhere(
      (f) =>
          f.path.endsWith('.part') || deleted.contains(f.uri.pathSegments.last),
    );
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Directory get _deletions => Directory('${dir.path}/.deletions');

  /// Local-only, durable decisions. Sync must not infer deletion from absence.
  Future<Set<String>> deletedNames() async {
    if (!await _deletions.exists()) return {};
    final names = await _deletions
        .list()
        .where((e) => e is File && e.path.endsWith('.del'))
        .map((e) => e.uri.pathSegments.last)
        .toList();
    return names
        .map((name) => '${name.substring(0, name.length - 4)}.shtr')
        .toSet();
  }

  /// Commits the deletion decision before removing bytes, so crashes can retry.
  Future<void> delete(File container) async {
    final name = checkedFileName(container.uri.pathSegments.last);
    if (container.absolute.parent.uri.normalizePath() !=
            dir.absolute.uri.normalizePath() ||
        !name.endsWith('.shtr')) {
      throw const FormatException('Expected a container in this vault');
    }
    final marker = File(
      '${_deletions.path}/${name.substring(0, name.length - 5)}.del',
    );
    if (!await marker.exists()) {
      await _deletions.create(recursive: true);
      final pending = await _deletions.createTemp('.pending-');
      try {
        final staged = await File('${pending.path}/marker')
            .writeAsBytes([], flush: true);
        await staged.rename(marker.path);
      } finally {
        await pending.delete(recursive: true);
      }
    }
    for (final file in [container, File('${container.path}.part')]) {
      try {
        await file.delete();
      } on FileSystemException catch (e) {
        // Sync and the viewer may finish the same authorized unlink concurrently.
        if (e.osError?.errorCode != 2) rethrow;
      }
    }
  }

  /// Exposed for tests that build containers with a custom chunk size.
  @visibleForTesting
  SecureKey get masterKeyForTests => _masterKey;

  void dispose() => _masterKey.dispose();

  Stream<List<int>> read(File container) =>
      crypto.decrypt(container.openRead(), _masterKey);
}
