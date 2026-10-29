import '../test_support/library_controls.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/main.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/vault.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

/// Holds one selected read so native UI can cancel or lock during preparation.
class GatedVault extends Vault {
  GatedVault(Vault original)
    : super(original.crypto, original.masterKeyForTests.copy(), original.dir);
  bool block = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Stream<List<int>> read(File container) async* {
    if (block) {
      block = false;
      entered.complete();
      await release.future;
    }
    yield* super.read(container);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/share');

  Future<void> until(WidgetTester tester, bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Sharing checkpoint timed out');
      }
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
    if (key == Keys.libraryPhotos) await applyLibraryView(tester);
  }

  Future<void> seed(TestApp app) async {
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    for (final name in ['2026-01.jpg', '2026-02.mp4', '2026-03.png']) {
      final source =
          await File('${(await getTemporaryDirectory()).path}/share-seed')
              .writeAsBytes(
                fixtureBytes(
                  name.endsWith('mp4')
                      ? 'tiny.mp4'
                      : name.endsWith('png')
                      ? 'wide.png'
                      : 'tiny.jpg',
                ),
              );
      await app.vault.ingestAs(source, name);
    }
  }

  testWidgets(
    'filtered selection shares only chosen copies, mixed batch stays byte-identical',
    (tester) async {
      final app = await TestApp.unlocked();
      await seed(app);
      final originals = {
        for (final file in await app.vault.list())
          file.path: await file.readAsBytes(),
      };
      final sent = <List<String>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        final mimes = (args['mimeTypes'] as List).cast<String>();
        final paths = (args['paths'] as List).cast<String>();
        for (var i = 0; i < paths.length; i++) {
          final fixture = switch (mimes[i]) {
            'video/mp4' => 'tiny.mp4',
            'image/png' => 'wide.png',
            _ => 'tiny.jpg',
          };
          expect(await File(paths[i]).readAsBytes(), fixtureBytes(fixture));
        }
        sent.add(mimes);
        return '';
      });
      try {
        await tester.pumpWidget(app.widget());
        await tap(tester, Keys.openGallery);
        await tap(tester, Keys.libraryPhotos);
        await tap(tester, Keys.librarySelect);
        await tap(tester, Keys.librarySelectAll);
        await tap(tester, Keys.libraryShare);
        expect(find.byKey(Keys.shareStripLocation), findsOneWidget);
        await tap(tester, Keys.shareCancel);
        expect(sent, isEmpty);
        await tap(tester, Keys.libraryShare);
        await tap(tester, Keys.shareConfirm);
        await until(
          tester,
          () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
        );
        expect(sent.single.toSet(), {'image/jpeg', 'image/png'});
        await tap(tester, Keys.libraryCancelSelection);
        await tap(tester, Keys.libraryAll);
        await tap(tester, Keys.librarySelect);
        await tap(tester, Keys.librarySelectAll);
        await tap(tester, Keys.libraryShare);
        await tap(tester, Keys.shareConfirm);
        await until(
          tester,
          () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
        );
        expect(sent.last.toSet(), {'image/jpeg', 'image/png', 'video/mp4'});
        expect(sent.last, hasLength(3));
        for (final entry in originals.entries) {
          expect(await File(entry.key).readAsBytes(), entry.value);
        }
        final temp = await getTemporaryDirectory();
        expect(
          await Directory('${temp.path}/quietake-share').exists(),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        await tester.pumpWidget(const SizedBox());
        await app.close();
      }
    },
  );

  testWidgets(
    'damaged selected capture identifies private title and prevents partial sending',
    (tester) async {
      final app = await TestApp.unlocked();
      await seed(app);
      final broken = (await app.vault.list()).firstWhere(
        (f) => f.path.endsWith('.mp4.shtr'),
      );
      await app.vault.catalog.renameItem(
        broken.uri.pathSegments.last,
        'Broken demo',
      );
      final bytes = await broken.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await broken.writeAsBytes(bytes);
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        calls++;
        return '';
      });
      try {
        await tester.pumpWidget(app.widget());
        await tap(tester, Keys.openGallery);
        await tap(tester, Keys.librarySelect);
        await tap(tester, Keys.librarySelectAll);
        await tap(tester, Keys.libraryShare);
        await tap(tester, Keys.shareConfirm);
        await until(
          tester,
          () => find.byKey(Keys.shareError).evaluate().isNotEmpty,
        );
        expect(
          tester.widget<Text>(find.byKey(Keys.shareError)).data,
          contains('Broken demo'),
        );
        expect(calls, 0);
        await tap(tester, Keys.shareCancel);
        expect(find.byKey(Keys.galleryGrid), findsOneWidget);
        expect(await broken.readAsBytes(), bytes);
        final temp = await getTemporaryDirectory();
        expect(
          await Directory('${temp.path}/quietake-share').exists(),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        await tester.pumpWidget(const SizedBox());
        await app.close();
      }
    },
  );

  for (final lock in [false, true]) {
    testWidgets(
      '${lock ? 'manual lock' : 'Back'} during preparation cancels without popping gallery',
      (tester) async {
        final app = await TestApp.unlocked();
        await seed(app);
        (await app.session.store.createWithPasscode('sharing-test-passcode'))
            .dispose();
        final vault = GatedVault(app.vault);
        final backend = FakeCastBackend();
        final session = Session(
          vault: vault,
          server: await MediaServer.start(vault),
          cast: CastController(vault, backend),
          store: app.session.store,
        );
        var calls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async {
            calls++;
            return '';
          },
        );
        try {
          await tester.pumpWidget(
            QuietakeApp(
              session: session,
              store: session.store,
              auth: app.auth,
              castBackend: backend,
            ),
          );
          await tap(tester, Keys.openGallery);
          await tap(tester, Keys.librarySelect);
          await tap(tester, Keys.librarySelectAll);
          await tap(tester, Keys.libraryShare);
          vault.block = true;
          await tap(tester, Keys.shareConfirm);
          await until(tester, () => vault.entered.isCompleted);
          expect(find.byKey(Keys.shareProgress), findsOneWidget);
          if (lock) {
            PrivacyScope.maybeOf(tester.element(find.byKey(Keys.shareDialog)))!
                .lock();
            await until(
              tester,
              () => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty,
            );
          } else {
            await tester.binding.handlePopRoute();
            await tester.pump();
          }
          vault.release.complete();
          final temp = await getTemporaryDirectory();
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (await Directory('${temp.path}/quietake-share').exists()) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Cancelled share did not clean up');
            }
            await tester.pump(const Duration(milliseconds: 100));
          }
          if (lock) {
            await tap(tester, Keys.lockBiometric);
            await until(
              tester,
              () => find.byKey(Keys.galleryGrid).evaluate().isNotEmpty,
            );
          }
          await until(
            tester,
            () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byKey(Keys.shareDialog), findsNothing);
          expect(find.byKey(Keys.galleryGrid), findsOneWidget);
          expect(calls, 0);
          expect(await vault.list(), hasLength(3));
          expect(tester.takeException(), isNull);
        } finally {
          if (!vault.release.isCompleted) vault.release.complete();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          await tester.pumpWidget(const SizedBox());
          await session.close();
          await app.close();
        }
      },
    );
  }
}
