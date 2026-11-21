import 'dart:async';
import 'dart:io';

import 'package:sodium/sodium_sumo.dart';

import 'camera/locked_capture_store.dart';
import 'cast/cast_backend.dart';
import 'cast/cast_controller.dart';
import 'crypto/pending_crypto.dart';
import 'crypto/vault_crypto.dart';
import 'gallery/preview.dart';
import 'media/media_server.dart';
import 'sync/sync_controller.dart';
import 'vault/master_key_store.dart';
import 'vault/pending_key_store.dart';
import 'vault/vault.dart';

/// Everything that exists only while the vault is unlocked.
class Session {
  Session({
    required this.vault,
    required this.server,
    required this.cast,
    required this.store,
    // Decision 026: new NAS uploads get random file names. Device tests that
    // read capture names on a fake server turn this off.
    bool randomRemoteNames = true,
    Future<int>? lockedPublished,
  }) : _lockedPublished = lockedPublished ?? Future.value(0),
       sync = SyncController(vault, useRandomNames: randomRemoteNames) {
    vault.catalog.addListener(_catalogChanged);
  }

  void _catalogChanged() {
    // Only committed edits need another pass. Restore/load notify the UI too;
    // the catalog distinguishes edits through its revision counter.
    if (_catalogRevision != vault.catalog.revision) {
      _catalogRevision = vault.catalog.revision;
      sync.sync();
    }
  }

  int _catalogRevision = 0;

  final Vault vault;
  final MediaServer server;
  final CastController cast;
  final MasterKeyStore store;
  final SyncController sync;

  /// How many captures taken on the lock screen camera were published at this
  /// unlock (decision 028). Never shown while locked.
  final Future<int> _lockedPublished;
  var _lockedTaken = false;

  /// The count once per session, so a rebuilt screen does not repeat the notice.
  Future<int> takeLockedPublished() {
    if (_lockedTaken) return Future.value(0);
    _lockedTaken = true;
    return _lockedPublished;
  }

  /// Decrypted thumbnails, bounded and cleared on every lock (decision 040).
  late final previews = PreviewCache(
    (item) => loadPreview(vault, server, item),
  );

  /// Entering the lock gate ends the cast session, which closes the LAN server
  /// and revokes its tokens, and drops decrypted previews from memory.
  Future<void> lock() async {
    previews.clear();
    await cast.stop();
  }

  Future<void> close() async {
    await cast.stop();
    cast.dispose();
    previews.dispose();
    await server.close();
    await sync.close();
    vault.catalog.removeListener(_catalogChanged);
    await vault.catalog.close();
    vault.dispose();
  }

  /// Owns [key] from here on: a failure before the session exists disposes it.
  static Future<Session> start(
    MasterKeyStore store,
    SecureKey key,
    CastBackend backend, {
    Directory? vaultDir,
  }) async {
    Vault? vault;
    try {
      vault = Vault(
        VaultCrypto(store.sodium),
        key,
        vaultDir ?? await Vault.defaultDir(),
      );
      try {
        // Captures past their 30 days go now. A failure retries next unlock.
        await vault.purgeTrash();
      } catch (_) {}
      // Key pair and publication of captures taken while locked (decision
      // 028). Not awaited so unlock never waits for it; a failure or a key
      // disposed by an early lock leaves the work for the next unlock.
      final published = _publishLocked(store, key, vault).catchError((_) => 0);
      return Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, backend),
        store: store,
        lockedPublished: published,
      );
    } catch (_) {
      (vault?.dispose ?? key.dispose)();
      rethrow;
    }
  }

  static Future<int> _publishLocked(
    MasterKeyStore store,
    SecureKey key,
    Vault vault,
  ) async {
    final keys = PendingKeyStore(store.sodium, store.dir);
    await keys.ensure(key);
    final locked = LockedCaptureStore(PendingCrypto(store.sodium), vault.dir);
    if (await locked.count() == 0) return 0;
    final publicKey = await keys.publicKey();
    if (publicKey == null) return 0;
    final secret = await keys.secretKey(key);
    try {
      return (await locked.publishAll(vault, publicKey, secret)).published;
    } finally {
      secret.dispose();
    }
  }
}
