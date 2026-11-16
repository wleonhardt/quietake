import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/moments_screen.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Session session;

  Future<void> open(WidgetTester tester, List<String> names) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-moments');
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
      for (final name in names) {
        final source = await File('${dir.path}/input').writeAsBytes([1, 2, 3]);
        await vault.ingestAs(source, name);
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
      () =>
          tester.pumpWidget(MaterialApp(home: MomentsScreen(session: session))),
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

  testWidgets('months are listed newest first with their capture counts', (
    tester,
  ) async {
    await open(tester, [
      '2026-10-31T23-59-59.jpg',
      '2026-11-03T10-00-00.jpg',
      '2026-11-20T08-30-00.mp4',
      'undated.jpg',
    ]);
    await until(
      tester,
      () => find.byKey(Keys.momentMonth('2026-11')).evaluate().isNotEmpty,
    );
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('2 captures'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('1 capture'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('November 2026')).dy <
          tester.getTopLeft(find.text('October 2026')).dy,
      isTrue,
    );
  });

  testWidgets('a vault without dated captures says so', (tester) async {
    await open(tester, ['undated.jpg']);
    await until(
      tester,
      () => find.text('No dated captures yet').evaluate().isNotEmpty,
    );
  });
}
