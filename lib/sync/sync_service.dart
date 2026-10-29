import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../vault/vault.dart';
import '../compat/legacy_identity.dart';
import '../library/private_catalog.dart';
import 'webdav_client.dart';

class BackupCheckException implements Exception {
  const BackupCheckException(this.message);
  final String message;
}

class BackupConflictException implements Exception {
  const BackupConflictException(this.name);
  final String name;
}

class BackupVerificationReport {
  const BackupVerificationReport({
    required this.media,
    required this.catalog,
    required this.checkedAt,
  });
  final int media;
  final bool catalog;
  final DateTime checkedAt;
}

/// Outcome of one [SyncService.sync] run. Transfer success is not remote verification.
class SyncReport {
  const SyncReport({
    required this.pushed,
    required this.pulled,
    required this.remoteTotal,
    required this.deleted,
  });

  final int pushed;
  final int pulled;
  final int remoteTotal;
  final int deleted;

  @override
  String toString() =>
      'Synced: $pushed uploaded, $pulled downloaded · '
      '${deleted == 0 ? '' : '$deleted deleted · '}$remoteTotal on NAS';
}

/// The caller owns session serialization, including verification and cancellation.
class SyncService {
  SyncService(this.vault, this.dav, {this.isCancelled});

  /// A collection listing larger than this is not a vault we made.
  static const maxListingBytes = 16 * 1024 * 1024;
  final bool Function()? isCancelled;
  final Vault vault;
  final WebDavClient dav;
  String? authenticatedCatalogHash;
  Set<String> confirmedMedia = const {};

  Future<String> _ciphertextHash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  void _checkCancelled() {
    if (isCancelled?.call() == true) {
      throw StateError('Backup operation cancelled');
    }
  }

  Future<void> _authenticate(File file) => vault.read(file).map((bytes) {
    _checkCancelled();
    return bytes;
  }).drain<void>();

  Future<Directory> _work() async {
    _checkCancelled();
    await for (final entry in vault.dir.list()) {
      if (entry is Directory &&
          entry.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('.backup-work-')) {
        await entry.delete(recursive: true);
      }
    }
    return vault.dir.createTemp('.backup-work-');
  }

  Future<bool> _same(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    Future<Uint8List> digest(File file) => vault
        .crypto
        .sodium
        .crypto
        .genericHash
        .stream(messages: file.openRead().map(Uint8List.fromList));
    return listEquals(await digest(a), await digest(b));
  }

  Future<File?> _catalog(List<RemoteEntry> entries, Directory work) async {
    LegacyIdentity.rejectBackupWrites(entries.map((e) => e.name));
    final matches = entries.where((e) => e.name == PrivateCatalog.fileName);
    if (matches.isEmpty) return null;
    if (matches.single.size > PrivateCatalog.maxBytes * 2) {
      throw const FormatException('Remote private library is too large');
    }
    final incoming = File('${work.path}/${PrivateCatalog.fileName}');
    await dav.get(
      PrivateCatalog.fileName,
      incoming,
      maxBytes: PrivateCatalog.maxBytes * 2,
    );
    await vault.catalog.validate(incoming);
    authenticatedCatalogHash = await _ciphertextHash(incoming);
    _checkCancelled();
    return incoming;
  }

