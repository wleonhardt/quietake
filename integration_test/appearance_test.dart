import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';

import '../test_support/integration_binding.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  initializeIntegrationBinding();
  testWidgets(
    'system appearance preserves readable routes and encrypted media',
    (tester) async {
      final app = await TestApp.unlocked();
      try {
        for (final entry in await app.vault.dir.list().toList()) {
          await entry.delete(recursive: true);
        }
        final source = await File(
          '${(await getTemporaryDirectory()).path}/appearance.jpg',
        ).writeAsBytes(fixtureBytes('tiny.jpg'));
        final photo = await app.vault.ingestAs(source, 'appearance.jpg');
        final encrypted = await photo.readAsBytes();
        (await app.session.store.createWithPasscode('appearance-test-passcode'))
            .dispose();
        await tester.pumpWidget(app.widget());
        Future<void> until(bool Function() ready) async {
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (!ready()) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Appearance route deadline');
            }
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        Future<void> routeReady(Key key) async {
          await until(() {
            final elements = find.byKey(key).evaluate();
            if (elements.isEmpty) return false;
            final route = ModalRoute.of(elements.single);
            return route?.isCurrent == true &&
                (route?.animation?.isCompleted ?? true) &&
                (route?.secondaryAnimation?.isDismissed ?? true);
          });
          await tester.pump();
        }

        Future<void> tap(Key key, Key destination) async {
          await until(() => find.byKey(key).evaluate().isNotEmpty);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.ensureVisible(find.byKey(key));
          await tester.tap(find.byKey(key));
          await tester.pump(const Duration(milliseconds: 500));
          await routeReady(destination);
        }

        Brightness appearance(Key key) =>
            Theme.of(tester.element(find.byKey(key))).brightness;
        Future<void> back(Key destination) async {
          // iOS can retain the preceding route's tooltip during transition.
          final back = find.byType(BackButton).hitTestable();
          expect(back, findsOneWidget);
          await tester.tap(back);
          await tester.pump(const Duration(milliseconds: 500));
          await routeReady(destination);
        }

        for (final brightness in Brightness.values) {
          for (final (size, scale) in [
            (const Size(320, 640), 2.0),
            (const Size(1024, 768), 1.0),
          ]) {
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.binding.setSurfaceSize(size);
            await tester.pump(const Duration(milliseconds: 500));
            await until(
              () =>
                  find.byKey(Keys.openGallery).evaluate().isNotEmpty &&
                  tester
                          .widget<IconButton>(find.byKey(Keys.openGallery))
                          .onPressed !=
                      null,
            );
            expect(appearance(Keys.shutter), Brightness.dark);
            await tap(Keys.openGallery, Keys.gallerySettings);
            await until(
              () => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty,
            );
            expect(appearance(Keys.gallerySettings), brightness);
            expect(find.text('Library'), findsOneWidget);
            await tap(Keys.galleryTile(0), Keys.viewerPager);
            await until(
              () => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty,
            );
            expect(appearance(Keys.viewerPager), Brightness.dark);
            final title = tester.renderObject<RenderParagraph>(
              find.byKey(Keys.viewerPosition),
            );
            expect(title.size.width, greaterThan(0));
            expect(title.didExceedMaxLines, isFalse);
            for (final key in [
              Keys.lockNow,
              Keys.viewerShare,
              Keys.viewerDelete,
              Keys.viewerFavorite,
              Keys.viewerCast,
            ]) {
              expect(find.byKey(key).hitTestable(), findsOneWidget);
            }
            await back(Keys.gallerySettings);
            await tap(Keys.gallerySettings, Keys.settingsPrivacySection);
            expect(appearance(Keys.settingsPrivacySection), brightness);
            expect(
              find.byKey(Keys.settingsPrivacySection).hitTestable(),
              findsOneWidget,
            );
            await tester.ensureVisible(find.byKey(Keys.settingsPass));
            expect(find.byKey(Keys.settingsPass).hitTestable(), findsOneWidget);
            expect(
              tester.getSize(find.byKey(Keys.settingsPass)).width,
              lessThanOrEqualTo(600),
            );
            expect(tester.takeException(), isNull);
            await back(Keys.gallerySettings);
            await back(Keys.openGallery);
          }
        }
        expect(await source.exists(), isFalse);
        expect(await app.vault.list(), hasLength(1));
        expect(await photo.readAsBytes(), encrypted);
        expect(await app.vault.readAll(photo), fixtureBytes('tiny.jpg'));
      } finally {
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        await app.close();
      }
    },
  );
}
