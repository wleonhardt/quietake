import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/settings/launcher_appearance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('quietake/appearance');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reads the native state', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'neutral');
      return true;
    });
    expect(await LauncherAppearance.neutral(), isTrue);
  });

  test('a platform without the channel reports no support', () async {
    expect(await LauncherAppearance.neutral(), isNull);
    expect(await LauncherAppearance.setNeutral(true), isFalse);
  });

  test(
    'a native error reads as no support and a failed switch as false',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'failed');
      });
      expect(await LauncherAppearance.neutral(), isNull);
      expect(await LauncherAppearance.setNeutral(false), isFalse);
    },
  );

  test('a switch sends the wanted state and reports success', () async {
    final sent = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setNeutral');
      sent.add(call.arguments);
      return null;
    });
    expect(await LauncherAppearance.setNeutral(true), isTrue);
    expect(await LauncherAppearance.setNeutral(false), isTrue);
    expect(sent, [true, false]);
  });
}
