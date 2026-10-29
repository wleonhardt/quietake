import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';

/// Follows the same disclosure path as a user; never manipulates screen state.
Future<void> revealLibraryControl(WidgetTester tester, Key key) async {
  const viewKeys = [
    Keys.libraryAll,
    Keys.libraryPhotos,
    Keys.libraryVideos,
    Keys.libraryFavorites,
    Keys.librarySort,
    Keys.librarySortOldest,
  ];
  const actionKeys = [
    Keys.librarySelect,
    Keys.libraryAlbums,
    Keys.libraryImport,
    Keys.galleryCast,
    Keys.gallerySync,
    Keys.libraryUntagged,
  ];
  if (!actionKeys.contains(key) &&
      key != Keys.libraryActionsClose &&
      find.byKey(Keys.libraryActionsClose).evaluate().isNotEmpty &&
      ModalRoute.of(tester.element(find.byKey(Keys.libraryActionsClose)))
              ?.isCurrent ==
          true) {
    await tester.ensureVisible(find.byKey(Keys.libraryActionsClose));
    await tester.tap(find.byKey(Keys.libraryActionsClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  if (!viewKeys.contains(key) &&
      key != Keys.libraryViewApply &&
      find.byKey(Keys.libraryViewApply).evaluate().isNotEmpty &&
      ModalRoute.of(tester.element(find.byKey(Keys.libraryViewApply)))
              ?.isCurrent ==
          true) {
    await tester.ensureVisible(find.byKey(Keys.libraryViewApply));
    await tester.tap(find.byKey(Keys.libraryViewApply));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  if (key == Keys.librarySearch && find.byKey(key).evaluate().isEmpty) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Keys.libraryOpenSearch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
    expect(find.byKey(Keys.librarySearch), findsOneWidget);
  }
  if (viewKeys.contains(key) || actionKeys.contains(key)) {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byKey(key).evaluate().isEmpty) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.byKey(
          viewKeys.contains(key) ? Keys.libraryView : Keys.libraryTools,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.ensureVisible(find.byKey(key));
  }
}

Future<void> applyLibraryView(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(Keys.libraryViewApply));
  await tester.tap(find.byKey(Keys.libraryViewApply));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> showLibrarySearch(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  for (
    var attempt = 0;
    attempt < 250 && find.byKey(Keys.libraryShowSearch).evaluate().isEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(find.byKey(Keys.libraryShowSearch), findsOneWidget);
  await tester.ensureVisible(find.byKey(Keys.libraryShowSearch));
  await tester.tap(find.byKey(Keys.libraryShowSearch));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
