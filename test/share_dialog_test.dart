import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/share_dialog.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Vault vault;
  late VaultItem item;
  var shareCalls = 0;
  var shareFails = false;

  setUp(() async {
    shareCalls = 0;
    shareFails = false;
    root = await Directory.systemTemp.createTemp('quietake-share-dialog');
    final sodium = await SodiumSumoInit.init();
    vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      await Directory('${root.path}/vault').create(),
    );
    final plain = await File('${root.path}/in.mp4')
        .writeAsBytes(List.generate(4096, (i) => i % 251));
    item = VaultItem(await vault.ingestAs(plain, 'clip.mp4'));
    binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(paths, (_) async => root.path)
      ..setMockMethodCallHandler(share, (_) async {
        shareCalls++;
        if (shareFails) throw PlatformException(code: 'unavailable');
        return '';
      });
  });

  tearDown(() async {
    binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(share, null)
      ..setMockMethodCallHandler(paths, null);
    vault.dispose();
    await root.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () => showShareCopies(context, vault, [
              item,
            ], origin: const Rect.fromLTWH(0, 0, 10, 10)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> settleReal(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('warns about unencrypted copies and strips GPS by default', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Share a copy?'), findsOneWidget);
    expect(find.textContaining('unencrypted copies'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(Keys.shareStripLocation))
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(Keys.shareStripLocation));
    await tester.pump();
    expect(find.textContaining('keep all original metadata'), findsOneWidget);
  });

  testWidgets('cancel closes without preparing or sharing', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.shareCancel));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.shareDialog), findsNothing);
    expect(shareCalls, 0);
    expect(Directory('${root.path}/quietake-share').existsSync(), isFalse);
  });

  testWidgets('successful share hands off once and closes', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.shareConfirm));
    await settleReal(
      tester,
      () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.shareDialog), findsNothing);
    expect(shareCalls, 1);
  });

  testWidgets('damaged capture names the item, keeps dialog, never shares', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await item.file.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await item.file.writeAsBytes(bytes);
    });
    await open(tester);
    await tester.tap(find.byKey(Keys.shareConfirm));
    await settleReal(
      tester,
      () => find.byKey(Keys.shareError).evaluate().isNotEmpty,
    );
    expect(find.byKey(Keys.shareError), findsOneWidget);
    expect(find.textContaining(item.name), findsOneWidget);
    expect(find.byKey(Keys.shareDialog), findsOneWidget);
    expect(shareCalls, 0);
    expect(
      tester.widget<FilledButton>(find.byKey(Keys.shareConfirm)).onPressed,
      isNotNull,
    );
  });

  testWidgets('a failing chooser shows a retry message and keeps the dialog', (
    tester,
  ) async {
    shareFails = true;
    await open(tester);
    await tester.tap(find.byKey(Keys.shareConfirm));
    await settleReal(
      tester,
      () => find.byKey(Keys.shareError).evaluate().isNotEmpty,
    );
    expect(
      tester.widget<Text>(find.byKey(Keys.shareError)).data,
      'Could not share. Another share may still be finishing. Try again.',
    );
    expect(find.byKey(Keys.shareDialog), findsOneWidget);
    shareFails = false;
    await tester.tap(find.byKey(Keys.shareConfirm));
    await settleReal(
      tester,
      () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.shareDialog), findsNothing);
  });
}
