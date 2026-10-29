import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/tag_picker.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  for (final remove in [false, true]) {
    testWidgets(
      'batch tag picker counts, search and cancellation; remove=$remove',
      (tester) async {
        late Directory dir;
        late Vault vault;
        late String subject;
        late String action;
        await tester.runAsync(() async {
          final sodium = await SodiumSumoInit.init();
          dir = await Directory.systemTemp.createTemp('tag-picker');
          vault = Vault(
            VaultCrypto(sodium),
            sodium.crypto.secretBox.keygen(),
            dir,
          );
          subject = await vault.catalog.createAlbum('Alex');
          action = await vault.catalog.createAlbum('Running');
          await vault.catalog.organize({'one.jpg.shtr'}, tagIds: {subject});
        });
        Set<String>? choice;
        Future<void> tap(Key key) async {
          final finder = find.byKey(key);
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              100,
              scrollable: find.byType(Scrollable).last,
            );
          }
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: quietakeTheme(),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      choice = await chooseTags(
                        context,
                        vault.catalog,
                        captures: {'one.jpg.shtr', 'two.jpg.shtr'},
                        remove: remove,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('1 of 2 already tagged'), findsOneWidget);
          expect(find.text('0 of 2 already tagged'), findsOneWidget);
          await tap(Keys.albumChoose(subject));
          await tap(Keys.tagPickerClose);
          expect(choice, isNull);
          expect(vault.catalog.details('two.jpg.shtr').albums, isEmpty);
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tap(Keys.albumChoose(subject));
          await tester.enterText(find.byKey(Keys.tagPickerSearch), 'running');
          await tester.pump();
          expect(find.byKey(Keys.albumChoose(subject)), findsNothing);
          await tap(Keys.albumChoose(action));
          await tap(Keys.tagPickerApply);
          expect(choice, {subject, action});
          expect(
            vault.catalog.details('one.jpg.shtr').albums,
            {subject},
            reason: 'Picker does not write memberships before the caller applies the result',
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(() async {
            await vault.catalog.close();
            vault.dispose();
            await dir.delete(recursive: true);
          });
        }
      },
    );
  }
}
