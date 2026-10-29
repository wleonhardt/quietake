import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/viewer_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    for (final delete in [false, true]) {
      testWidgets(
        '${delete ? 'delete' : 'share'} confirmation fits $size with large text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          FlutterSecureStorage.setMockInitialValues({});
          final privacy = PrivacyController(onLock: () {})..minutes = 0;
          privacy.setEnabled(true);
          addTearDown(privacy.dispose);
          late Directory dir;
          late Session session;
          late File photo;
          await tester.runAsync(() async {
            final sodium = await SodiumSumoInit.init();
            dir = await Directory.systemTemp.createTemp('quietake-dialog');
            final vault = Vault(
              VaultCrypto(sodium),
              sodium.crypto.secretBox.keygen(),
              dir,
            );
            final plain = await File('test_fixtures/tiny.jpg')
                .copy('${dir.path}/input.jpg');
            photo = await vault.ingestAs(plain, 'photo.jpg');
            session = Session(
              vault: vault,
              server: await MediaServer.start(vault),
              cast: CastController(vault, FakeCastBackend()),
              store: MasterKeyStore(sodium, dir),
            );
          });
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.runAsync(() async {
              await session.close();
              await dir.delete(recursive: true);
            });
          });
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: PrivacyScope(controller: privacy, child: child!),
              ),
              home: ViewerScreen(
                session: session,
                items: [VaultItem(photo)],
                initialIndex: 0,
              ),
            ),
          );
          await tester.pump();
          expect(tester.getSize(find.byType(AppBar)).height, lessThanOrEqualTo(56));
          final title = tester.renderObject<RenderParagraph>(
            find.byKey(Keys.viewerPosition),
          );
          expect(title.size.width, greaterThan(0));
          expect(title.didExceedMaxLines, isFalse);
          for (final key in [
            Keys.lockNow,
            Keys.viewerShare,
            Keys.viewerDelete,
            Keys.viewerCast,
          ]) {
            expect(find.byKey(key).hitTestable(), findsOneWidget);
          }
          await tester.tap(
            find.byKey(delete ? Keys.viewerDelete : Keys.viewerShare),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          if (delete) expect(find.text('Delete from this phone?'), findsOneWidget);
          final cancel = find.byKey(
            delete ? Keys.deleteCancel : Keys.shareCancel,
          );
          await tester.ensureVisible(cancel);
          expect(cancel.hitTestable(), findsOneWidget);
          await tester.tap(cancel);
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(AlertDialog), findsNothing);
          expect(await tester.runAsync(photo.exists), isTrue);
        },
      );
    }
  }
}
