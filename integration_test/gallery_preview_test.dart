import '../test_support/library_controls.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/gallery/preview.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('filter changes never show another capture while preview waits', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    for (final name in ['2099-z.jpg', '2099-a.mp4']) {
      final plain =
          await File('${(await getTemporaryDirectory()).path}/preview-seed')
              .writeAsBytes(
                fixtureBytes(name.endsWith('jpg') ? 'tiny.jpg' : 'tiny.mp4'),
              );
      await app.vault.ingestAs(plain, name);
    }
    const channel = MethodChannel('quietake/previews');
    final called = Completer<void>();
    final release = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expectSync(call.method, 'video');
      if (!called.isCompleted) called.complete();
      await release.future;
      return {'bytes': fixtureBytes('tiny.jpg'), 'durationMs': 1000};
    });
    Future<void> until(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) {
          final preview = find.descendant(
            of: find.byKey(Keys.galleryTile(1)),
            matching: find.byType(FutureBuilder<MediaPreview>),
          );
          if (preview.evaluate().isNotEmpty) {
            try {
              await tester.widget<FutureBuilder<MediaPreview>>(preview).future;
            } catch (error) {
              fail('Preview setup error: $error');
            }
          }
          fail('Preview deadline; nativeCalled=${called.isCompleted}');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Finder image() => find.descendant(
      of: find.byKey(Keys.galleryTile(0)),
      matching: find.byKey(Keys.galleryPreview),
    );
    try {
      await tester.pumpWidget(app.widget());
      await until(() => find.byKey(Keys.openGallery).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Keys.openGallery));
      await until(() => image().evaluate().isNotEmpty && called.isCompleted);
      await tester.pump(const Duration(milliseconds: 500));
      await revealLibraryControl(tester, Keys.libraryVideos);
      await tester.tap(find.byKey(Keys.libraryVideos));
      await applyLibraryView(tester);
      expect(
        image(),
        findsNothing,
        reason: 'Pending video must not retain preceding photo thumbnail',
      );
      release.complete();
      await until(() => image().evaluate().isNotEmpty);
      expect(find.byKey(Keys.galleryVideoDuration), findsOneWidget);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        final label = tester
            .getSemantics(find.byKey(Keys.galleryTile(0)))
            .label;
        expect(label, contains('1 of 1'));
        expect(label, contains('duration 0:01'));
      } finally {
        semantics.dispose();
      }
      expect(await app.vault.list(), hasLength(2));
      expect(tester.takeException(), isNull);
    } finally {
      if (!release.isCompleted) release.complete();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await app.close();
    }
  });

  testWidgets(
    'gallery semantics distinguish captures and expose failed previews',
    (tester) async {
      final app = await TestApp.unlocked();
      final semantics = tester.ensureSemantics();
      try {
        for (final file in await app.vault.list()) {
          await file.delete();
        }
        final tmp = await getTemporaryDirectory();
        final captures = <File>[];
        for (var i = 0; i < 3; i++) {
          final plain = await File('${tmp.path}/semantics-seed')
              .writeAsBytes(i == 0 ? [1, 2, 3] : fixtureBytes('tiny.jpg'));
          captures.add(
            await app.vault.ingestAs(
              plain,
              '2026-10-27T12-00-00.00$i'
              '.jpg',
            ),
          );
          expect(await plain.exists(), isFalse);
        }
        await tester.pumpWidget(app.widget());
        Future<void> until(bool Function() done) async {
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (!done()) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Gallery semantics deadline');
            }
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await until(() => find.byKey(Keys.openGallery).evaluate().isNotEmpty);
        await tester.tap(find.byKey(Keys.openGallery));
        await until(
          () => find.byIcon(Icons.broken_image_outlined).evaluate().isNotEmpty,
        );
        String label(int i) =>
            tester.getSemantics(find.byKey(Keys.galleryTile(i))).label;
        expect(label(0), isNot(label(1)));
        expect(label(0), contains('1 of 3'));
        expect(label(2), contains('Preview unavailable'));
        expect(await app.vault.list(), hasLength(3));
        expect(
          await app.vault.readAll(captures.last),
          fixtureBytes('tiny.jpg'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        await app.close();
      }
    },
  );
}
