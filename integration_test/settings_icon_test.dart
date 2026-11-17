import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/settings/launcher_appearance.dart';

import '../test_support/integration_binding.dart';
import 'harness.dart';

/// The Settings switch for the plain launcher icon changes the real launcher
/// entry on Android. iOS shows a system alert after each change that only a
/// person can dismiss, so there the test checks the row and the read path.
void main() {
  initializeIntegrationBinding();

  testWidgets('the Settings switch changes the launcher entry', (tester) async {
    final app = await TestApp.unlocked();
    addTearDown(() async {
      if (Platform.isAndroid) await LauncherAppearance.setNeutral(false);
    });
    try {
      await tester.pumpWidget(app.widget());
      Future<void> until(bool Function() ready) async {
        final end = DateTime.now().add(const Duration(seconds: 30));
        while (!ready()) {
          if (DateTime.now().isAfter(end)) fail('Settings icon deadline');
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await until(
        () =>
            find.byKey(Keys.openGallery).evaluate().isNotEmpty &&
            tester.widget<IconButton>(find.byKey(Keys.openGallery)).onPressed !=
                null,
      );
      await tester.tap(find.byKey(Keys.openGallery));
      await until(() => find.byKey(Keys.gallerySettings).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Keys.gallerySettings));
      await until(
        () => find.byKey(Keys.settingsPlainIcon).evaluate().isNotEmpty,
      );
      await tester.ensureVisible(find.byKey(Keys.settingsPlainIcon));
      await tester.pump();
      bool on() => tester
          .widget<SwitchListTile>(find.byKey(Keys.settingsPlainIcon))
          .value;
      expect(on(), isFalse);
      expect(await LauncherAppearance.neutral(), isFalse);
      if (!Platform.isAndroid) return;

      await tester.tap(find.byKey(Keys.settingsPlainIcon));
      await until(() => on());
      expect(await LauncherAppearance.neutral(), isTrue);
      await tester.tap(find.byKey(Keys.settingsPlainIcon));
      await until(() => !on());
      expect(await LauncherAppearance.neutral(), isFalse);
    } finally {
      await app.close();
    }
  });
}
