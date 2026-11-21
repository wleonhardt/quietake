import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../media/media_server.dart';
import '../vault/vault.dart';
import 'item.dart';

/// A decoded thumbnail. The cache owns [image] and disposes it once no tile
/// references the name any more; tiles paint it with [RawImage].
class MediaPreview {
  const MediaPreview(this.image, {this.duration});
  final ui.Image image;
  final Duration? duration;

  /// Decoded size, what the cache budget counts.
  int get bytes => image.width * image.height * 4;
}

/// Serializes decoding and retains only small previews under a byte budget.
class PreviewCache {
  PreviewCache(this.load, {this.maxBytes = 8 * 1024 * 1024});
  final Future<MediaPreview> Function(VaultItem) load;
  final int maxBytes;
  final _ready = <String, MediaPreview>{};
  final _retired = <String, List<MediaPreview>>{};
  final _references = <String, int>{};
  final _pending = <String, Future<MediaPreview>>{};
  // Photos and videos queue separately: a native video decode that hangs for
  // its 20 s timeout must not stall every photo tile behind it.
  Future<void> _tail = Future.value();
  Future<void> _videoTail = Future.value();
  int retainedBytes = 0;
  bool _disposed = false;

  Future<MediaPreview> get(VaultItem item) {
    _references.update(item.name, (count) => count + 1, ifAbsent: () => 1);
    final hit = _ready.remove(item.name);
    if (hit != null) {
      _ready[item.name] = hit;
      return Future.value(hit);
    }
    return _pending.putIfAbsent(item.name, () => _read(item));
  }

  Future<MediaPreview> _read(VaultItem item) async {
    final previous = item.isVideo ? _videoTail : _tail;
    final done = Completer<void>();
    if (item.isVideo) {
      _videoTail = done.future;
    } else {
      _tail = done.future;
    }
    await previous;
    try {
      if (_disposed || !_references.containsKey(item.name)) {
        throw StateError('Preview no longer visible');
      }
      final preview = await load(item);
      if (_disposed) {
        preview.image.dispose();
        throw StateError('Preview cache closed');
      }
      if (preview.bytes <= maxBytes) {
        _ready[item.name] = preview;
        retainedBytes += preview.bytes;
        while (retainedBytes > maxBytes) {
          _drop(_ready.keys.first);
        }
      } else {
        _retire(item.name, preview);
      }
      return preview;
    } finally {
      _pending.remove(item.name);
      done.complete();
    }
  }

  void release(VaultItem item) {
    final count = _references[item.name] ?? 0;
    if (count <= 1) {
      _references.remove(item.name);
      // The last tile is gone: anything retired for this name can go.
      _retired.remove(item.name)?.forEach((p) => p.image.dispose());
    } else {
      _references[item.name] = count - 1;
    }
  }

  void _drop(String name) {
    final gone = _ready.remove(name);
    if (gone == null) return;
    retainedBytes -= gone.bytes;
    _retire(name, gone);
  }

  void _retire(String name, MediaPreview preview) {
    if ((_references[name] ?? 0) > 0) {
      _retired.putIfAbsent(name, () => []).add(preview);
    } else {
      preview.image.dispose();
    }
  }

  /// Drops decrypted previews while visible tiles keep their references, so
  /// the next request re-reads from the vault.
  void clear() {
    for (final name in _ready.keys.toList()) {
      _drop(name);
    }
    retainedBytes = 0;
  }

  void evict(String name) => _drop(name);

  void dispose() {
    _disposed = true;
    clear();
    _references.clear();
    for (final previews in _retired.values) {
      for (final preview in previews) {
        preview.image.dispose();
      }
    }
    _retired.clear();
  }
}

ui.TargetImageSize photoDecodeSize(int width, int height, int maxSide) {
  final longest = width > height ? width : height;
  final scale = longest > maxSide ? maxSide / longest : 1.0;
  return ui.TargetImageSize(
    width: (width * scale).round().clamp(1, maxSide),
    height: (height * scale).round().clamp(1, maxSide),
  );
}

const _previews = MethodChannel('quietake/previews');
const _noDuration = 0xffffffff;

/// A stored thumbnail's plaintext (decision 045): a version byte, the video
/// duration in milliseconds (all ones for a photo), then a JPEG.
Uint8List packThumbnail(Uint8List jpeg, Duration? duration) {
  final out = Uint8List(5 + jpeg.length)
    ..[0] = 1
    ..setRange(5, 5 + jpeg.length, jpeg);
  ByteData.sublistView(out).setUint32(
    1,
    duration?.inMilliseconds.clamp(0, _noDuration - 1) ?? _noDuration,
  );
  return out;
}

Future<MediaPreview> _decodeJpeg(Uint8List jpeg, Duration? duration) async {
  // The JPEG is already small; decode once instead of per paint.
  final codec = await ui.instantiateImageCodec(jpeg);
  try {
    return MediaPreview((await codec.getNextFrame()).image, duration: duration);
  } finally {
    codec.dispose();
  }
}

Future<MediaPreview?> _storedPreview(Vault vault, VaultItem item) async {
  try {
    final stored = await vault.readThumbnail(item.file);
    if (stored == null || stored.length < 6 || stored[0] != 1) return null;
    final millis = ByteData.sublistView(stored).getUint32(1);
    return await _decodeJpeg(
      Uint8List.sublistView(stored, 5),
      millis == _noDuration ? null : Duration(milliseconds: millis),
    );
  } catch (_) {
    return null; // Unreadable: build it again from the capture.
  }
}

/// Best effort: a preview that cannot be stored is still shown.
Future<void> _storePreview(
  Vault vault,
  VaultItem item,
  Future<Uint8List> Function() jpeg,
  Duration? duration,
) async {
  try {
    await vault.writeThumbnail(
      item.file,
      packThumbnail(await jpeg(), duration),
    );
  } catch (_) {}
}

/// The preview of [item]: its stored thumbnail when there is one, otherwise
/// built from the capture and stored for the next time (decision 045).
Future<MediaPreview> loadPreview(
  Vault vault,
  MediaServer server,
  VaultItem item,
) async {
  final stored = await _storedPreview(vault, item);
  if (stored != null) return stored;
  if (item.isVideo) {
    final url = server.register(item.file);
    try {
      final result = await _previews
          .invokeMapMethod<String, dynamic>('video', {'url': url.toString()})
          .timeout(const Duration(seconds: 20));
      // The native frame arrives as a small JPEG.
      final jpeg = result!['bytes'] as Uint8List;
      final duration = Duration(milliseconds: result['durationMs'] as int);
      final preview = await _decodeJpeg(jpeg, duration);
      await _storePreview(vault, item, () async => jpeg, duration);
      return preview;
    } finally {
      server.unregister(url);
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await vault.readAll(item.file),
  );
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = photoDecodeSize(descriptor.width, descriptor.height, 300);
    codec = await descriptor.instantiateCodec(
      targetWidth: size.width,
      targetHeight: size.height,
    );
    // The decoded image is the preview; no PNG encode and decode round trip.
    final image = (await codec.getNextFrame()).image;
    await _storePreview(vault, item, () async {
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      // Flutter encodes PNG only; the platform makes the far smaller JPEG.
      return (await _previews.invokeMethod<Uint8List>('encode', {
        'width': image.width,
        'height': image.height,
        'rgba': pixels!.buffer.asUint8List(
          pixels.offsetInBytes,
          pixels.lengthInBytes,
        ),
      }))!;
    }, null);
    return MediaPreview(image);
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

String mediaTime(Duration duration) {
  final seconds = duration.inSeconds;
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}
