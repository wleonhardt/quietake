import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/library_query.dart';
import 'package:quietake/library/view_sheet.dart';

void main() {
  const initial = (
    kind: MediaKind.photo,
    favorites: true,
    sort: LibrarySort.oldest,
  );
  LibraryView? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester, {
    int Function(LibraryView)? count,
  }) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () async {
              result = await chooseLibraryView(context, initial, count: count);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('applying without edits returns the initial view', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Apply view'), findsOneWidget);
    await tester.tap(find.byKey(Keys.libraryViewApply));
    await tester.pumpAndSettle();
    expect(result, initial);
  });

  testWidgets('edits combine and return the chosen view', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.libraryVideos));
    await tester.tap(find.byKey(Keys.libraryFavorites));
    await tester.tap(find.byKey(Keys.librarySort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Keys.libraryViewApply));
    await tester.pumpAndSettle();
    expect(result, (
      kind: MediaKind.video,
      favorites: false,
      sort: LibrarySort.name,
    ));
  });

  testWidgets('reset restores defaults and cancel returns nothing', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.libraryViewReset));
    await tester.pump();
    await tester.tap(find.byKey(Keys.libraryViewApply));
    await tester.pumpAndSettle();
    expect(result, (
      kind: MediaKind.all,
      favorites: false,
      sort: LibrarySort.newest,
    ));

    await open(tester);
    await tester.tap(find.byKey(Keys.libraryVideos));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('apply button shows the live count of the pending view', (
    tester,
  ) async {
    await open(
      tester,
      count: (v) => v.kind == MediaKind.video
          ? 1
          : v.favorites
          ? 7
          : 0,
    );
    expect(find.text('Show 7 captures'), findsOneWidget);
    await tester.tap(find.byKey(Keys.libraryVideos));
    await tester.pump();
    expect(find.text('Show 1 capture'), findsOneWidget);
    await tester.tap(find.byKey(Keys.libraryFavorites));
    await tester.pump();
    expect(find.text('Show 1 capture'), findsOneWidget);
    await tester.tap(find.byKey(Keys.libraryAll));
    await tester.pump();
    expect(find.text('Show 0 captures'), findsOneWidget);
  });
}
