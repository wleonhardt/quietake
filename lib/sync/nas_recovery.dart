import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../backup/restore_transaction.dart';
import '../compat/legacy_identity.dart';
import '../library/private_catalog.dart';
import '../vault/backup_passphrase.dart';
import '../vault/master_key_store.dart';
import '../vault/vault.dart';
import '../crypto/vault_crypto.dart';
import 'webdav_client.dart';

/// Caller owns the foreground lease. All remote restore operations are read-only.
class NasRecovery {
  NasRecovery(this.store, this.dav, {this.isCancelled});
  final MasterKeyStore store;
  final WebDavClient dav;
  final bool Function()? isCancelled;
  void _check() {
    if (isCancelled?.call() == true) throw StateError('Recovery cancelled');
  }

  static const _name = MasterKeyStore.recoveryBoxName;
  String _tag(String? value) {
    if (value == null ||
        !RegExp(r'^"[^"\r\n]*"$').hasMatch(value) ||
        value.length > 256) {
      throw const FormatException(
        'NAS needs strong ETags for safe recovery changes',
      );
    }
    return value;
  }

  Future<void> change(
    Vault vault,
    String currentPasscode,
    String? phrase,
  ) async {
    if (phrase != null) {
      BackupPassphrase.validate(phrase);
      if (phrase == currentPasscode) {
        throw const FormatException('Use a separate backup passphrase');
      }
    }
    final key = await store.unlockWithPasscode(currentPasscode);
    Directory? work;
    String? lease;
    try {
      if (!vault.matchesKey(key)) {
        throw const FormatException('Open vault identity changed');
      }
      _check();
      lease = await dav.lockCollection();
      LegacyIdentity.rejectBackupWrites((await dav.list()).map((e) => e.name));
      // Key management changes only recovery material, never capture backup state.
      await for (final entry in vault.dir.list()) {
        if (entry is Directory &&
            entry.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last
                .startsWith('.recovery-work-')) {
          await entry.delete(recursive: true);
        }
      }
      final catalog = await dav.readSmall(
        PrivateCatalog.fileName,
        PrivateCatalog.maxBytes * 2,
      );
      if (catalog == null) {
        throw const FormatException('Sync a saved backup first');
      }
      work = await vault.dir.createTemp('.recovery-work-');
      final incoming = await File('${work.path}/catalog')
          .writeAsBytes(catalog.bytes);
      await vault.catalog.validate(incoming);
      _tag(catalog.etag);
      String? existingTag;
      final existing = await dav.readSmall(
        _name,
        MasterKeyStore.recoveryBoxLimit,
      );
      if (existing != null) {
        MasterKeyStore.validateBackupBox(existing.bytes);
        existingTag = _tag(existing.etag);
      }
      _check();
      await _cleanOwned(vault, lease);
      if (phrase == null) {
        if (existing != null) {
          _check();
          await dav.deleteConditional(_name, etag: existingTag!, lease: lease);
        }
        return;
      }
      final box = await store.wrapBackupKey(key, phrase);
      _check();
      final upload = await File('${work.path}/box')
          .writeAsString(box, flush: true);
      final stage =
          '.quietake-recovery-${base64Url.encode(store.sodium.randombytes.buf(18))}';
      await _record(vault, stage, true);
      try {
        _check();
        await dav.put(stage, upload, lease: lease);
        _check();
        await dav.move(
          stage,
          _name,
          replace: existing != null,
          etag: existingTag,
          lease: lease,
        );
        await _record(vault, stage, false);
      } finally {
        try {
          await dav.delete(stage, lease: lease);
          await _record(vault, stage, false);
        } catch (_) {
          // Only the durable owned marker may authorize a later staging cleanup.
        }
      }
    } finally {
      if (lease != null) {
        try {
          await dav.unlockCollection(lease);
        } catch (_) {}
      }
      key.dispose();
      if (work != null && await work.exists()) {
        await work.delete(recursive: true);
      }
    }
  }

