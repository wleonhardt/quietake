import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/app_localizations.dart';
import 'package:quietake/library/merge_target.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Directory dir;
  late Vault vault;
  late String source;
  late String target;

  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    dir = await Directory.systemTemp.createTemp('merge-target-');
    vault = Vault(VaultCrypto(sodium), sodium.crypto.secretBox.keygen(), dir);
    source = await vault.catalog.createAlbum('Jogging');
    target = await vault.catalog.createAlbum('Running');
  });

  tearDown(() async {
    await vault.catalog.close();
    vault.dispose();
    await dir.delete(recursive: true);
  });

  Future<Future<String?>> open(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final result = chooseMergeTarget(context, vault.catalog, source);
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('lists other tags, filters by search and says when none match', (
    tester,
  ) async {
    final result = await open(tester);
    expect(find.byKey(Keys.tagMergeTarget(target)), findsOneWidget);
    expect(find.byKey(Keys.tagMergeTarget(source)), findsNothing);
    await tester.enterText(find.byKey(Keys.tagMergeSearch), 'zzz');
    await tester.pump();
    expect(find.byKey(Keys.tagMergeTarget(target)), findsNothing);
    expect(find.text('No matching tags'), findsOneWidget);
    await tester.tap(find.byKey(Keys.tagMergeClose));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('tapping a tag returns its ID', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byKey(Keys.tagMergeTarget(target)));
    await tester.pumpAndSettle();
    expect(await result, target);
  });
}
