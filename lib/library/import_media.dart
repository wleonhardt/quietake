import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:sodium/sodium_sumo.dart';

import '../vault/vault.dart';
import '../gallery/preview.dart' show photoDecodeSize;

const importChannel = MethodChannel('quietake/import');

enum ImportStatus { imported, duplicate, failed, cancelled }

class ImportInput {
  const ImportInput({required this.name, this.path, this.error});
  final String name;
  final String? path;
  final String? error;
}

class ImportResult {
  const ImportResult(this.name, this.status, this.message);
  final String name;
  final ImportStatus status;
  final String message;
}

/// Consumes only private picker copies. External originals never enter ingestion.
class MediaImporter {
  MediaImporter(this.vault, this.staging, {this.validate = validateImport});
  final Vault vault;
  final Directory staging;
  final Future<void> Function(File, String) validate;
  static const maxBatchBytes = 512 * 1024 * 1024;
  static const maxPhotoPixels = 64 * 1000 * 1000;

  Future<String> _digest(Stream<List<int>> stream) async {
    final bytes = await vault.crypto.sodium.crypto.genericHash.stream(
      messages: stream.map((chunk) => Uint8List.fromList(chunk)),
    );
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<List<ImportResult>> run(
    List<ImportInput> inputs, {
    bool Function()? isCancelled,
    void Function(ImportResult)? onResult,
  }) async {
    final results = <ImportResult>[];
    final digests = <int, Set<String>>{};
    var remaining = maxBatchBytes;
    try {
      for (final input in inputs) {
        ImportResult result;
        try {
          if (inputs.length > 20) {
            throw const FormatException('Choose up to 20 files.');
          }
          if (isCancelled?.call() == true) {
            result = ImportResult(
              input.name,
              ImportStatus.cancelled,
              'Cancelled',
            );
          } else {
            if (input.error != null) throw FormatException(input.error!);
            var extension = input.name.split('.').last.toLowerCase();
            if (extension == 'jpeg') extension = 'jpg';
            if (!['jpg', 'png', 'mp4'].contains(extension)) {
              throw const FormatException('Use JPEG, PNG or MP4.');
            }
            final file = File(input.path!);
            final privatePath =
                '${await staging.resolveSymbolicLinks()}${Platform.pathSeparator}';
            if (!(await file.resolveSymbolicLinks()).startsWith(privatePath)) {
              throw const FormatException('Expected a private import copy.');
            }
            final length = await file.length();
            final limit = extension == 'mp4'
                ? maxBatchBytes
                : Vault.maxPhotoBytes;
            if (length == 0 || length > limit || length > remaining) {
              throw const FormatException('Import size limit exceeded.');
            }
            remaining -= length;
            await validate(file, extension);
            final hash = await _digest(file.openRead());
            if (!digests.containsKey(length)) {
              final hashes = <String>{};
              for (final existing in await vault.list()) {
                try {
                  if (await vault.crypto.plaintextLength(existing) == length) {
                    hashes.add(await _digest(vault.read(existing)));
                  }
                } on FormatException {
                  // Damaged existing media cannot prove a duplicate.
                } on SodiumException {
                  // Authentication failure must not block a valid new import.
                }
                if (isCancelled?.call() == true) break;
              }
              digests[length] = hashes;
            }
            if (isCancelled?.call() == true) {
              result = ImportResult(
                input.name,
                ImportStatus.cancelled,
                'Cancelled',
              );
            } else if (digests[length]!.contains(hash)) {
              result = ImportResult(
                input.name,
                ImportStatus.duplicate,
                'Exact duplicate skipped',
              );
            } else {
              await vault.ingest(file, extension: extension);
              digests[length]!.add(hash);
              result = ImportResult(
                input.name,
                ImportStatus.imported,
                'Imported',
              );
            }
          }
        } on FormatException catch (error) {
          result = ImportResult(input.name, ImportStatus.failed, error.message);
        } catch (_) {
          result = ImportResult(
            input.name,
            ImportStatus.failed,
            'Could not import. Check storage and try again.',
          );
        }
        results.add(result);
        onResult?.call(result);
      }
      return results;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
}

/// Native decoders validate only supported inputs; no conversion or autoplay.
Future<void> validateImport(File file, String extension) async {
  final head = await file
      .openRead(0, 12)
      .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
  final valid = switch (extension) {
    'jpg' =>
      head.length >= 3 && head[0] == 255 && head[1] == 216 && head[2] == 255,
    'png' =>
      head.length >= 8 && head.take(8).join(',') == '137,80,78,71,13,10,26,10',
    'mp4' =>
      head.length >= 8 && String.fromCharCodes(head.sublist(4, 8)) == 'ftyp',
    _ => false,
  };
  if (!valid) throw const FormatException('Unsupported or damaged media.');
  if (extension == 'mp4') {
    final player = VideoPlayerController.file(file);
    try {
      await player.initialize().timeout(const Duration(seconds: 20));
      if (player.value.duration <= Duration.zero || player.value.size.isEmpty) {
        throw const FormatException('Unsupported or damaged video.');
      }
    } catch (_) {
      throw const FormatException('Unsupported or damaged video.');
    } finally {
      await player.dispose();
    }
  } else {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > MediaImporter.maxPhotoPixels) {
        throw const FormatException('Photo resolution limit exceeded (64 MP).');
      }
      final size = photoDecodeSize(descriptor.width, descriptor.height, 64);
      codec = await descriptor.instantiateCodec(
        targetWidth: size.width,
        targetHeight: size.height,
      );
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Unsupported or damaged photo.');
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
