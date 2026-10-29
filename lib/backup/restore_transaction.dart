import 'dart:convert';
import 'dart:io';

import 'package:sodium/sodium_sumo.dart';

import '../vault/master_key_store.dart';

/// Only a fresh installation can adopt another identity. The ready journal holds
/// a fingerprint of the encrypted keyfile (a hash of ciphertext wrapped by
/// Argon2id, so it reveals nothing about the key or passcode). Startup can
/// finish the two file moves after process death without requiring either
/// secret, which is why the fingerprint cannot itself be keyed.
class RestoreTransaction {
  RestoreTransaction(this.store);
  final MasterKeyStore store;
  Directory get pending => Directory('${store.dir.path}/.portable-restore');
  Directory get target => Directory('${store.dir.path}/vault');

  Future<void> requireFresh() async {
    if (await store.hasKeyfile ||
        await store.hasCachedKey ||
        (await target.exists() && !await target.list().isEmpty)) {
      throw const FormatException('Restore requires a fresh empty vault');
    }
  }

  Future<String> _fingerprint(File file) async {
    if (await file.length() > 65536) {
      throw const FormatException('Invalid restore keyfile');
    }
    final hash = store.sodium.crypto.genericHash.call(
      message: await file.readAsBytes(),
    );
    return base64Encode(hash);
  }

  Future<void> commit(
    Directory validated,
    SecureKey key,
    String passcode, {
    bool Function()? isCancelled,
    void Function(String)? onProgress,
    void Function()? onCommitting,
  }) async {
    await requireFresh();
    if (await pending.exists()) {
      throw const FormatException('Another restore is pending');
    }
    final parent = await store.dir.resolveSymbolicLinks();
    final source = await validated.resolveSymbolicLinks();
    final name = validated.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (validated.parent.resolveSymbolicLinksSync() != parent ||
        !name.startsWith('.portable-stage-') ||
        !name.endsWith('.validated') ||
        source != '$parent/$name' ||
        await FileSystemEntity.type(validated.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw const FormatException('Expected validated private restore staging');
    }
    await pending.create();
    final ready = File('${pending.path}/ready');
    try {
      await validated.rename('${pending.path}/vault');
      onProgress?.call('Preparing passcode');
      final keyfile = await store.preparePortableKeyfile(key, passcode);
      if (isCancelled?.call() == true) throw StateError('Restore cancelled');
      await requireFresh();
      await ready.writeAsString(
        jsonEncode({'version': 1, 'keyfile': await _fingerprint(keyfile)}),
        flush: true,
      );
      onProgress?.call('Saving restored vault');
      // From here the moves are durable and must not be cancelled by the UI.
      onCommitting?.call();
      await resume();
    } finally {
      // Once ready, startup owns completion. Never remove the only prepared pair
      // after a failed final move; the original ZIP also remains untouched.
      if (await pending.exists() && !await ready.exists()) {
        await pending.delete(recursive: true);
      }
    }
  }

  Future<bool> resume() async {
    // Startup and commit call this before any other restore can be active.
    await for (final entry in store.dir.list()) {
      if (entry is Directory &&
          entry.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('.portable-stage-')) {
        await entry.delete(recursive: true);
      }
    }
    if (!await pending.exists()) return false;
    final ready = File('${pending.path}/ready');
    if (!await ready.exists()) {
      await pending.delete(recursive: true);
      return false;
    }
    if (await ready.length() > 4096) {
      throw const FormatException('Invalid restore journal');
    }
    final record = jsonDecode(await ready.readAsString());
    if (record is! Map<String, dynamic> ||
        record['version'] != 1 ||
        record['keyfile'] is! String) {
      throw const FormatException('Invalid restore journal');
    }
    final preparedKey = File('${pending.path}/vault.keyfile.json');
    if (await store.keyfile.exists() &&
        await _fingerprint(store.keyfile) != record['keyfile']) {
      throw const FormatException(
        'Existing credentials differ; restore preserved',
      );
    }
    if (await preparedKey.exists()) {
      if (await _fingerprint(preparedKey) != record['keyfile']) {
        throw const FormatException(
          'Prepared credentials differ; restore preserved',
        );
      }
    } else if (!await store.keyfile.exists()) {
      throw const FormatException(
        'Prepared credentials missing; restore preserved',
      );
    }
    final preparedVault = Directory('${pending.path}/vault');
    if (await preparedVault.exists()) {
      if (await target.exists()) {
        if (!await target.list().isEmpty) {
          throw const FormatException(
            'Vault is no longer empty; restore preserved',
          );
        }
        await target.delete();
      }
      await preparedVault.rename(target.path);
    } else if (!await target.exists() || await target.list().isEmpty) {
      // Nothing was moved yet and the prepared media is gone: adopting the
      // keyfile now would finish with a vault of nothing.
      throw const FormatException('Prepared media missing; restore preserved');
    }
    if (await preparedKey.exists()) {
      await preparedKey.rename(store.keyfile.path);
    }
    await pending.delete(recursive: true);
    return true;
  }
}