  Future<SyncReport> sync() async {
    final work = await _work();
    try {
      await vault.catalog.load();
      final deleted = await vault.deletedNames();
      final local = {
        for (final f in await vault.list()) f.uri.pathSegments.last: f,
      };
      await dav.ensureCollection();
      final entries = await dav.list(maxBytes: maxListingBytes);
      // Staging names are ours by construction; a crashed pass leaves them.
      for (final entry in entries) {
        if (entry.name.startsWith(WebDavClient.stagePrefix)) {
          await dav.delete(entry.name);
        }
      }
      final remote = {
        for (final e in entries)
          if (e.name.endsWith('.shtr')) e.name: e,
      };
      final incomingCatalog = await _catalog(entries, work);
      final incoming = <String, File>{};
      // Validate the entire prospective restore before any upload, removal or adoption.
      for (final entry in remote.entries) {
        final own = local[entry.key];
        final conflict = own != null && entry.value.size != await own.length();
        if (incomingCatalog != null &&
            !conflict &&
            (own != null || deleted.contains(entry.key))) {
          continue;
        }
        final file = File('${work.path}/${entry.key}');
        // The listing bounds the download; a server that omits sizes says 0.
        await dav.get(
          entry.key,
          file,
          maxBytes: entry.value.size > 0 ? entry.value.size : null,
        );
        await _authenticate(file);
        if (own != null && !await _same(own, file)) {
          throw BackupConflictException(entry.key);
        }
        if (own == null && !deleted.contains(entry.key)) {
          incoming[entry.key] = file;
        } else {
          await file.delete();
        }
      }
      _checkCancelled();
      deleted.addAll(await vault.deletedNames());
      if (incomingCatalog != null) await vault.catalog.restore(incomingCatalog);
      var pulled = 0;
      for (final entry in incoming.entries) {
        _checkCancelled();
        if (deleted.contains(entry.key)) continue;
        final target = File('${vault.dir.path}/${entry.key}');
        if (!await target.exists()) {
          await entry.value.rename(target.path);
          pulled++;
        }
      }
      var removed = 0;
      for (final name in deleted) {
        _checkCancelled();
        if (remote.remove(name) != null) {
          await dav.delete(name);
          removed++;
        }
      }
      var pushed = 0;
      for (final entry in local.entries) {
        _checkCancelled();
        // A capture deleted during this pass is journaled; the next pass
        // replays it instead of failing here on a missing file.
        if (!await entry.value.exists()) continue;
        if (!deleted.contains(entry.key) && !remote.containsKey(entry.key)) {
          try {
            await dav.putStaged(entry.key, entry.value);
          } on WebDavException catch (e) {
            // Appeared on the NAS since the listing: keep both copies.
            if (e.status == 412) throw BackupConflictException(entry.key);
            rethrow;
          }
          pushed++;
        }
      }
      final later = (await vault.deletedNames()).difference(deleted);
      for (final name in later) {
        await vault.delete(File('${vault.dir.path}/$name'));
        if (remote.containsKey(name) || local.containsKey(name)) {
          await dav.delete(name);
          removed++;
        }
      }
      deleted.addAll(later);
      await vault.catalog.forgetDeleted();
      // Even a media-empty backup needs authenticated ownership for recovery.
      await vault.catalog.ensurePersisted();
      final snapshot = await vault.catalog.snapshot();
      if (snapshot != null) {
        try {
          if (incomingCatalog == null ||
              !await incomingCatalog.exists() ||
              !await _same(snapshot, incomingCatalog)) {
            final current = entries
                .where((e) => e.name == PrivateCatalog.fileName)
                .firstOrNull;
            try {
              await dav.putStaged(
                PrivateCatalog.fileName,
                snapshot,
                replace: current != null,
                etag: current?.etag,
              );
            } on WebDavException catch (e) {
              // Someone else wrote the catalog meanwhile: never overwrite it.
              if (e.status == 412) {
                throw const BackupConflictException(PrivateCatalog.fileName);
              }
              rethrow;
            }
          }
          authenticatedCatalogHash = await _ciphertextHash(snapshot);
        } finally {
          await snapshot.parent.delete(recursive: true);
        }
      }
      _checkCancelled();
      confirmedMedia = {...local.keys, ...remote.keys}..removeAll(deleted);
      return SyncReport(
        pushed: pushed,
        pulled: pulled,
        remoteTotal: ({
          ...remote.keys,
          ...local.keys,
        }..removeAll(deleted)).length,
        deleted: removed,
      );
    } finally {
      await work.delete(recursive: true);
    }
  }

  /// Reads every remote copy without repairing, deleting or adopting any original.
  Future<BackupVerificationReport> verify({
    void Function(int checked, int total)? onProgress,
  }) async {
    final work = await _work();
    try {
      final deleted = await vault.deletedNames();
      final local = {
        for (final f
            in await vault.dir
                .list()
                .where((f) => f is File && f.path.endsWith('.shtr'))
                .cast<File>()
                .toList())
          if (!deleted.contains(f.uri.pathSegments.last))
            f.uri.pathSegments.last: f,
      };
      final entries = await dav.list(maxBytes: maxListingBytes);
      final remote = {
        for (final entry in entries)
          if (entry.name.endsWith('.shtr')) entry.name: entry,
      };
      if (deleted.any(remote.containsKey)) {
        throw const BackupCheckException(
          'NAS deletions are still pending. Sync before checking.',
        );
      }
      if (local.keys.any((name) => !remote.containsKey(name))) {
        throw const BackupCheckException(
          'Some phone captures are missing from NAS. Sync before checking.',
        );
      }
      if (remote.isEmpty &&
          !entries.any((entry) => entry.name == PrivateCatalog.fileName)) {
        throw const BackupCheckException(
          'No encrypted backup files found. Capture or import media, then sync.',
        );
      }
      final catalog = await _catalog(entries, work);
      final ownCatalog = vault.catalog.file;
      if (await ownCatalog.exists() && catalog == null) {
        throw const BackupCheckException(
          'NAS has no organization file for this vault yet. Sync before checking.',
        );
      }
      if (catalog != null &&
          await ownCatalog.exists() &&
          !await _same(ownCatalog, catalog)) {
        throw const BackupConflictException(PrivateCatalog.fileName);
      }
      var checked = 0;
      onProgress?.call(checked, remote.length);
      for (final name in remote.keys) {
        final file = File('${work.path}/$name');
        final size = remote[name]!.size;
        await dav.get(name, file, maxBytes: size > 0 ? size : null);
        await _authenticate(file);
        final own = local[name];
        if (own != null && !await _same(own, file)) {
          throw BackupConflictException(name);
        }
        await file.delete();
        onProgress?.call(++checked, remote.length);
      }
      _checkCancelled();
      confirmedMedia = remote.keys.toSet();
      return BackupVerificationReport(
        media: remote.length,
        catalog: catalog != null,
        checkedAt: DateTime.now(),
      );
    } finally {
      await work.delete(recursive: true);
    }
  }
}
