import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/gallery_screen.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/library_controls.dart';

/// A capture name for local noon on [day]; noon keeps the local day in
/// every time zone the tests run in.
String _nameAtNoon(DateTime day, {int second = 0}) {
  final utc = DateTime(day.year, day.month, day.day, 12, 0, second).toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}-${two(utc.minute)}-${two(utc.second)}.000Z.jpg';
}

void main() {
  test('captures split where the local day changes', () {
    VaultItem item(String name) => VaultItem(File('/vault/$name.shtr'));
    final groups = dayGroups([
      item(_nameAtNoon(DateTime(2026, 10, 27), second: 1)),
      item(_nameAtNoon(DateTime(2026, 10, 27))),
      item(_nameAtNoon(DateTime(2026, 10, 26))),
      item('holiday.jpg'),
      item('party.jpg'),
    ]);
    expect(groups, [
      (day: DateTime(2026, 10, 27), start: 0, count: 2),
      (day: DateTime(2026, 10, 26), start: 2, count: 1),
      (day: null, start: 3, count: 2),
    ]);
    expect(dayGroups(const []), isEmpty);
  });

  testWidgets('sorted by date, each day has a header; sorted by name, none', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    const channel = MethodChannel('quietake/previews');
    late Directory dir;
    late Session session;
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-gallery-days');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        dir,
      );
      final jpg = await File('test_fixtures/tiny.jpg').readAsBytes();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => {'bytes': jpg},
      );
      for (final name in [
        _nameAtNoon(DateTime.now()),
        _nameAtNoon(DateTime(2026, 10, 27), second: 1),
        _nameAtNoon(DateTime(2026, 10, 27)),
        _nameAtNoon(DateTime(2026, 10, 26)),
      ]) {
        final plain = await File('${dir.path}/input').writeAsBytes(jpg);
        await vault.ingestAs(plain, name);
      }
      session = Session(
        vault: vault,
        server: await MediaServer.start(vault),
        cast: CastController(vault, FakeCastBackend()),
        store: MasterKeyStore(sodium, dir),
      );
    });
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 150 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        // The test clock moves too, so the sheet can finish closing.
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue);
    }

    bool has(Key key) => find.byKey(key).evaluate().isNotEmpty;
    String header(int start) =>
        tester.widget<Text>(find.byKey(Keys.galleryDay(start))).data!;
    double top(Key key) => tester.getTopLeft(find.byKey(key)).dy;
    try {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: quietakeTheme(),
            home: GalleryScreen(session: session),
          ),
        );
      });
      await until(() => has(Keys.galleryTile(3)));
      expect(header(0), 'Today');
      expect(header(1), 'Tuesday, October 27, 2026');
      expect(header(3), 'Monday, October 26, 2026');
      expect(has(Keys.galleryDay(2)), isFalse);
      // A header sits above its own day; one day's captures share a row.
      expect(top(Keys.galleryDay(1)), greaterThan(top(Keys.galleryTile(0))));
      expect(top(Keys.galleryDay(1)), lessThan(top(Keys.galleryTile(1))));
      expect(top(Keys.galleryTile(1)), top(Keys.galleryTile(2)));
      expect(top(Keys.galleryTile(3)), greaterThan(top(Keys.galleryDay(3))));
      expect(
        tester
            .getSemantics(find.byKey(Keys.galleryDay(1)))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      // Tiles are still counted across the days.
      expect(
        tester.getSemantics(find.byKey(Keys.galleryTile(3))).label,
        contains('4 of 4'),
      );
      expect(
        tester
            .widget<CustomScrollView>(find.byKey(Keys.galleryGrid))
            .semanticChildCount,
        4,
      );

      await revealLibraryControl(tester, Keys.librarySort);
      await tester.tap(find.byKey(Keys.librarySort));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Name').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.byKey(Keys.libraryViewApply));
      await tester.tap(find.byKey(Keys.libraryViewApply));
      await until(() => !has(Keys.libraryViewApply));
      await until(() => has(Keys.galleryTile(3)));
      for (final start in [0, 1, 3]) {
        expect(has(Keys.galleryDay(start)), isFalse);
      }
      expect(top(Keys.galleryTile(0)), top(Keys.galleryTile(1)));
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await session.close();
        await dir.delete(recursive: true);
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    }
  });
}
