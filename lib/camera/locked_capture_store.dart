import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sodium/sodium_sumo.dart';

import '../crypto/pending_crypto.dart';
import '../vault/vault.dart';

/// Captures taken while the vault is locked (decision 028). Needs no vault
/// key: each capture is sealed to the public key and waits in a hidden
/// folder that library and sync listings never read. The next unlock
/// publishes them as ordinary containers.
class LockedCaptureStore {
  LockedCaptureStore(this.crypto, this.vaultDir);

  final PendingCrypto crypto;
  final Directory vaultDir;

  Directory get directory => Directory('${vaultDir.path}/.pending');

  /// Seals [source] and deletes it only after the sealed file is complete.
  Future<File> save(
    File source, {
    required String extension,
    required Uint8List publicKey,
  }) async {
    await directory.create(recursive: true);
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await const MethodChannel('quietake/captures')
                .invokeMethod<bool>('protect', {'path': directory.path}) !=
            true) {
      throw const FileSystemException(
        'Could not exclude pending captures from backup',
      );
    }
    final id = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final out = File('${directory.path}/$id.$extension.pending');
    final tmp = File('${out.path}.part');
    try {
      await crypto.seal(source, tmp, publicKey);
      await tmp.rename(out.path);
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
    await source.delete();
    return out;
  }

  Future<List<File>> _files() async {
    if (!await directory.exists()) return [];
    final files = await directory
        .list(followLinks: false)
        .where((e) => e is File && e.path.endsWith('.pending'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<int> count() async => (await _files()).length;

  /// Publishes every pending capture. A file stays until its container is
  /// authenticated; a capture the owner already deleted is discarded.
  Future<({int published, int failed})> publishAll(
    Vault vault,
    Uint8List publicKey,
    SecureKey secretKey,
  ) async {
    var published = 0;
    var failed = 0;
    final deleted = await vault.deletedNames();
    for (final file in await _files()) {
      final base = file.uri.pathSegments.last;
      final name = '${base.substring(0, base.length - '.pending'.length)}.shtr';
      final out = File('${vaultDir.path}/$name');
      try {
        if (deleted.contains(name)) {
          await file.delete();
          continue;
        }
        if (!await out.exists()) {
          await vault.publishPending(crypto, file, out, publicKey, secretKey);
        }
        await for (final _ in vault.read(out)) {
          // Consume through FINAL before the pending copy goes away.
        }
        await file.delete();
        published++;
      } on Exception {
        failed++;
      }
    }
    return (published: published, failed: failed);
  }
}