  String get _target => sha256
      .convert(utf8.encode('${dav.base}\u0000${dav.username}'))
      .toString();
  File _journal(Vault vault) =>
      File('${vault.dir.path}/.recovery-uploads.json');
  Future<Map<String, dynamic>> _records(Vault vault) async {
    final file = _journal(vault);
    if (!await file.exists()) return {};
    if (await file.length() > 32768) {
      throw const FormatException('Invalid owned staging record');
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic> ||
        value.length > 64 ||
        value.values.any(
          (v) =>
              v is! String ||
              !RegExp(r'^\.quietake-recovery-[A-Za-z0-9_-]{24}$').hasMatch(v),
        )) {
      throw const FormatException('Invalid owned staging record');
    }
    return value;
  }

  Future<void> _record(Vault vault, String name, bool add) async {
    final records = await _records(vault);
    if (add) {
      if (records.length >= 64) {
        throw const FormatException('Clean previous recovery staging first');
      }
      records[_target] = name;
    } else if (records[_target] == name) {
      records.remove(_target);
    }
    final file = _journal(vault);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(jsonEncode(records), flush: true);
    await pending.rename(file.path);
  }

  Future<void> _cleanOwned(Vault vault, String lease) async {
    final name = (await _records(vault))[_target] as String?;
    if (name != null) {
      _check();
      await dav.delete(name, lease: lease);
      await _record(vault, name, false);
    }
  }

  Future<void> restore(
    String phrase,
    String newPasscode, {
    void Function(String)? onProgress,
    void Function()? onCommitting,
  }) async {
    final transaction = RestoreTransaction(store);
    await transaction.requireFresh();
    if (newPasscode.length < MasterKeyStore.minPasscodeLength) {
      throw const FormatException(MasterKeyStore.passcodeTooShort);
    }
    final entries = await dav.list(maxBytes: 16 * 1024 * 1024);
    final names = entries.map((e) => e.name).toSet();
    final legacy =
        names.contains(LegacyIdentity.catalog) ||
        names.contains(LegacyIdentity.recoveryBox);
    final current =
        names.contains(PrivateCatalog.fileName) || names.contains(_name);
    if (legacy && current) {
      throw const FormatException(
        'Mixed backup identities; choose an unmixed backup',
      );
    }
    final catalogName = legacy
        ? LegacyIdentity.catalog
        : PrivateCatalog.fileName;
    final boxName = legacy ? LegacyIdentity.recoveryBox : _name;
    if (!names.contains(catalogName) || !names.contains(boxName)) {
      throw const FormatException('Incomplete backup recovery pair');
    }
    final box = await dav.readSmall(boxName, MasterKeyStore.recoveryBoxLimit);
    if (box == null) {
      throw const FormatException('No passphrase recovery file found');
    }
    final key = await store.openBackupKey(box.bytes, phrase);
    Directory? work;
    Vault? staged;
    try {
      _check();
      final media = entries.where((e) => e.name.endsWith('.shtr')).toList();
      if (media.length > 10000 ||
          media.map((e) => e.name).toSet().length != media.length) {
        throw const FormatException('Unsupported backup file count');
      }
      work = await store.dir.createTemp('.portable-stage-');
      staged = Vault(VaultCrypto(store.sodium), key.copy(), work);
      await dav.get(
        catalogName,
        staged.catalog.file,
        maxBytes: PrivateCatalog.maxBytes * 2,
      );
      await staged.catalog.validate(staged.catalog.file);
      for (var i = 0; i < media.length; i++) {
        _check();
        onProgress?.call(
          'Checking encrypted capture ${i + 1} of ${media.length}',
        );
        final file = File('${work.path}/${media[i].name}');
        await dav.get(
          media[i].name,
          file,
          authenticate: (bytes) async {
            await staged!.crypto.decrypt(bytes, key).map((plain) {
              _check();
              return plain;
            }).drain<void>();
          },
        );
      }
      _check();
      staged.dispose();
      staged = null;
      work = await work.rename('${work.path}.validated');
      await transaction.commit(
        work,
        key,
        newPasscode,
        isCancelled: isCancelled,
        onProgress: onProgress,
        onCommitting: onCommitting,
      );
    } finally {
      staged?.dispose();
      key.dispose();
      if (work != null && await work.exists()) {
        await work.delete(recursive: true);
      }
    }
  }
}
