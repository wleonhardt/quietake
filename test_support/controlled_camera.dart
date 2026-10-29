import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';

import 'fixtures.dart';

/// A camera that can reproduce an empty native result without using hardware.
class ControlledCamera extends CameraPlatform {
  ControlledCamera(this.directory);
  final Directory directory;
  bool empty = true;
  int created = 0;
  final disposed = <int>{};
  final _errors = <int, StreamController<CameraErrorEvent>>{};
  final outputs = <File>[];

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'controlled',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    ),
  ];
  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async {
    final id = ++created;
    _errors[id] = StreamController<CameraErrorEvent>.broadcast();
    return id;
  }

  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) => Stream.value(
    CameraInitializedEvent(
      id,
      160,
      120,
      ExposureMode.auto,
      false,
      FocusMode.auto,
      false,
    ),
  );
  @override
  Stream<CameraErrorEvent> onCameraError(int id) => _errors[id]!.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Widget buildPreview(int id) => const SizedBox.expand();
  @override
  Future<void> startVideoRecording(
    int id, {
    Duration? maxVideoDuration,
  }) async {}
  Future<XFile> _output(String extension) async {
    final file = await File(
      '${directory.path}/controlled-${outputs.length}.$extension',
    ).writeAsBytes(empty ? [] : fixtureBytes('tiny.$extension'));
    outputs.add(file);
    return XFile(file.path);
  }

  @override
  Future<XFile> takePicture(int id) => _output('jpg');
  @override
  Future<XFile> stopVideoRecording(int id) => _output('mp4');
  @override
  Future<void> dispose(int id) async {
    _errors[id]!.add(CameraErrorEvent(id, 'Disposed test camera'));
    await _errors.remove(id)!.close();
    disposed.add(id);
  }
}
