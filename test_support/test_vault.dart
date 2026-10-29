import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

/// Seeds only the development app's sandbox; release builds have a different ID.
Future<Vault> openTestVault() async {
  // Automatic sync in development tests must never reuse real NAS settings.
  await const SyncSettings(url: '', username: '', password: '').save();
  final sodium = await SodiumSumoInit.init();
  final store = MasterKeyStore(sodium, await getApplicationDocumentsDirectory());
  var key = await store.cachedKey();
  if (key == null) {
    key = sodium.crypto.secretBox.keygen();
    await const FlutterSecureStorage().write(
      key: MasterKeyStore.cacheName,
      value: base64Encode(key.extractBytes()),
    );
  }
  final dir = await Vault.defaultDir();
  // Earlier test files may leave a catalog sealed under a different key, which
  // the app reports as unreadable tags. A fresh test vault starts without one.
  final catalog = File('${dir.path}/${PrivateCatalog.fileName}');
  if (await catalog.exists()) await catalog.delete();
  return Vault(VaultCrypto(sodium), key, dir);
}
