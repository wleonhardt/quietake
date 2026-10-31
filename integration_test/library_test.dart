import '../test_support/integration_binding.dart';
import '../test_support/library_controls.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/library/library_query.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  initializeIntegrationBinding();

  testWidgets('private library organizes, searches and preserves originals', (
    tester,
  ) async {
    final elapsed = Stopwatch()..start();
    void checkpoint(String phase) {
      // ignore: avoid_print
      print('LIBRARY phase=$phase elapsed_ms=${elapsed.elapsedMilliseconds}');
    }

    final app = await TestApp.unlocked();
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    for (final name in ['2026-01.jpg', '2026-02.mp4', '2026-03.jpg']) {
      final tmp = File('${(await getTemporaryDirectory()).path}/library-seed');
      await tmp.writeAsBytes(
        fixtureBytes(name.endsWith('mp4') ? 'tiny.mp4' : 'tiny.jpg'),
      );
      await app.vault.ingestAs(tmp, name);
    }
    Future<void> until(bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!done()) {
        if (DateTime.now().isAfter(deadline)) {
          fail(
            'Library deadline: photo=${find.byKey(Keys.viewerPhoto).evaluate().length}, video=${find.byKey(Keys.viewerVideo).evaluate().length}, lock=${find.byKey(Keys.lockPasscode).evaluate().length}, error=${find.byKey(Keys.viewerError).evaluate().length}',
          );
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tap(Key key) async {
      await revealLibraryControl(tester, key);
      await until(() => find.byKey(key).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(key));
      await tester.pump(const Duration(milliseconds: 500));
      if ([
        Keys.libraryAll,
        Keys.libraryPhotos,
        Keys.libraryVideos,
        Keys.libraryFavorites,
        Keys.librarySortOldest,
      ].contains(key)) {
        await applyLibraryView(tester);
      }
    }

    Future<void> enter(Key key, String value) async {
      await revealLibraryControl(tester, key);
      await tester.enterText(find.byKey(key), value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      final field = tester.widget<TextField>(find.byKey(key));
      if (field.controller!.text != value) {
        field.controller!.text = value;
        field.onChanged?.call(value);
      }
      await tester.pump();
      expect(field.controller!.text, value);
      if (key == Keys.librarySearch) await showLibrarySearch(tester);
    }

    Future<void> name(String value) async {
      await enter(Keys.libraryName, value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      await tap(Keys.librarySave);
    }

    int count() => tester
        .widget<GridView>(find.byKey(Keys.galleryGrid))
        .childrenDelegate
        .estimatedChildCount!;
    try {
      await tester.pumpWidget(app.widget());
      await tap(Keys.openGallery);
      await until(() => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty);
      expect(count(), 3);
      checkpoint('seeded-gallery');
      await tester.binding.setSurfaceSize(const Size(320, 360));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.drag(find.byKey(Keys.galleryGrid), const Offset(0, -160));
      await tester.pumpAndSettle();
      double scrollOffset() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(Keys.galleryGrid),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      final beforeSearch = scrollOffset();
      expect(beforeSearch, greaterThan(0));
      await revealLibraryControl(tester, Keys.librarySearch);
      await tap(Keys.libraryCloseSearch);
      await until(() => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty);
      expect(
        scrollOffset(),
        closeTo(beforeSearch, 1),
        reason: 'Closing focused Search restores the existing Library scroll position',
      );
      checkpoint('search-scroll-restored');
      await tester.binding.setSurfaceSize(null);
      await tester.pump(const Duration(milliseconds: 500));
      await tap(Keys.libraryAlbums);
      await tap(Keys.albumCreate);
      await name('Private holiday');
      await until(() => app.vault.catalog.albums.isNotEmpty);
      final id = app.vault.catalog.albums.keys.single;
      await tap(Keys.albumMenu(id));
      await tap(Keys.albumRename);
      await name('Quiet weekend');
      await until(() => app.vault.catalog.albums[id] == 'Quiet weekend');
      checkpoint('tag-created-renamed');
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.longPress(find.byKey(Keys.galleryTile(0)));
      await tester.pump();
      await tap(Keys.galleryTile(1));
      await tap(Keys.libraryFavorite);
      await tap(Keys.libraryAddAlbum);
      await tap(Keys.albumChoose(id));
      await tap(Keys.tagPickerApply);
      await tap(Keys.libraryCancelSelection);
      await tap(Keys.libraryFavorites);
      expect(count(), 2);
      await tap(Keys.libraryPhotos);
      expect(count(), 1);
      await tap(Keys.librarySelect);
      await tap(Keys.librarySelectAll);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byKey(Keys.galleryCast).hitTestable(), findsOneWidget);
      await tap(Keys.libraryFavorite);
      await until(
        () => find.byKey(Keys.libraryNoResults).evaluate().isNotEmpty,
      );
      expect(app.vault.catalog.details('2026-03.jpg.shtr').favorite, isFalse);
      expect(app.vault.catalog.details('2026-02.mp4.shtr').favorite, isTrue);
      expect(app.vault.catalog.details('2026-01.jpg.shtr').favorite, isFalse);
      await tap(Keys.libraryCancelSelection);
      await tap(Keys.libraryFavorites);
      expect(count(), 2);
      await tester.longPress(find.byKey(Keys.galleryTile(0)));
      await tester.pump();
      await tap(Keys.libraryFavorite);
      await tap(Keys.libraryCancelSelection);
      await tap(Keys.libraryFavorites);
      expect(count(), 1);

      await tap(Keys.libraryVideos);
      expect(count(), 1);
      await tap(Keys.libraryAll);
      await tap(Keys.libraryFavorites);
      expect(count(), 3);

      await tester.longPress(find.byKey(Keys.galleryTile(0)));
      await tester.pump();
      await tap(Keys.libraryRename);
      checkpoint('favorites-filtered');
      await name('Evening glow');
      await tap(Keys.libraryCancelSelection);
      await enter(Keys.librarySearch, 'EVENING');
      await tester.pump();
      expect(count(), 1);
      await enter(Keys.librarySearch, 'absent');
      await tester.pump();
      expect(find.byKey(Keys.libraryNoResults), findsOneWidget);
      expect(find.byKey(Keys.galleryEmpty), findsNothing);
      await tap(Keys.libraryClearFilters);
      expect(count(), 3);
      expect(find.byKey(Keys.libraryNoResults), findsNothing);
      await enter(Keys.librarySearch, 'weekend');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      expect(count(), 2, reason: 'Search includes encrypted album names');
      await enter(Keys.librarySearch, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));

      expect(count(), 3);
      await tap(Keys.librarySort);
      await tap(Keys.librarySortOldest);
      await revealLibraryControl(tester, Keys.librarySort);
      expect(
        tester
            .widget<PopupMenuButton<LibrarySort>>(find.byKey(Keys.librarySort))
            .initialValue,
        LibrarySort.oldest,
      );
      await applyLibraryView(tester);
      await tap(Keys.galleryTile(0));
      await until(() => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty);
      await tap(Keys.viewerFavorite);
      await until(() => app.vault.catalog.details('2026-01.jpg.shtr').favorite);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      final reopened = PrivateCatalog(app.vault);
      await reopened.load();
      expect(reopened.details('2026-03.jpg.shtr').title, 'Evening glow');
      expect(reopened.details('2026-02.mp4.shtr').albums, {id});
      expect(reopened.details('2026-01.jpg.shtr').favorite, isTrue);
      await reopened.close();
      checkpoint('search-sort-persisted');

      await tap(Keys.libraryAlbums);
      await tap(Keys.albumCreate);
      await name('Running');
      await until(() => app.vault.catalog.albums.containsValue('Running'));
      final action = app.vault.catalog.albums.entries
          .singleWhere((e) => e.value == 'Running')
          .key;
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.longPress(find.byKey(Keys.galleryTile(1)));
      await tester.pump();
      await tap(Keys.libraryAddAlbum);
      await tap(Keys.albumChoose(id));
      await tap(Keys.albumChoose(action));
      await tap(Keys.tagPickerApply);
      await tap(Keys.libraryCancelSelection);
      expect(app.vault.catalog.details('2026-02.mp4.shtr').albums, {
        id,
        action,
      });

      await tap(Keys.libraryAlbums);
      await tap(Keys.tagBrowse(action));
      await until(() => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty);
      expect(count(), 1);
      await tap(Keys.libraryCloseSearch);
      await tap(Keys.libraryUntagged);
      await until(() => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty);
      expect(count(), 1);
      await tap(Keys.libraryCloseSearch);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));

      await revealLibraryControl(tester, Keys.librarySearch);
      await tap(Keys.libraryTag(id));
      await tap(Keys.libraryTag(action));
      await showLibrarySearch(tester);
      expect(
        count(),
        1,
        reason: 'Subject and action use intersection by default',
      );
      checkpoint('tag-intersection');
      await tap(Keys.librarySearchOptions);
      await tap(Keys.libraryMatchAny);
      expect(count(), 2);
      await tap(Keys.librarySearchOptions);
      await tap(Keys.libraryMatchAll);
      expect(count(), 1);
      await tap(Keys.libraryAlbums);
      await tap(Keys.albumMenu(action));
      await tap(Keys.tagMerge);
      await tap(Keys.tagMergeTarget(id));
      await tap(Keys.tagMergeConfirm);
      await until(() => !app.vault.catalog.albums.containsKey(action));
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        count(),
        2,
        reason:
            'Merge preserves the destination and clears the stale search chip',
      );
      await tester.longPress(find.byKey(Keys.galleryTile(0)));
      await tester.pump();
      await tap(Keys.libraryRemoveAlbum);
      await tap(Keys.albumChoose(id));
      await tap(Keys.tagPickerApply);
      await until(() => count() == 1);
      await tap(Keys.libraryCancelSelection);
      await tap(Keys.libraryAlbums);
      await tap(Keys.albumMenu(id));
      await tap(Keys.albumDelete);
      await tap(Keys.albumDeleteConfirm);
      await until(() => app.vault.catalog.albums.isEmpty);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        count(),
        3,
        reason: 'Deleting selected album restores All albums scope',
      );
      expect(await app.vault.list(), hasLength(3));
      expect(await app.vault.deletedNames(), isEmpty);
      for (final file in await app.vault.list()) {
        expect(
          await app.vault.readAll(file),
          fixtureBytes(file.path.contains('.mp4') ? 'tiny.mp4' : 'tiny.jpg'),
        );
      }
      checkpoint('tags-merged-removed-originals-verified');
      await tap(Keys.galleryTile(0));
      await until(() => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty);
      await tap(Keys.viewerDelete);
      await tap(Keys.deleteConfirm);
      await until(
        () => !app.vault.catalog.items.containsKey('2026-01.jpg.shtr'),
      );
      await until(
        () =>
            find.byKey(Keys.viewerPosition).evaluate().isNotEmpty &&
            tester.widget<Text>(find.byKey(Keys.viewerPosition)).data ==
                '1 / 2' &&
            tester
                    .widget<IconButton>(find.byKey(Keys.viewerDelete))
                    .onPressed !=
                null,
      );

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await until(() => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty);
      expect(count(), 2);
      expect(await app.vault.deletedNames(), contains('2026-01.jpg.shtr'));
      expect(tester.takeException(), isNull);
      checkpoint('deletion-verified');
    } finally {
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      await app.close();
      checkpoint('closed');
    }
    // This end-to-end workflow previously passed in 144 s on Android and 132 s
    // on iOS. Keep the shared two-minute default for shorter cases and the
    // independent five-minute file watchdog; allow this measured longer case.
  }, timeout: const Timeout(Duration(minutes: 3)));
}
