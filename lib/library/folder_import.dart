import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../vault/vault.dart';
import 'import_media.dart';

/// One file in a folder chosen for import.
class FolderEntry {
  const FolderEntry({required this.id, required this.name});

  /// Stable within the folder, such as the file name or a document ID.
  final String id;
  final String name;
}

/// What a platform folder picker provides. Implementations never modify the
/// folder; [copyTo] writes only inside the private [directory] it is given.
abstract class FolderSource {
  /// Opaque, stable identity of the folder, used only to key the resume ledger.
  String get identity;
  Future<List<FolderEntry>> list();
  Future<File> copyTo(FolderEntry entry, Directory directory);
}

/// Source entry IDs already imported or skipped as exact duplicates, stored
/// encrypted in the vault directory and keyed by a hash of the folder identity.
class ImportLedger {
  ImportLedger(this.vault, String identity)
    : file = File('${vault.dir.path}/.import/${_key(vault, identity)}.ledger');
  final Vault vault;
  final File file;
  final Set<String> done = {};

  static String _key(Vault vault, String identity) => vault.crypto.sodium.crypto
      .genericHash(message: utf8.encode(identity), outLen: 16)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Future<void> load() async {
    done.clear();
    if (!await file.exists()) return;
    final bytes = <int>[];
    await for (final chunk in vault.read(file)) {
      bytes.addAll(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! List || value.any((e) => e is! String)) {
      throw const FormatException('Unsupported import ledger');
    }
    done.addAll(value.cast<String>());
  }

  Future<void> save() async {
    await file.parent.create(recursive: true);
    await vault.writeMetadata(
      file,
      utf8.encode(jsonEncode(done.toList()..sort())),
    );
  }
}

class FolderImportSummary {
  const FolderImportSummary({
    required this.total,
    required this.alreadyDone,
    required this.imported,
    required this.duplicates,
    required this.failed,
    required this.cancelled,
  });

  /// Supported files found in the folder.
  final int total;

  /// Skipped because an earlier run already handled them.
  final int alreadyDone;
  final int imported;
  final int duplicates;
  final int failed;
  final int cancelled;
}

class FolderImport {
  FolderImport(this.vault, this.staging, {MediaImporter? importer})
    : _importer = importer ?? MediaImporter(vault, staging);
  final Vault vault;
  final Directory staging;
  final MediaImporter _importer;
  static const maxFiles = 10000;
  static const chunkSize = 20;
  static const _supported = ['jpg', 'jpeg', 'png', 'mp4'];

  static bool isSupported(String name) =>
      _supported.contains(name.split('.').last.toLowerCase());

  Future<FolderImportSummary> run(
    FolderSource source, {
    bool Function()? isCancelled,
    void Function(int handled, int total)? onProgress,
  }) async {
    final entries = [
      for (final e in await source.list())
        if (isSupported(e.name)) e,
    ];
    if (entries.length > maxFiles) {
      throw const FormatException('Choose a folder with up to 10,000 files.');
    }
    final ledger = ImportLedger(vault, source.identity);
    await ledger.load();
    final pending = [
      for (final e in entries)
        if (!ledger.done.contains(e.id)) e,
    ];
    var handled = entries.length - pending.length;
    var imported = 0, duplicates = 0, failed = 0, cancelled = 0;
    final digests = <int, Set<String>>{};
    onProgress?.call(handled, entries.length);
    for (var i = 0; i < pending.length; i += chunkSize) {
      if (isCancelled?.call() == true) {
        cancelled += pending.length - i;
        break;
      }
      final chunk = pending.skip(i).take(chunkSize).toList();
      final inputs = <ImportInput>[];
      for (final entry in chunk) {
        try {
          final copy = await source.copyTo(entry, staging);
          inputs.add(ImportInput(name: entry.name, path: copy.path));
        } catch (_) {
          inputs.add(
            ImportInput(name: entry.name, error: 'Could not read this file.'),
          );
        }
      }
      final results = await _importer.run(
        inputs,
        isCancelled: isCancelled,
        knownDigests: digests,
      );
      for (var j = 0; j < results.length; j++) {
        switch (results[j].status) {
          case ImportStatus.imported:
            imported++;
            ledger.done.add(chunk[j].id);
          case ImportStatus.duplicate:
            duplicates++;
            ledger.done.add(chunk[j].id);
          case ImportStatus.failed:
            failed++;
          case ImportStatus.cancelled:
            cancelled++;
        }
      }
      await ledger.save();
      handled += chunk.length;
      onProgress?.call(handled, entries.length);
    }
    return FolderImportSummary(
      total: entries.length,
      alreadyDone: entries.length - pending.length,
      imported: imported,
      duplicates: duplicates,
      failed: failed,
      cancelled: cancelled,
    );
  }
}

const folderChannel = MethodChannel('quietake/folder');

/// The platform folder picker behind [FolderSource]. The native side keeps the
/// chosen folder open until [release]; it reads only direct children.
class PickedFolder implements FolderSource {
  PickedFolder._(this.identity, this._entries);
  @override
  final String identity;
  final List<FolderEntry> _entries;

  /// Null when the user cancels the picker.
  static Future<PickedFolder?> pick() async {
    final raw = await folderChannel.invokeMapMethod<String, dynamic>('pick');
    if (raw == null) return null;
    return PickedFolder._(raw['identity'] as String, [
      for (final e in raw['entries'] as List)
        FolderEntry(id: (e as Map)['id'] as String, name: e['name'] as String),
    ]);
  }

  @override
  Future<List<FolderEntry>> list() async => _entries;

  @override
  Future<File> copyTo(FolderEntry entry, Directory directory) async {
    final path = await folderChannel.invokeMethod<String>('copy', {
      'id': entry.id,
      'directory': directory.path,
    });
    return File(path!);
  }

  Future<void> cancel() => folderChannel.invokeMethod<void>('cancel');
  Future<void> release() => folderChannel.invokeMethod<void>('release');
}
