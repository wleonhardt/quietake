import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../vault/vault.dart';
import 'capture_store.dart';

/// Android H.264/AAC normalization in private cache (decision 019). Null on
/// platforms whose recordings already play on Chromecast. Native code learns
/// the pending-capture directory from this call instead of a hard-coded path.
Future<File> Function(File)? videoPreparer(Vault vault) =>
    defaultTargetPlatform == TargetPlatform.android
    ? (plain) async {
        final path = await const MethodChannel('quietake/camera')
            .invokeMethod<String>('prepareVideo', {
              'path': plain.path,
              'pending': CaptureStore(vault).directory.path,
            });
        if (path == null) throw const FormatException('No prepared video');
        return File(path);
      }
    : null;

/// Secure the original before optional Android receiver normalization.
Future<({File container, bool castReady, bool albumApplied})> ingestVideo(
  Vault vault,
  File source, {
  String? albumId,
  Set<String> tagIds = const {},
}) => CaptureStore(vault).ingest(
  source,
  extension: 'mp4',
  albumId: albumId,
  tagIds: tagIds,
  prepare: videoPreparer(vault),
);
