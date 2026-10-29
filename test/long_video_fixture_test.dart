import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../test_support/long_video.dart';
import '../test_support/mp4.dart';

void main() {
  test(
    'long fixture is large and keeps actual H.264/AAC sample entries',
    () async {
      final dir = await Directory.systemTemp.createTemp('long-fixture-');
      try {
        final file = File('${dir.path}/long.mp4');
        await writeLongVideo(file);
        expect(
          await file.length(),
          inInclusiveRange(63 * 1024 * 1024, 64 * 1024 * 1024),
        );
        expect(
          mp4SampleEntries(await file.readAsBytes()),
          containsAll(['avc1', 'mp4a']),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
