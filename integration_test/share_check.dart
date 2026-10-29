import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

/// Explicit native-sheet check. Host verifies ChooserActivity and presses Back;
/// it never chooses a recipient or transmits media to another app.
void main() {
  if (!const bool.fromEnvironment('QUIETAKE_SHARE_CHECK')) {
    throw StateError('Run explicitly with QUIETAKE_SHARE_CHECK=true');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native chooser opens, cancels and clears plaintext copies', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    final temp = await getTemporaryDirectory();
    for (final file in await app.vault.list()) {
      await file.delete();
    }
    final plain = await File('${temp.path}/native-share.jpg')
        .writeAsBytes(fixtureBytes('tiny.jpg'));
    await app.vault.ingestAs(plain, 'test.jpg');
    Future<void> until(bool Function() ready) async {
      final end = DateTime.now().add(const Duration(seconds: 60));
      while (!ready()) {
        if (DateTime.now().isAfter(end)) {
          fail('Native sharing checkpoint timed out');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(app.widget());
    await until(() => find.byKey(Keys.openGallery).evaluate().isNotEmpty);
    await tester.tap(find.byKey(Keys.openGallery));
    await until(() => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.galleryTile(0)));
    await until(() => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.viewerShare));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(Keys.shareConfirm));
    debugPrint('NATIVE_SHARE_WAITING_FOR_HOST_CANCEL');
    await until(
      () =>
          tester.widget<IconButton>(find.byKey(Keys.viewerShare)).onPressed !=
          null,
    );
    expect(await Directory('${temp.path}/quietake-share').exists(), isFalse);
    expect(await Directory('${temp.path}/share_plus').exists(), isFalse);
    final files = await app.vault.list();
    expect(files, hasLength(1));
    expect(await app.vault.readAll(files.single), fixtureBytes('tiny.jpg'));
    await tester.pumpWidget(const SizedBox());
    await app.close();
  });
}
