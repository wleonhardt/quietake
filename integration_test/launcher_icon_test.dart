import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/settings/launcher_appearance.dart';

import '../test_support/integration_binding.dart';

void main() {
  initializeIntegrationBinding();

  testWidgets(
    'the plain launcher entry switches on Android and reports no support elsewhere',
    (tester) async {
      if (!Platform.isAndroid) {
        expect(await LauncherAppearance.neutral(), isNull);
        return;
      }
      addTearDown(() => LauncherAppearance.setNeutral(false));
      expect(await LauncherAppearance.neutral(), isFalse);
      expect(await LauncherAppearance.setNeutral(true), isTrue);
      expect(await LauncherAppearance.neutral(), isTrue);
      expect(await LauncherAppearance.setNeutral(false), isTrue);
      expect(await LauncherAppearance.neutral(), isFalse);
    },
  );
}
