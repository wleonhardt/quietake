import 'package:camera_android_camerax/camera_android_camerax.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';

/// A camera platform that reports when a running recording has written data.
abstract interface class RecordingProgress {
  /// Emits once the recording started last has written encoded data.
  Stream<void> get recordedData;
}

/// Events that follow the recorder's Start event, or null when the platform
/// cannot report them and a started recording counts as live at once.
///
/// CameraX forwards every VideoRecordEvent to Dart. The first one is Start,
/// which ends the plugin's startVideoRecording. Recorder emits the next one,
/// Status, after writing video data to the muxer, which only starts with the
/// first keyframe; a Finalize arrives instead when the recording already
/// ended. A fresh subscription per recording keeps the skip aligned to Start.
Stream<void>? recordedData(CameraPlatform platform) {
  if (platform case RecordingProgress(:final recordedData)) return recordedData;
  if (platform is AndroidCameraCameraX) {
    return AndroidCameraCameraX.videoRecordingEventStreamController.stream.skip(
      1,
    );
  }
  return null;
}
