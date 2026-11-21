import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../limits.dart' as limits;
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
    this.skipped = 0,
  });

  final int pushed;
  final int pulled;
  final int remoteTotal;
  final int deleted;

  /// NAS files that did not authenticate with this vault's key: damaged, or
  /// written by another vault. They are left exactly as they are.
  final int skipped;

  @override
  String toString() =>
      'Synced: $pushed uploaded, $pulled downloaded · '
      '${deleted == 0 ? '' : '$deleted deleted · '}$remoteTotal on NAS'
      '${skipped == 0 ? '' : ' · $skipped NAS ${skipped == 1 ? 'file' : 'files'} skipped (unreadable)'}';
}

/// Result of [SyncService.renameRemote].
class RenameReport {
  const RenameReport({required this.candidates, required this.renamed});

  /// NAS captures that kept their readable name and are on the phone too.
  final int candidates;
  final int renamed;
}

/// The caller owns session serialization, including verification and cancellation.
class SyncService {
  SyncService(
    this.vault,
    this.dav, {
    this.isCancelled,
    this.useRandomNames = false,
  });

  /// A collection listing larger than this is not a vault we made.
  static const maxListingBytes = limits.maxListingBytes;

  /// Bound for a download whose size the server did not report.
  static const maxUnknownSizeBytes = 4 * 1024 * 1024 * 1024;
  final bool Function()? isCancelled;

  /// New uploads get a random NAS name (decision 026). Captures already on the
  /// NAS keep their name. Off until the recovery tool reads the mapping.
  final bool useRandomNames;
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

  static final _randomName = RegExp(r'^[0-9a-f]{32}\.shtr$');
  bool _looksRandom(String name) => _randomName.hasMatch(name);

