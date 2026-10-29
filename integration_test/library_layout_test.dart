import '../test_support/library_controls.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quietake/keys.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('library search fits landscape with keyboard and large text', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    try {
      (await app.session.store.createWithPasscode('layout-test-passcode'))
          .dispose();
      await tester.pumpWidget(app.widget());
      Future<void> until(Key key) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (find.byKey(key).evaluate().isEmpty) {
          if (DateTime.now().isAfter(deadline)) fail('Library layout deadline');
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await until(Keys.openGallery);
      await tester.tap(find.byKey(Keys.openGallery));
      await until(Keys.libraryOpenSearch);
      await revealLibraryControl(tester, Keys.librarySearch);
      expect(find.byKey(Keys.librarySearch).hitTestable(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.setSurfaceSize(const Size(740, 360));
      tester.view.viewInsets = FakeViewPadding(
        bottom: 200 * tester.view.devicePixelRatio,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Search must fit above keyboard',
      );
      tester.view.resetViewInsets();
      for (final size in [
        const Size(320, 640),
        const Size(360, 740),
        const Size(740, 360),
      ]) {
        for (final scale in [1.0, 2.0]) {
          await tester.binding.setSurfaceSize(size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pump(const Duration(milliseconds: 500));
          final title = tester.renderObject<RenderParagraph>(
            find.text('Search'),
          );
          expect(title.size.width, greaterThan(0));
          expect(title.didExceedMaxLines, isFalse);
          for (final key in [
            Keys.lockNow,
            Keys.gallerySettings,
            Keys.gallerySync,
            Keys.galleryCast,
            Keys.libraryImport,
          ]) {
            await revealLibraryControl(tester, key);
            expect(find.byKey(key).hitTestable(), findsOneWidget);
          }
          await revealLibraryControl(tester, Keys.lockNow);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Gallery must fit $size at $scale',
          );
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(Keys.lockNow));
      await until(Keys.lockPasscode);
    } finally {
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      await app.close();
    }
  });
}
