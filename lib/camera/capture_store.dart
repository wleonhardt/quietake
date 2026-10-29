import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../vault/vault.dart';

class EmptyCaptureException extends FormatException {
  const EmptyCaptureException(this.extension) : super('Empty native capture');
  final String extension;
}

class PendingCaptureException implements Exception {
  const PendingCaptureException({this.albumApplied = true});
  final bool albumApplied;
}

/// Owns finalized camera output until a durable encrypted capture is published.
/// Pending originals never enter the library, sharing or NAS sync listings.
class CaptureStore {
  CaptureStore(this.vault);
  final Vault vault;
  Directory get directory => Directory('${vault.dir.path}/.captures');

  Future<({File container, bool castReady, bool albumApplied})> ingest(
    File source, {
    required String extension,
    String? albumId,
    Set<String> tagIds = const {},
    Future<File> Function(File)? prepare,
  }) async {
    final selectedTags = {...tagIds, ?albumId};
    if (await source.length() == 0) {
      await source.delete();
      throw EmptyCaptureException(extension);
    }
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
    final work = await Directory('${directory.path}/$id').create();
    final plain = await source.rename('${work.path}/capture.$extension');
    final original = File('${plain.path}.shtr');
    final out = _destination(work, extension);
    File? prepared;
    var castReady = true;
    var albumApplied = true;
    try {
      if (selectedTags.isNotEmpty) {
        try {
          // Recovery publishes this same filename. Missing-media references
          // remain invisible until the encrypted capture is committed.
          await vault.catalog.organize({
            out.uri.pathSegments.last,
          }, tagIds: selectedTags);
        } on Exception {
          albumApplied = false;
        }
      }
      await vault.encryptFile(plain, original);
      if (prepare != null) {
        try {
          prepared = await prepare(plain);
          if (prepared.path != plain.path) {
            await vault.encryptFile(prepared, original);
          }
        } on Exception {
          // Conversion is optional. Its failure cannot destroy the original.
          castReady = false;
        }
      }
      await original.rename(out.path);
      try {
        await work.delete(recursive: true);
      } on FileSystemException {
        // The capture is published; recover removes the leftover source later.
      }
      return (container: out, castReady: castReady, albumApplied: albumApplied);
    } on Exception {
      // Retain both original input and any committed ciphertext for next unlock.
      throw PendingCaptureException(albumApplied: albumApplied);
    } finally {
      if (prepared != null &&
          prepared.path != plain.path &&
          await prepared.exists()) {
        await prepared.delete();
      }
    }
  }

  File _destination(Directory work, String extension) {
    final id = work.uri.pathSegments.lastWhere((part) => part.isNotEmpty);
    return File('${vault.dir.path}/$id.$extension.shtr');
  }

  Future<void> _authenticate(File file) async {
    await for (final _ in vault.read(file)) {
      // Consume through FINAL; a header or partial stream is not a saved capture.
    }
  }

  /// Authenticated camera open retries pending saves without requiring the NAS.
  /// [unnormalized] counts published videos that skipped or failed receiver
  /// normalization; the caller warns about TV playback and never auto-casts.
  Future<({int recovered, int pending, int unnormalized})> recover({
    Directory? cameraCache,
    Future<File> Function(File)? prepare,
  }) async {
    var recovered = 0;
    var pending = 0;
    var unnormalized = 0;
    final deleted = await vault.deletedNames();
    final workItems = await directory.exists()
        ? directory.list(followLinks: false)
        : const Stream<FileSystemEntity>.empty();
    await for (final work in workItems) {
      if (work is! Directory) continue;
      for (final extension in ['jpg', 'mp4']) {
        final plain = File('${work.path}/capture.$extension');
        final original = File('${plain.path}.shtr');
        final hasSource = await plain.exists() || await original.exists();
        final out = _destination(work, extension);
        if (!hasSource && !await out.exists()) continue;
        try {
          if (!deleted.contains(out.uri.pathSegments.last)) {
            if (await out.exists()) {
              try {
                await _authenticate(out);
              } on Exception {
                // A damaged published copy is replaced from the retained
                // source; without one the damaged bytes stay for inspection.
                if (!hasSource) rethrow;
                await out.delete();
              }
            }
            if (!await out.exists()) {
              try {
                await _authenticate(original);
              } on Exception {
                await vault.encryptFile(plain, original);
              }
              await original.rename(out.path);
              recovered++;
              // An interrupted conversion leaves no proof it finished.
              if (extension == 'mp4') unnormalized++;
            }
          }
          await work.delete(recursive: true);
        } on Exception {
          pending++;
        }
      }
    }
    if (cameraCache != null) {
      // CameraX's pinned plugin creates REC*.mp4 directly in private cache.
      // A process can die after native finalization but before Dart gets its path.
      await for (final source in cameraCache.list(followLinks: false)) {
        if (source is! File ||
            !source.uri.pathSegments.last.startsWith('REC') ||
            !source.path.endsWith('.mp4')) {
          continue;
        }
        try {
          final saved = await ingest(
            source,
            extension: 'mp4',
            prepare: prepare,
          );
          recovered++;
          if (!saved.castReady) unnormalized++;
        } on EmptyCaptureException {
          // The native recorder produced no data; do not invent a saved video.
        } on Exception {
          pending++;
        }
      }
    }
    return (recovered: recovered, pending: pending, unnormalized: unnormalized);
  }
}
