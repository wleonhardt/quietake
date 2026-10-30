import '../test_support/library_controls.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/import_media.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestApp app;
  late Directory temp;
  late Directory staging;
  late Directory external;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  );

  setUp(() async {
    app = await TestApp.unlocked();
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    temp = await getTemporaryDirectory();
    staging = Directory('${temp.path}/quietake-import');
    external = await Directory('${temp.path}/external-fixtures').create();
    await File('${external.path}/photo.jpg')
        .writeAsBytes(fixtureBytes('tiny.jpg'));
    await File('${external.path}/video.mp4')
        .writeAsBytes(fixtureBytes('tiny.mp4'));
    await File('${external.path}/photo.png').writeAsBytes(png);
    await File('${external.path}/oversized.png')
        .writeAsBytes(fixtureBytes('oversized.png'));
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      importChannel,
      null,
    );
    if (await external.exists()) await external.delete(recursive: true);
    await app.close();
  });

  Future<List<Map<String, String>>> copies() async {
    await staging.create();
    return [
      for (final name in ['photo.jpg', 'photo.png', 'video.mp4'])
        {
          'name': name,
          'path': (await File(
            '${external.path}/$name',
          ).copy('${staging.path}/$name')).path,
        },
    ];
  }

  Future<void> until(WidgetTester tester, bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('Import checkpoint timed out');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await revealLibraryControl(tester, key);
    await until(tester, () => find.byKey(key).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> begin(WidgetTester tester) async {
    await tester.pumpWidget(app.widget());
    await tap(tester, Keys.openGallery);
    await tap(tester, Keys.galleryEmptyCamera);
    await tap(tester, Keys.openGallery);
    await tap(tester, Keys.galleryEmptyImport);
  }

  testWidgets(
    'import validates native media, skips duplicates and refreshes gallery',
    (tester) async {
      var round = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(importChannel, (
        call,
      ) async {
        if (call.method != 'pick') return null;
        round++;
        if (round <= 2) return copies();
        await staging.create();
        if (round == 4) {
          return [
            {
              'name': 'oversized.png',
              'path': (await File(
                '${external.path}/oversized.png',
              ).copy('${staging.path}/oversized.png')).path,
            },
          ];
        }
        return [
          {
            'name': 'damaged.jpg',
            'path': (await File(
              '${staging.path}/damaged.jpg',
            ).writeAsBytes([255, 216, 255, 0])).path,
          },
        ];
      });
      await begin(tester);
      expect(find.textContaining('Up to 20 files'), findsNothing);
      await tap(tester, Keys.importDetails);
      expect(find.textContaining('Up to 20 files'), findsOneWidget);
      await tester.tap(find.text('Supported files and limits'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Up to 20 files'), findsNothing);
      await tap(tester, Keys.importChoose);
      await until(
        tester,
        () => find.byKey(Keys.importProgress).evaluate().isEmpty,
      );
      expect(
        find.text('3 imported · 0 duplicates skipped'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('|'),
      );
      expect(
        await File('${external.path}/photo.jpg').readAsBytes(),
        fixtureBytes('tiny.jpg'),
      );
      expect(await File('${external.path}/photo.png').readAsBytes(), png);
      expect(
        await File('${external.path}/video.mp4').readAsBytes(),
        fixtureBytes('tiny.mp4'),
      );
      final files = await app.vault.list();
      expect(files, hasLength(3));
      for (final file in files) {
        final name = file.uri.pathSegments.last;
        expect(
          await app.vault.readAll(file),
          name.endsWith('mp4.shtr')
              ? fixtureBytes('tiny.mp4')
              : name.endsWith('png.shtr')
              ? png
              : fixtureBytes('tiny.jpg'),
        );
      }
      expect(await staging.exists(), isFalse);
      await tap(tester, Keys.importChoose);
      await until(
        tester,
        () => find.byKey(Keys.importProgress).evaluate().isEmpty,
      );
      expect(find.text('0 imported · 3 duplicates skipped'), findsOneWidget);
      await tap(tester, Keys.importChoose);
      await until(
        tester,
        () => find.byKey(Keys.importProgress).evaluate().isEmpty,
      );
      expect(find.text('Unsupported or damaged photo.'), findsOneWidget);
      await tap(tester, Keys.importChoose);
      await until(
        tester,
        () => find.byKey(Keys.importProgress).evaluate().isEmpty,
      );
      expect(
        find.text('Photo resolution limit exceeded (64 MP).'),
        findsOneWidget,
      );
      expect(
        await File('${external.path}/oversized.png').readAsBytes(),
        fixtureBytes('oversized.png'),
      );
      expect(await app.vault.list(), hasLength(3));
      expect(await staging.exists(), isFalse);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await until(
        tester,
        () => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty,
      );
      expect(
        tester
            .widget<GridView>(find.byKey(Keys.galleryGrid))
            .childrenDelegate
            .estimatedChildCount,
        3,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'selected import finishes behind manual lock and remains protected until unlock',
    (tester) async {
      (await app.session.store.createWithPasscode('import-fixture-only'))
          .dispose();
      final selected = Completer<List<Map<String, String>>>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        importChannel,
        (call) async => call.method == 'pick' ? selected.future : null,
      );
      await begin(tester);
      await tap(tester, Keys.importChoose);
      await tap(tester, Keys.lockNow);
      await until(
        tester,
        () => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty,
      );
      selected.complete(await copies());
      var count = 0;
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (count != 3 || await staging.exists()) {
        if (DateTime.now().isAfter(end)) {
          final summary = tester.widgetList<Text>(
            find.byKey(Keys.importSummary, skipOffstage: false),
          );
          final errors = tester.widgetList<Text>(
            find.byKey(Keys.importError, skipOffstage: false),
          );
          fail(
            'Locked import did not finish: count=$count, '
            'staging=${await staging.exists()}, '
            'summary=${summary.map((text) => text.data).toList()}, '
            'errors=${errors.map((text) => text.data).toList()}',
          );
        }
        await tester.pump(const Duration(milliseconds: 100));
        count = (await app.vault.list()).length;
      }
      expect(find.byKey(Keys.lockPasscode), findsOneWidget);
      expect(find.byKey(Keys.importSummary), findsNothing);
      await tap(tester, Keys.lockBiometric);
      await until(
        tester,
        () => find.byKey(Keys.importSummary).evaluate().isNotEmpty,
      );
      expect(
        find.text('3 imported · 0 duplicates skipped'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('|'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancel while picker copies are pending keeps external originals and imports nothing',
    (tester) async {
      final pending = Completer<List<Map<String, String>>>();
      var cancellations = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(importChannel, (
        call,
      ) async {
        if (call.method == 'pick') return pending.future;
        if (call.method == 'cancel') cancellations++;
        return null;
      });
      await begin(tester);
      await tap(tester, Keys.importChoose);
      await tap(tester, Keys.importCancel);
      expect(cancellations, 1);
      pending.complete(await copies());
      await until(
        tester,
        () => find.byKey(Keys.importProgress).evaluate().isEmpty,
      );
      expect(find.text('0 imported · 0 duplicates skipped'), findsOneWidget);
      expect(await app.vault.list(), isEmpty);
      expect(await staging.exists(), isFalse);
      expect(
        await File('${external.path}/photo.jpg').readAsBytes(),
        fixtureBytes('tiny.jpg'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reopening import waits for abandoned selection cleanup before allowing another picker',
    (tester) async {
      final pending = Completer<List<Map<String, String>>>();
      var picks = 0;
      var clears = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(importChannel, (
        call,
      ) async {
        if (call.method == 'pick') {
          picks++;
          return picks == 1 ? pending.future : copies();
        }
        if (call.method == 'clear') clears++;
        return null;
      });
      await begin(tester);
      await tap(tester, Keys.importChoose);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await tap(tester, Keys.libraryImport);
      await tap(tester, Keys.importChoose);
      expect(picks, 1);
      expect(
        find.text('Previous import is finishing. Try again shortly.'),
        findsOneWidget,
      );
      pending.complete(await copies());
      await until(tester, () => clears == 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(await staging.exists(), isFalse);
      expect(await app.vault.list(), isEmpty);
      await tap(tester, Keys.importChoose);
      await until(
        tester,
        () => find.byKey(Keys.importProgress).evaluate().isEmpty,
      );
      expect(picks, 2);
      expect(find.text('3 imported · 0 duplicates skipped'), findsOneWidget);
      expect(await app.vault.list(), hasLength(3));
      expect(await staging.exists(), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
