import 'package:sodium/sodium_sumo.dart';

import 'cast/cast_backend.dart';
import 'cast/cast_controller.dart';
import 'crypto/vault_crypto.dart';
import 'gallery/preview.dart';
import 'media/media_server.dart';
import 'sync/sync_controller.dart';
import 'vault/master_key_store.dart';
import 'vault/vault.dart';

/// Everything that exists only while the vault is unlocked.
class Session {
  Session({
    required this.vault,
    required this.server,
    required this.cast,
    required this.store,
  }) : sync = SyncController(vault) {
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
    CastBackend backend,
  ) async {
    Vault? vault;
    try {
      vault = Vault(VaultCrypto(store.sodium), key, await Vault.defaultDir());
      return Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, backend),
        store: store,
      );
    } catch (_) {
      (vault?.dispose ?? key.dispose)();
      rethrow;
    }
  }
}
