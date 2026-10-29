import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/viewer_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

class _CountingVault extends Vault {
  _CountingVault(super.crypto, super.key, super.dir);
  int reads = 0;
  bool failRead = false;
  bool invalidImage = false;
  @override
  Future<Uint8List> readAll(File container) async {
    reads++;
    if (failRead) throw const FormatException('Corrupt test photo');
    return invalidImage
        ? Uint8List.fromList([1, 2, 3])
        : File('test_fixtures/tiny.jpg').readAsBytesSync();
  }
}

void main() {
  for (final mode in ['valid', 'read-error', 'invalid-image']) {
    final failFirst = mode != 'valid';
    testWidgets(
      failFirst
          ? '$mode offers a working retry'
          : 'rebuild and cast notifications reuse photo decryption',
      (tester) async {
        late Directory dir;
        late Session session;
        late _CountingVault vault;
        await tester.runAsync(() async {
          final sodium = await SodiumSumoInit.init();
          dir = await Directory.systemTemp.createTemp('quietake-viewer');
          vault =
              _CountingVault(
                  VaultCrypto(sodium),
                  sodium.crypto.secretBox.keygen(),
                  dir,
                )
                ..failRead = mode == 'read-error'
                ..invalidImage = mode == 'invalid-image';
          session = Session(
            vault: vault,
            server: await MediaServer.start(vault),
            cast: CastController(vault, FakeCastBackend()),
            store: MasterKeyStore(sodium, dir),
          );
        });
        Widget viewer() => MaterialApp(
          theme: quietakeTheme(brightness: Brightness.light),
          home: ViewerScreen(
            session: session,
            items: [VaultItem(File('${dir.path}/photo.jpg.shtr'))],
            initialIndex: 0,
          ),
        );
        await tester.pumpWidget(viewer());
        await tester.pump();
        expect(Theme.of(tester.element(find.byKey(Keys.viewerPager))).brightness, Brightness.dark);
        if (failFirst) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pump();
          expect(find.byKey(Keys.viewerError), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          vault.failRead = false;
          vault.invalidImage = false;
          await tester.tap(find.byKey(Keys.viewerError));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
        } else {
          await tester.runAsync(session.cast.stop);
          await tester.pumpWidget(viewer());
          await tester.pump();
        }
        expect(find.byKey(Keys.viewerPhoto), findsOneWidget);
        expect(vault.reads, failFirst ? 2 : 1);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await session.close();
          await dir.delete(recursive: true);
        });
      },
    );
  }
}
