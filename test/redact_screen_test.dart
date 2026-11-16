import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/redact_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';

import '../test_support/png_fixture.dart';

void main() {
  Future<Future<List<Rect>?> Function()> open(
    WidgetTester tester,
    Uint8List bytes, {
    Locale? locale,
  }) async {
    List<Rect>? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () async {
              result = await Navigator.push<List<Rect>>(
                context,
                MaterialPageRoute(builder: (_) => RedactScreen(bytes: bytes)),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    return () async {
      expect(closed, isTrue);
      return result;
    };
  }

  Future<void> show(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump(const Duration(milliseconds: 400));
    // The screen decodes the photo asynchronously.
    for (var i = 0; i < 100; i++) {
      if (find.byKey(Keys.redactCanvas).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byKey(Keys.redactCanvas), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // Route transition ends.
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await gesture.up();
    await tester.pump();
  }

  testWidgets('dragging adds an area and Done returns it in image fractions', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(gradientPng))!;
    final result = await open(tester, bytes);
    await show(tester);
    final box = tester.getRect(find.byKey(Keys.redactCanvas));
    await drag(
      tester,
      box.topLeft + Offset(box.width * .25, box.height * .25),
      box.topLeft + Offset(box.width * .75, box.height * .5),
    );
    expect(find.text('1 area will be hidden.'), findsOneWidget);
    await tester.tap(find.byKey(Keys.redactDone));
    await tester.pumpAndSettle();
    final rects = (await result())!;
    expect(rects, hasLength(1));
    expect(rects.single.left, closeTo(.25, .02));
    expect(rects.single.top, closeTo(.25, .02));
    expect(rects.single.right, closeTo(.75, .02));
    expect(rects.single.bottom, closeTo(.5, .02));
  });

  testWidgets('Undo removes the last area and a tiny drag adds none', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(gradientPng))!;
    final result = await open(tester, bytes);
    await show(tester);
    final box = tester.getRect(find.byKey(Keys.redactCanvas));
    await drag(tester, box.center, box.center + const Offset(1, 1));
    expect(find.text('Drag over the photo to hide an area.'), findsOneWidget);
    await drag(tester, box.topLeft + const Offset(5, 5), box.center);
    await drag(tester, box.center, box.bottomRight - const Offset(5, 5));
    expect(find.text('2 areas will be hidden.'), findsOneWidget);
    await tester.tap(find.byKey(Keys.redactUndo));
    await tester.pump();
    expect(find.text('1 area will be hidden.'), findsOneWidget);
    await tester.tap(find.byKey(Keys.redactDone));
    await tester.pumpAndSettle();
    expect((await result())!, hasLength(1));
  });

  testWidgets('going back keeps the earlier choice by returning null', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(gradientPng))!;
    final result = await open(tester, bytes);
    await show(tester);
    final box = tester.getRect(find.byKey(Keys.redactCanvas));
    await drag(tester, box.topLeft + const Offset(5, 5), box.center);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await result(), isNull);
  });

  testWidgets('the screen follows the device language', (tester) async {
    final bytes = (await tester.runAsync(gradientPng))!;
    await open(tester, bytes, locale: const Locale('es'));
    await show(tester);
    expect(
      find.text('Arrastra sobre la foto para ocultar una zona.'),
      findsOneWidget,
    );
    expect(find.text('Listo'), findsOneWidget);
  });
}
