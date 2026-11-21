import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/video_setting.dart';

void main() {
  test('video records at 1080p until a choice is saved', () async {
    FlutterSecureStorage.setMockInitialValues({});
    expect(await VideoSetting.load(), 1080);
    await VideoSetting.save(2160);
    expect(await VideoSetting.load(), 2160);
  });

  test('an unknown saved height falls back and unknown heights are refused',
      () async {
    FlutterSecureStorage.setMockInitialValues({'camera.videoHeight': '480'});
    expect(await VideoSetting.load(), 1080);
    expect(() => VideoSetting.save(480), throwsArgumentError);
  });

  test('each choice has a preset and a label', () {
    expect(VideoSetting.preset(720), ResolutionPreset.high);
    expect(VideoSetting.preset(1080), ResolutionPreset.veryHigh);
    expect(VideoSetting.preset(2160), ResolutionPreset.ultraHigh);
    expect(VideoSetting.choices.map(VideoSetting.label), ['720p', '1080p', '4K']);
  });
}