  /// The phone capture with no NAS copy whose bytes equal [remoteCopy], if any.
  Future<String?> _phoneCopyOf(
    File remoteCopy,
    Map<String, File> local,
    Map<String, RemoteEntry> remote,
    Set<String> skip,
  ) async {
    for (final e in local.entries) {
      if (remote.containsKey(e.key) || skip.contains(e.key)) continue;
      if (await _same(e.value, remoteCopy)) return e.key;
    }
    return null;
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
      final incomingCatalog = await _catalog(entries, work);
      var names = vault.catalog.remoteNames;
      if (incomingCatalog != null && !await vault.catalog.file.exists()) {
        names = await vault.catalog.remoteNamesOf(incomingCatalog);
      }
      final remote = {
        for (final e in entries)
          if (e.name.endsWith('.shtr')) names.localFor(e.name): e,
      };
      final incoming = <String, File>{};
      // Validate the entire prospective restore before any upload, removal or adoption.
      // A trashed capture keeps its NAS copy and must not come back as a new one.
      final held = (await vault.trashedAt()).keys.toSet();
      final rebuilt = <String, String>{};
      // NAS files that failed authentication: never adopted, uploaded over or
      // removed, and they do not stop the other captures.
      final skipped = <String>{};
      for (final entry in remote.entries) {
        if (held.contains(entry.key)) continue;
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
          entry.value.name,
          file,
          maxBytes: entry.value.size > 0
              ? entry.value.size
              : maxUnknownSizeBytes,
        );
        try {
          await _authenticate(file);
        } on Exception {
          // Without a catalog that proves this folder is ours, an unreadable
          // file may mean another vault's folder: stop before uploading into
          // it. Cancellation is a StateError and always ends the pass.
          if (incomingCatalog == null) rethrow;
          skipped.add(entry.key);
          await file.delete();
          continue;
        }
        if (own != null && !await _same(own, file)) {
          throw BackupConflictException(entry.key);
        }
        if (own == null && _looksRandom(entry.key)) {
          // A mapping lost to an older app version: the same ciphertext on the
          // phone proves this is that capture, not a new one.
          final match = await _phoneCopyOf(file, local, remote, {
            ...deleted,
            ...rebuilt.keys,
          });
          if (match != null) {
            rebuilt[match] = entry.key;
            await file.delete();
            continue;
          }
        }
        if (own == null && !deleted.contains(entry.key)) {
          incoming[entry.key] = file;
        } else {
          await file.delete();
        }
      }
      _checkCancelled();
      if (rebuilt.isNotEmpty) {
        names = await vault.catalog.adoptRemoteNames(rebuilt);
        for (final e in rebuilt.entries) {
          final entry = remote.remove(e.value);
          if (entry != null) remote[e.key] = entry;
        }
      }
      deleted.addAll(await vault.deletedNames());
      if (incomingCatalog != null) await vault.catalog.restore(incomingCatalog);
      names = vault.catalog.remoteNames;
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
        if (skipped.contains(name)) continue;
        final gone = remote.remove(name);
        if (gone != null) {
          await dav.delete(gone.name);
          removed++;
        }
      }
      if (useRandomNames) {
        names = await vault.catalog.assignRemoteNames([
          for (final e in local.entries)
            if (!deleted.contains(e.key) && !remote.containsKey(e.key)) e.key,
        ]);
      }
      var pushed = 0;
      for (final entry in local.entries) {
        _checkCancelled();
        // A capture deleted during this pass is journaled; the next pass
        // replays it instead of failing here on a missing file.
        if (!await entry.value.exists()) continue;
        if (!deleted.contains(entry.key) && !remote.containsKey(entry.key)) {
          try {
            await dav.putStaged(names.remoteFor(entry.key), entry.value);
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
        if (skipped.contains(name)) continue;
        if (remote.containsKey(name) || local.containsKey(name)) {
          await dav.delete(remote[name]?.name ?? names.remoteFor(name));
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
      confirmedMedia = {...local.keys, ...remote.keys}
        ..removeAll(deleted)
        ..removeAll(skipped);
      return SyncReport(
        pushed: pushed,
        pulled: pulled,
        remoteTotal: ({
          ...remote.keys,
          ...local.keys,
        }..removeAll(deleted)).length,
        deleted: removed,
        skipped: skipped.length,
      );
    } finally {
      await work.delete(recursive: true);
    }
  }

  /// Gives captures that already sit on the NAS under their readable name a
  /// random one (decision 026, slice 5). Only captures with an identical copy
  /// on the phone qualify, so nothing is renamed on trust. The mapping is saved
  /// in the catalog first, each file is then moved on the server without
  /// overwriting, and a closing listing must show every new name at the same
  /// size before the catalog is uploaded by a normal sync. An interrupted run
  /// resumes with the saved mapping. [dryRun] only counts.
  Future<RenameReport> renameRemote({bool dryRun = false}) async {
    await vault.catalog.load();
    final deleted = await vault.deletedNames();
    final held = (await vault.trashedAt()).keys.toSet();
    final local = {
      for (final f in await vault.list()) f.uri.pathSegments.last: f,
    };
    await dav.ensureCollection();
    final entries = await dav.list(maxBytes: maxListingBytes);
    var names = vault.catalog.remoteNames;
    final todo = <String, RemoteEntry>{};
    for (final e in entries) {
      if (!e.name.endsWith('.shtr') ||
          e.name.startsWith(WebDavClient.stagePrefix) ||
          names.localFor(e.name) != e.name ||
          _looksRandom(e.name) ||
          deleted.contains(e.name) ||
          held.contains(e.name)) {
        continue;
      }
      final own = local[e.name];
      if (own == null || e.size != await own.length()) continue;
      todo[e.name] = e;
    }
    if (dryRun || todo.isEmpty) {
      return RenameReport(candidates: todo.length, renamed: 0);
    }
    names = await vault.catalog.assignRemoteNames([
      for (final k in todo.keys)
        if (names.remoteFor(k) == k) k,
    ]);
    for (final e in todo.entries) {
      _checkCancelled();
      await dav.move(e.value.name, names.remoteFor(e.key), replace: false);
    }
    final after = {
      for (final e in await dav.list(maxBytes: maxListingBytes)) e.name: e,
    };
    for (final e in todo.entries) {
      final moved = after[names.remoteFor(e.key)];
      if (moved == null ||
          moved.size != e.value.size ||
          after.containsKey(e.key)) {
        throw StateError('Rename could not be confirmed for ${e.key}');
      }
    }
    // Uploads the catalog that carries the new names.
    await sync();
    return RenameReport(candidates: todo.length, renamed: todo.length);
  }

  /// Reads every remote copy without repairing, deleting or adopting any original.
  Future<BackupVerificationReport> verify({
    void Function(int checked, int total)? onProgress,
  }) async {
    final work = await _work();
    try {
      final deleted = await vault.deletedNames();
      final held = (await vault.trashedAt()).keys.toSet();
      final local = {
        for (final f
            in await vault.dir
                .list()
                .where((f) => f is File && f.path.endsWith('.shtr'))
                .cast<File>()
                .toList())
          if (!deleted.contains(f.uri.pathSegments.last) &&
              !held.contains(f.uri.pathSegments.last))
            f.uri.pathSegments.last: f,
      };
      final entries = await dav.list(maxBytes: maxListingBytes);
      await vault.catalog.load();
      final names = vault.catalog.remoteNames;
      final remote = {
        for (final entry in entries)
          if (entry.name.endsWith('.shtr')) names.localFor(entry.name): entry,
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
        await dav.get(
          remote[name]!.name,
          file,
          maxBytes: size > 0 ? size : null,
        );
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
