import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/library/tag_cover.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';
import '../test_support/png_fixture.dart';

void main() {
  late Directory dir;
  late Session session;
  const name = '2026-10-27T12-00-01.002Z.png';

  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    dir = await Directory.systemTemp.createTemp('quietake-tag-cover');
    final vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      dir,
    );
    final plain = await File('${dir.path}/input')
        .writeAsBytes(await gradientPng());
    await vault.ingestAs(plain, name);
    session = Session(
      vault: vault,
      server: await MediaServer.start(vault),
      cast: CastController(vault, FakeCastBackend()),
      store: MasterKeyStore(sodium, dir),
    );
  });

  tearDown(() async {
    await session.close();
    await dir.delete(recursive: true);
  });

  late Future<String?> result;

  Future<void> open(WidgetTester tester, List<String> names) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () => result = chooseTagCover(context, session, names),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a thumbnail returns that capture name', (tester) async {
    await open(tester, [name]);
    expect(find.byKey(Keys.tagCoverGrid), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.tap(find.byKey(Keys.tagCoverPick(name)));
    await tester.pumpAndSettle();
    expect(await result, name);
    expect(find.byKey(Keys.tagCoverGrid), findsNothing);
  });

  testWidgets('cancel returns null and an empty list shows the empty text', (
    tester,
  ) async {
    await open(tester, const []);
    expect(find.byKey(Keys.tagCoverGrid), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
