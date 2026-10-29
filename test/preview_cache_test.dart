import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/preview.dart';

/// A decoded image of [pixels] by one, 4 bytes per pixel.
Future<MediaPreview> preview(int pixels) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List(pixels * 4),
    pixels,
    1,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future.then(MediaPreview.new);
}

void main() {
  test(
    'photo decoding stays positive, bounded and never upscales small media',
    () {
      for (final width in [1, 2, 16, 160, 5000, 65535]) {
        for (final height in [1, 2, 16, 120, 5000, 65535]) {
          for (final limit in [300, 4096]) {
            final size = photoDecodeSize(width, height, limit);
            expect(size.width, inInclusiveRange(1, limit));
            expect(size.height, inInclusiveRange(1, limit));
            expect(size.width!, lessThanOrEqualTo(width));
            expect(size.height!, lessThanOrEqualTo(height));
          }
        }
      }
      final original = photoDecodeSize(160, 120, 4096);
      expect((original.width, original.height), (160, 120));
    },
  );

  test(
    'previews deduplicate, evict oldest bytes and clear on dispose',
    () async {
      var reads = 0;
      final cache = PreviewCache((_) async {
        reads++;
        return preview(1);
      }, maxBytes: 8);
      VaultItem item(String name) => VaultItem(File('$name.jpg.shtr'));
      final a = cache.get(item('a'));
      expect(identical(cache.get(item('a')), a), isTrue);
      await a;
      await cache.get(item('b'));
      await cache.get(item('a'));
      await cache.get(item('c'));
      expect(cache.retainedBytes, 8);
      expect(reads, 3);
      await cache.get(item('b'));
      expect(reads, 4);
      cache.dispose();
      expect(cache.retainedBytes, 0);
    },
  );

  test(
    'an evicted image stays alive for its tiles and is disposed on release',
    () async {
      final cache = PreviewCache((_) => preview(1), maxBytes: 4);
      final a = VaultItem(File('a.jpg.shtr'));
      final b = VaultItem(File('b.jpg.shtr'));
      final first = await cache.get(a);
      await cache.get(b); // evicts a while a tile still references it
      expect(first.image.debugDisposed, isFalse);
      cache.clear();
      expect(first.image.debugDisposed, isFalse);
      cache.release(a);
      expect(first.image.debugDisposed, isTrue);
      cache.dispose();
    },
  );

  test('decodes run one at a time and failure does not poison queue', () async {
    final first = Completer<void>();
    final log = <String>[];
    final cache = PreviewCache((item) async {
      log.add(item.name);
      if (item.name.startsWith('bad')) {
        await first.future;
        throw const FormatException('corrupt');
      }
      return preview(1);
    });
    final bad = expectLater(
      cache.get(VaultItem(File('bad.jpg.shtr'))),
      throwsFormatException,
    );
    final good = cache.get(VaultItem(File('good.jpg.shtr')));
    await Future<void>.delayed(Duration.zero);
    expect(log, ['bad.jpg.shtr']);
    first.complete();
    await bad;
    await good;
    expect(log, ['bad.jpg.shtr', 'good.jpg.shtr']);
    cache.dispose();
  });
  test('a stalled video preview does not block photo previews', () async {
    final stall = Completer<void>();
    final cache = PreviewCache((item) async {
      if (item.isVideo) await stall.future;
      return preview(1);
    });
    final video = cache.get(VaultItem(File('clip.mp4.shtr')));
    final photo = cache.get(VaultItem(File('photo.jpg.shtr')));
    await photo.timeout(const Duration(seconds: 2));
    stall.complete();
    await video;
    cache.dispose();
  });

  test('queued off-screen work is skipped', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final calls = <String>[];
    final cache = PreviewCache((item) async {
      calls.add(item.name);
      if (item.name.startsWith('first')) {
        started.complete();
        await gate.future;
      }
      return preview(1);
    });
    final first = cache.get(VaultItem(File('first.jpg.shtr')));
    await started.future;
    final offscreen = VaultItem(File('offscreen.jpg.shtr'));
    final skipped = expectLater(cache.get(offscreen), throwsStateError);
    cache.release(offscreen);
    gate.complete();
    await first;
    await skipped;
    expect(calls, ['first.jpg.shtr']);
    cache.dispose();
  });
}
