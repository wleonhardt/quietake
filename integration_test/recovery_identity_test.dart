import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quietake/keys.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'live empty vault rejects another recovery identity without replacing passcode',
    (tester) async {
      final app = await TestApp.unlocked();
      for (final entry in await app.vault.dir.list().toList()) {
        await entry.delete(recursive: true);
      }
      (await app.session.store.createWithPasscode('identity-test-old'))
          .dispose();
      final foreign = app.vault.crypto.generateMasterKey();
      Future<void> until(bool Function() done) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (!done()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Recovery identity checkpoint timed out');
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> tap(Key key) async {
        await until(() => find.byKey(key).evaluate().isNotEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<void> enter(Key key, String value) async {
        final field = find.byKey(key);
        await tester.enterText(field, value);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));
        final controller = tester.widget<TextField>(field).controller!;
        if (controller.text != value) controller.text = value;
        await tester.pump();
      }

      try {
        await tester.pumpWidget(app.widget());
        await tap(Keys.lockNow);
        await tap(Keys.lockRecovery);
        expect(
          tester
              .widget<TextField>(find.byKey(Keys.setupRecoveryKey))
              .obscureText,
          isTrue,
        );
        await enter(
          Keys.setupRecoveryKey,
          app.session.store.exportRecovery(foreign),
        );
        await enter(Keys.setupPasscode, 'identity-test-new');
        await enter(Keys.setupConfirm, 'identity-test-new');
        await tap(Keys.setupSubmit);
        await until(
          () =>
              find.byKey(Keys.setupError).evaluate().isNotEmpty ||
              find.byKey(Keys.shutter).evaluate().isNotEmpty,
        );
        expect(
          find.byKey(Keys.setupError),
          findsOneWidget,
          reason: 'Another key must not replace the keyfile while the live session retains its original key',
        );
        (await app.session.store.unlockWithPasscode('identity-test-old'))
            .dispose();
        expect(await app.vault.list(), isEmpty);
        await enter(
          Keys.setupRecoveryKey,
          app.session.store.exportRecovery(app.vault.masterKeyForTests),
        );
        await enter(Keys.setupPasscode, 'identity-test-new');
        await enter(Keys.setupConfirm, 'identity-test-new');
        await tap(Keys.setupSubmit);
        await until(() => find.byKey(Keys.shutter).evaluate().isNotEmpty);
        final restored = await app.session.store.unlockWithPasscode(
          'identity-test-new',
        );
        try {
          final plain = await File(
            '${(await getTemporaryDirectory()).path}/identity-capture.jpg',
          ).writeAsBytes(fixtureBytes('tiny.jpg'));
          final saved = await app.vault.ingestAs(plain, 'identity-capture.jpg');
          final bytes = await app.vault.crypto
              .decrypt(saved.openRead(), restored)
              .expand((chunk) => chunk)
              .toList();
          expect(bytes, fixtureBytes('tiny.jpg'));
          expect(await plain.exists(), isFalse);
        } finally {
          restored.dispose();
        }
        expect(tester.takeException(), isNull);
      } finally {
        foreign.dispose();
        await tester.pumpWidget(const SizedBox());
        await app.close();
      }
    },
  );
}
