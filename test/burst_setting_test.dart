import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/burst_setting.dart';

void main() {
  test('the burst size is five until a choice is saved', () async {
    FlutterSecureStorage.setMockInitialValues({});
    expect(await BurstSetting.load(), 5);
    await BurstSetting.save(10);
    expect(await BurstSetting.load(), 10);
  });

  test(
    'an unknown saved size falls back to five and unknown sizes are refused',
    () async {
      FlutterSecureStorage.setMockInitialValues({'camera.burstSize': '7'});
      expect(await BurstSetting.load(), 5);
      expect(() => BurstSetting.save(7), throwsArgumentError);
    },
  );
}
