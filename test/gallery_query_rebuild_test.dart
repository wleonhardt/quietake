import '../test_support/library_controls.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/gallery_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/sync/sync_controller.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

class _Catalog extends PrivateCatalog {
  _Catalog(super.vault);
  int metadataReads = 0;
  int loads = 0;
  @override
  Future<void> load() {
    loads++;
    return super.load();
  }

  @override
  Map<String, CaptureDetails> get items {
    metadataReads++;
    return super.items;
  }
}

class _Vault extends Vault {
  _Vault(super.crypto, super.key, super.dir);
  late final _catalog = _Catalog(this);
  @override
  _Catalog get catalog => _catalog;
}

class _Sync extends SyncController {
  _Sync(super.vault);
  @override
  Future<void> sync() async {}
  void progress({bool finished = false}) {
    state = finished ? SyncState.synced : SyncState.syncing;
    notifyListeners();
  }
}

class _Session extends Session {
  _Session({
    required super.vault,
    required super.server,
    required super.cast,
    required super.store,
  });
  late final _sync = _Sync(vault);
  @override
  _Sync get sync => _sync;
}

void main() {
  testWidgets(
    'selection and progress reuse query, but changed inputs refresh results',
    (tester) async {
      late Directory dir;
      late _Vault vault;
      late _Session session;
      await tester.runAsync(() async {
        final sodium = await SodiumSumoInit.init();
        dir = await Directory.systemTemp.createTemp('quietake-query-rebuild');
        vault = _Vault(
          VaultCrypto(sodium),
          sodium.crypto.secretBox.keygen(),
          dir,
        );
        final input = await File('test_fixtures/tiny.jpg')
            .copy('${dir.path}/input.jpg');
        await vault.ingestAs(input, 'photo.jpg');
        session = _Session(
          vault: vault,
          server: await MediaServer.start(vault),
          cast: CastController(vault, FakeCastBackend()),
          store: MasterKeyStore(sodium, dir),
        );
      });
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if (done()) return;
        }
        fail('Gallery query did not settle');
      }

      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(home: GalleryScreen(session: session)),
          );
        });
        await until(
          () => find.byKey(Keys.galleryPreview).evaluate().isNotEmpty,
        );
        final reads = vault.catalog.metadataReads;
        await tester.longPress(find.byKey(Keys.galleryTile(0)));
        await tester.pump();
        expect(find.text('1 selected'), findsOneWidget);
        await tester.tap(find.byKey(Keys.galleryTile(0)));
        await tester.pump();
        expect(find.text('0 selected'), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          session.sync.progress();
          await tester.pump();
        }
        expect(
          vault.catalog.metadataReads,
          reads,
          reason:
              'Selection and transfer progress must not scan library metadata',
        );
        // Only the syncing-to-idle edge reloads; idle notifications do not.
        final loads = vault.catalog.loads;
        session.sync.progress(finished: true);
        await tester.pump();
        await until(() => vault.catalog.loads == loads + 1);
        for (var i = 0; i < 3; i++) {
          session.sync.progress(finished: true);
          await tester.pump();
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(vault.catalog.loads, loads + 1);
        // Back to an active transfer for the steps below.
        session.sync.progress();
        await tester.pump();
        await revealLibraryControl(tester, Keys.gallerySync);
        expect(find.byTooltip('Cancel sync'), findsOneWidget);
        await tester.runAsync(
          () async => session.sync.progress(finished: true),
        );
        await until(() => vault.catalog.metadataReads > reads);
        expect(
          find.byTooltip('Sync with NAS'),
          findsOneWidget,
          reason: 'Open actions must reflect a transfer finishing',
        );

        await revealLibraryControl(tester, Keys.librarySearch);
        await until(
          () => find.byKey(Keys.libraryShowSearch).evaluate().isNotEmpty,
        );
        await tester.enterText(find.byKey(Keys.librarySearch), 'garden');
        await showLibrarySearch(tester);
        expect(find.byKey(Keys.libraryNoResults), findsOneWidget);
        expect(vault.catalog.metadataReads, greaterThan(reads));
        await tester.runAsync(
          () => vault.catalog.renameItem('photo.jpg.shtr', 'Garden'),
        );
        await tester.pump();
        expect(find.byKey(Keys.galleryTile(0)), findsOneWidget);
        expect(find.text('Garden'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.longPress(find.byKey(Keys.galleryTile(0)));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byKey(Keys.libraryCancelSelection));
        await tester.pump();
        await tester.runAsync(
          () => tester.tap(find.byKey(Keys.libraryCloseSearch)),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(Keys.librarySearch), findsNothing);
        await revealLibraryControl(tester, Keys.librarySearch);
        await until(
          () => find.byKey(Keys.libraryShowSearch).evaluate().isNotEmpty,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(Keys.librarySearch))
              .controller!
              .text,
          isEmpty,
        );
        await tester.enterText(find.byKey(Keys.librarySearch), 'garden');
        await showLibrarySearch(tester);
        await tester.runAsync(() async {
          final input = await File('test_fixtures/tiny.jpg')
              .copy('${dir.path}/input.jpg');
          await vault.ingestAs(input, 'garden.jpg');
          // Search matches titles, not filenames (decision 036).
          await vault.catalog.renameItem('garden.jpg.shtr', 'Garden path');
          // A real transfer passes through syncing before it finishes.
          session.sync.progress();
          session.sync.progress(finished: true);
        });
        await until(
          () => find.byKey(Keys.galleryTile(1)).evaluate().isNotEmpty,
        );
        expect(find.byKey(Keys.galleryTile(1)), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          await session.close();
          await dir.delete(recursive: true);
        });
      }
    },
  );
}
