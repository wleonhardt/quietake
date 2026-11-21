import 'dart:async';

import 'package:camera_android_camerax/camera_android_camerax.dart';
import 'package:camera_android_camerax/src/camerax_library.g.dart'
    show VideoRecordEventStart, VideoRecordEventFinalize;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/recording_progress.dart';

class _Start extends VideoRecordEventStart {
  _Start() : super.pigeon_detached();
}

class _Finalize extends VideoRecordEventFinalize {
  _Finalize() : super.pigeon_detached();
}

class _Plain extends CameraPlatform {}

class _Reporting extends CameraPlatform implements RecordingProgress {
  final controller = StreamController<void>.broadcast();
  @override
  Stream<void> get recordedData => controller.stream;
}

void main() {
  test('a platform that reports progress is used as is', () async {
    final platform = _Reporting();
    var emitted = 0;
    final subscription = recordedData(platform)!.listen((_) => emitted++);
    platform.controller.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, 1);
    await subscription.cancel();
  });

  test('a platform that cannot report has no progress stream', () {
    expect(recordedData(_Plain()), isNull);
  });

  test('CameraX ignores the Start event and reports the next one', () async {
    final stream = recordedData(AndroidCameraCameraX())!;
    var emitted = 0;
    final subscription = stream.listen((_) => emitted++);
    final events = AndroidCameraCameraX.videoRecordingEventStreamController;
    events.add(_Start());
    await Future<void>.delayed(Duration.zero);
    expect(emitted, 0, reason: 'Start only means the recorder opened');
    events.add(_Finalize());
    await Future<void>.delayed(Duration.zero);
    expect(emitted, 1);
    await subscription.cancel();
  });

  test('each CameraX recording gets a fresh skip of its own Start', () async {
    final events = AndroidCameraCameraX.videoRecordingEventStreamController;
    final platform = AndroidCameraCameraX();
    for (var i = 0; i < 2; i++) {
      var emitted = 0;
      final subscription = recordedData(platform)!.listen((_) => emitted++);
      events.add(_Start());
      await Future<void>.delayed(Duration.zero);
      expect(emitted, 0, reason: 'recording ${i + 1}');
      await subscription.cancel();
    }
  });
}
