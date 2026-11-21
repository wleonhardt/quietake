import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/settings/launcher_appearance.dart';

import '../test_support/integration_binding.dart';

void main() {
  initializeIntegrationBinding();

  testWidgets(
    'the plain launcher entry switches on Android and iOS',
    (tester) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        expect(await LauncherAppearance.neutral(), isNull);
        return;
      }
      expect(await LauncherAppearance.neutral(), isFalse);
      // iOS shows a system alert after each icon change that only a person
      // can dismiss, so the switch itself is not driven on iOS.
      if (Platform.isIOS) return;
      addTearDown(() => LauncherAppearance.setNeutral(false));
      expect(await LauncherAppearance.setNeutral(true), isTrue);
      expect(await LauncherAppearance.neutral(), isTrue);
      expect(await LauncherAppearance.setNeutral(false), isTrue);
      expect(await LauncherAppearance.neutral(), isFalse);
    },
  );
}
