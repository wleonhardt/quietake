import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../crypto/random_token.dart';
import '../crypto/share_bundle.dart';
import '../vault/vault.dart';
import 'exif_strip.dart';
import 'item.dart';
import 'redact.dart';

bool _sharing = false;

/// Also removes the Android plugin's private copy. Run at startup after crashes.
/// [atStartup] also removes plaintext copies an interrupted import left; a
/// share must not, because an import may be running.
Future<void> clearShareFiles({bool atStartup = false}) async {
  final root = await getTemporaryDirectory();
  for (final name in [
    'quietake-share',
    'share_plus',
    if (atStartup) 'quietake-import',
  ]) {
    final directory = Directory('${root.path}/$name');
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

const maxShareItems = 10;
const maxShareBatchBytes = 256 * 1024 * 1024;

class SharePreparationException implements Exception {
  const SharePreparationException(this.message, {this.item});
  final String message;
  final VaultItem? item;
}

class _ShareCancelled implements Exception {}

/// Single-item export used by the share tests; the app shares through
/// [shareMediaCopies].
Future<void> shareMedia(
  Vault vault,
  VaultItem item, {
  required Rect origin,
  required bool Function() isActive,
}) => shareMediaCopies(vault, [item], origin: origin, isActive: isActive);

/// Prepares every selected copy before opening the chooser. Originals stay encrypted.
Future<void> shareMediaCopies(
  Vault vault,
  List<VaultItem> selected, {
  required Rect origin,
  bool stripLocation = true,

  /// Areas to pixelate per photo, keyed by capture name. A redacted copy is a
  /// PNG without metadata; the vault original is never changed.
  Map<String, List<Rect>> redactions = const {},

  /// When set, the prepared copies go into one `.quietake-share` bundle
  /// encrypted with this passphrase (decision 025) and only the bundle is
  /// handed to the chooser, with neutral entry names.
  String? passphrase,
  required bool Function() isActive,
  void Function(int prepared, int total)? onProgress,
}) async {
  if (_sharing) throw StateError('Another share is still finishing');
  _sharing = true;
  final items = List<VaultItem>.unmodifiable(selected);
  try {
    if (items.isEmpty || items.length > maxShareItems) {
      throw const SharePreparationException(
        'Select between 1 and 10 captures.',
      );
    }
    var expectedBytes = 0;
    for (final item in items) {
      if (!isActive()) return;
      try {
        expectedBytes += await vault.crypto.plaintextLength(item.file);
      } catch (_) {
        throw SharePreparationException(
          'Could not read this capture.',
          item: item,
        );
      }
    }
    if (items.length > 1 && expectedBytes > maxShareBatchBytes) {
      throw const SharePreparationException(
        'Share up to 256 MiB at once, or share a video individually.',
      );
    }
    await clearShareFiles();
    final root = await getTemporaryDirectory();
    final directory = await Directory('${root.path}/quietake-share').create();
    final files = <XFile>[];
    var bytes = 0;
    onProgress?.call(0, items.length);
    for (final item in items) {
      if (!isActive()) return;
      final id = randomHexToken(vault.crypto.sodium);
      final areas = item.isVideo ? null : redactions[item.name];
      final redacted = areas != null && areas.isNotEmpty;
      final extension = item.isVideo
          ? item.extension
          : redacted || item.extension == 'png'
          ? 'png'
          : 'jpg';
      final file = File(
        '${directory.path}/${item.isVideo ? 'video' : 'photo'}-$id.$extension',
      );
      try {
        if (redacted || (stripLocation && !item.isVideo)) {
          // Photos are bounded (Vault.maxPhotoBytes). JPEG GPS data is erased;
          // unsafe metadata aborts before the chooser receives any copy.
          if (!isActive()) throw _ShareCancelled();
          final plain = await vault.readAll(item.file);
          bytes += plain.length;
          if (items.length > 1 && bytes > maxShareBatchBytes) {
            throw const SharePreparationException(
              'Share up to 256 MiB at once, or share a video individually.',
            );
          }
          if (!isActive()) throw _ShareCancelled();
          await file.writeAsBytes(
            redacted ? await redactToPng(plain, areas) : withoutMetadata(plain),
            flush: true,
          );
        } else {
          await vault
              .read(item.file)
              .map((chunk) {
                if (!isActive()) throw _ShareCancelled();
                bytes += chunk.length;
                if (items.length > 1 && bytes > maxShareBatchBytes) {
                  throw const SharePreparationException(
                    'Share up to 256 MiB at once, or share a video individually.',
                  );
                }
                return chunk;
              })
              .pipe(file.openWrite());
        }
      } on _ShareCancelled {
        return;
      } on SharePreparationException {
        rethrow;
      } catch (_) {
        throw SharePreparationException(
          'Could not prepare this capture. Remove it from selection and try again.',
          item: item,
        );
      }
      files.add(
        XFile(file.path, mimeType: redacted ? 'image/png' : item.contentType),
      );
      onProgress?.call(files.length, items.length);
    }
    if (!isActive()) return;
    if (passphrase != null) {
      final bundle = File(
        '${directory.path}/captures-${randomHexToken(vault.crypto.sodium)}.quietake-share',
      );
      final entries = <ShareEntry>[
        for (var i = 0; i < files.length; i++)
          ShareEntry(
            '${items[i].isVideo ? 'video' : 'photo'}-${(i + 1).toString().padLeft(2, '0')}.${files[i].path.split('.').last}',
            File(files[i].path),
          ),
      ];
      try {
        await ShareBundle(vault.crypto.sodium)
            .write(bundle, passphrase, entries);
      } catch (_) {
        throw const SharePreparationException(
          'Could not prepare the encrypted share. Try again.',
        );
      }
      for (final e in entries) {
        await e.file.delete();
      }
      files
        ..clear()
        ..add(XFile(bundle.path, mimeType: 'application/octet-stream'));
      if (!isActive()) return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        title: passphrase != null
            ? 'Share encrypted bundle'
            : items.length == 1
            ? (items.single.isVideo ? 'Share video' : 'Share photo')
            : 'Share ${items.length} captures',
        sharePositionOrigin: origin,
      ),
    );
    final resumed = _ShareReturn();
    try {
      await resumed.done;
    } finally {
      resumed.dispose();
    }
  } finally {
    try {
      await clearShareFiles();
    } finally {
      _sharing = false;
    }
  }
}

/// Android can report the chosen app before that app has consumed the file.
class _ShareReturn with WidgetsBindingObserver {
  _ShareReturn() {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _done.complete();
    }
  }
  final _done = Completer<void>();
  Future<void> get done => _done.future;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_done.isCompleted) {
      _done.complete();
    }
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
