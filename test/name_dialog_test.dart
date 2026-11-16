import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/name_dialog.dart';

Future<void> pumpHost(
  WidgetTester tester,
  Future<void> Function(BuildContext) onOpen,
) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: const Key('open'),
          onPressed: () => onOpen(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  Future<void> open(
    WidgetTester tester,
    Future<void> Function(String) save, {
    String initial = 'Old',
  }) async {
    await pumpHost(
      tester,
      (c) => editLibraryName(c, title: 'Rename', initial: initial, save: save),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('saves the edited text and closes', (tester) async {
    String? saved;
    await open(tester, (v) async => saved = v);
    expect(find.text('Old'), findsOneWidget);
    await tester.enterText(find.byKey(Keys.libraryName), 'New');
    await tester.tap(find.byKey(Keys.librarySave));
    await tester.pumpAndSettle();
    expect(saved, 'New');
    expect(find.byKey(Keys.libraryName), findsNothing);
  });

  testWidgets('cancel closes without saving', (tester) async {
    var calls = 0;
    await open(tester, (_) async => calls++);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byKey(Keys.libraryName), findsNothing);
  });

  testWidgets('shows validation text and stays open', (tester) async {
    await open(tester, (_) async => throw const FormatException('Name taken'));
    await tester.tap(find.byKey(Keys.librarySave));
    await tester.pumpAndSettle();
    expect(find.text('Name taken'), findsOneWidget);
    expect(find.byKey(Keys.libraryName), findsOneWidget);
  });

  testWidgets('hides internal errors behind a generic retry message', (
    tester,
  ) async {
    await open(tester, (_) async => throw StateError('secret path /x'));
    await tester.tap(find.byKey(Keys.librarySave));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Retry.'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('disables save while saving and closes on completion', (
    tester,
  ) async {
    final gate = Completer<void>();
    var calls = 0;
    await open(tester, (_) {
      calls++;
      return gate.future;
    });
    await tester.tap(find.byKey(Keys.librarySave));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(Keys.librarySave)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(Keys.librarySave), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.libraryName), findsNothing);
  });

  group('updateLibrary', () {
    Future<void> run(
      WidgetTester tester,
      Future<void> Function() update,
    ) async {
      await pumpHost(tester, (c) => updateLibrary(c, update));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('is silent on success', (tester) async {
      await run(tester, () async {});
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('shows catalog explanation for FormatException', (
      tester,
    ) async {
      await run(tester, () async => throw const FormatException('Stale tag'));
      expect(find.text('Stale tag'), findsOneWidget);
    });

    testWidgets('shows generic text for other failures', (tester) async {
      await run(tester, () async => throw StateError('boom'));
      expect(
        find.text('Could not update private library. Retry.'),
        findsOneWidget,
      );
      expect(find.textContaining('boom'), findsNothing);
    });
  });
}
