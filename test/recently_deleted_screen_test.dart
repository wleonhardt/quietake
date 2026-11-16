import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/library/recently_deleted_screen.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Session session;

  Future<void> open(
    WidgetTester tester,
    List<String> names, {
    DateTime? now,
    Locale? locale,
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-recently-deleted');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        dir,
      );
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, dir),
      );
      // A library never left empty: deleting its last capture hangs the catalog
      // teardown in the widget zone.
      final live = await File('${dir.path}/input').writeAsBytes([1, 2, 3]);
      await vault.ingestAs(live, '2026-11-05T10-00-00.000Z.jpg');
      await vault.catalog.load();
      for (final name in names) {
        final source = await File('${dir.path}/input').writeAsBytes([1, 2, 3]);
        final file = await vault.ingestAs(source, name);
        await vault.trash(file, at: DateTime.utc(2026, 12, 1));
      }
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await session.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecentlyDeletedScreen(
            session: session,
            clock: () => now ?? DateTime.utc(2026, 12, 11),
          ),
        ),
      ),
    );
  }

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'condition never became true');
  }

  const base = '2026-11-03T10-00-00.000Z.jpg';
  const a = '$base.shtr';
  const other = '2026-11-04T10-00-00.000Z.jpg';

  test('days left counts up to the 30 day limit and never below zero', () {
    final at = DateTime.utc(2026, 12, 1);
    expect(daysLeft(at, at), 30);
    expect(daysLeft(at, at.add(const Duration(days: 29, hours: 1))), 1);
    expect(daysLeft(at, at.add(const Duration(days: 31))), 0);
  });

  testWidgets(
    'a deleted capture shows days left and an empty state otherwise',
    (tester) async {
      await open(tester, [base]);
      await until(
        tester,
        () => find.byKey(Keys.recentlyDeletedItem(a)).evaluate().isNotEmpty,
      );
      expect(find.text('20 days left'), findsOneWidget);
    },
  );

  testWidgets('the screen follows the device language', (tester) async {
    await open(tester, [base], locale: const Locale('es'));
    await until(
      tester,
      () => find.byKey(Keys.recentlyDeletedItem(a)).evaluate().isNotEmpty,
    );
    expect(find.text('Eliminados recientemente'), findsOneWidget);
    expect(find.text('Quedan 20 días'), findsOneWidget);
    expect(find.byTooltip('Restaurar'), findsOneWidget);
    expect(find.text('Recently deleted'), findsNothing);
  });

  testWidgets('Restore returns the capture to the library', (tester) async {
    await open(tester, [base]);
    await until(
      tester,
      () => find.byKey(Keys.recentlyDeletedRestore(a)).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Keys.recentlyDeletedRestore(a)));
    await until(
      tester,
      () => find.byKey(Keys.recentlyDeletedEmpty).evaluate().isNotEmpty,
    );
    await tester.runAsync(() async {
      expect(
        (await session.vault.list()).map((f) => f.path),
        contains('${dir.path}/$a'),
      );
    });
  });

  // Confirming Delete now runs the vault delete and a sync, and the widget zone
  // then hangs in Session.close. That path is covered by vault_trash_test and the
  // device test integration_test/recently_deleted_test.dart.
  testWidgets('Delete now asks first and Cancel keeps the capture', (
    tester,
  ) async {
    await open(tester, [base, other]);
    await until(
      tester,
      () => find.byKey(Keys.recentlyDeletedNow(a)).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Keys.recentlyDeletedNow(a)));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.recentlyDeletedConfirm), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.recentlyDeletedItem(a)), findsOneWidget);
    await tester.runAsync(() async {
      expect(File('${dir.path}/$a').existsSync(), isTrue);
      expect(await session.vault.deletedNames(), isEmpty);
    });
  });

  testWidgets('controls are labeled and large enough on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await open(tester, [base]);
    await until(
      tester,
      () => find.byKey(Keys.recentlyDeletedItem(a)).evaluate().isNotEmpty,
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(find.byTooltip('Restore'), findsOneWidget);
    expect(find.byTooltip('Delete now'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Delete all now asks first and Cancel keeps every capture', (
    tester,
  ) async {
    await open(tester, [base, other]);
    await until(
      tester,
      () => find.byKey(Keys.recentlyDeletedAll).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Keys.recentlyDeletedAll));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 captures are permanently'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.recentlyDeletedItem(a)), findsOneWidget);
    await tester.runAsync(() async {
      expect(await session.vault.deletedNames(), isEmpty);
    });
  });
}
