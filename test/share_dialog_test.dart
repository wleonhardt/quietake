import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/share_dialog.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/png_fixture.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Vault vault;
  late VaultItem item;
  late VaultItem photo;
  late VaultItem photo2;
  List<dynamic> sharedMimes = const [];
  List<dynamic> sharedPaths = const [];
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
    photo = VaultItem(
      await vault.ingestAs(
        await File('${root.path}/pic.png').writeAsBytes(await gradientPng()),
        'pic.png',
      ),
    );
    photo2 = VaultItem(
      await vault.ingestAs(
        await File('${root.path}/pic2.png').writeAsBytes(await gradientPng()),
        'pic2.png',
      ),
    );
    binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(paths, (_) async => root.path)
      ..setMockMethodCallHandler(share, (call) async {
        shareCalls++;
        sharedMimes = (call.arguments as Map)['mimeTypes'] as List;
        sharedPaths = (call.arguments as Map)['paths'] as List;
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

  Future<void> open(
    WidgetTester tester, {
    Locale? locale,
    VaultItem? target,
    List<VaultItem>? targets,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () => showShareCopies(
              context,
              vault,
              targets ?? [target ?? item],
              origin: const Rect.fromLTWH(0, 0, 10, 10),
            ),
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

  testWidgets('warns about unencrypted copies and strips metadata by default', (
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

  testWidgets('the dialog follows the device language', (tester) async {
    await open(tester, locale: const Locale('es'));
    expect(find.text('¿Compartir una copia?'), findsOneWidget);
    expect(find.textContaining('copias sin cifrar'), findsOneWidget);
    expect(find.text('Elegir app'), findsOneWidget);
    expect(find.text('Share a copy?'), findsNothing);
  });

  testWidgets('a video offers no hiding of areas', (tester) async {
    await open(tester);
    expect(find.byKey(Keys.shareRedact), findsNothing);
  });

  testWidgets(
    'hiding areas of a photo shares a PNG and drops the metadata switch',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, target: photo);
      expect(find.byKey(Keys.shareStripLocation), findsOneWidget);
      await tester.runAsync(() => tester.tap(find.byKey(Keys.shareRedact)));
      await settleReal(
        tester,
        () => find.byKey(Keys.redactCanvas).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(seconds: 1));
      final box = tester.getRect(find.byKey(Keys.redactCanvas));
      final gesture = await tester.startGesture(
        box.topLeft + const Offset(10, 10),
      );
      await gesture.moveTo(box.center);
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(Keys.redactDone));
      await tester.pumpAndSettle();
      // The dialog's await began in the real zone, so let it resume there.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Hidden areas: 1'), findsOneWidget);
      expect(find.byKey(Keys.shareStripLocation), findsNothing);
      expect(find.textContaining('becomes a PNG'), findsOneWidget);
      await tester.tap(find.byKey(Keys.shareConfirm));
      await settleReal(
        tester,
        () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      expect(shareCalls, 1);
      expect(sharedMimes, ['image/png']);
    },
  );

  testWidgets('several photos are hidden one editor page per photo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, targets: [photo, photo2]);
    expect(find.text('Hide parts of these photos…'), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.byKey(Keys.shareRedact)));
    for (var page = 0; page < 2; page++) {
      await settleReal(
        tester,
        () => find.byKey(Keys.redactCanvas).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(seconds: 1));
      final box = tester.getRect(find.byKey(Keys.redactCanvas));
      final gesture = await tester.startGesture(
        box.topLeft + const Offset(10, 10),
      );
      await gesture.moveTo(box.center);
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(Keys.redactDone));
      // The next editor page decodes in the real zone and never settles.
      for (var k = 0; k < 5; k++) {
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Hidden areas: 2 in 2 photos'), findsOneWidget);
    expect(find.byKey(Keys.shareStripLocation), findsNothing);
    await tester.tap(find.byKey(Keys.shareConfirm));
    await settleReal(
      tester,
      () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
    expect(shareCalls, 1);
    expect(sharedMimes, ['image/png', 'image/png']);
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

  testWidgets(
    'an encrypted share shows a six word passphrase once, then shares one bundle',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(Keys.shareEncrypted));
      await tester.pump();
      Future<String> askPassphrase() async {
        await tester.tap(find.byKey(Keys.shareConfirm));
        await settleReal(
          tester,
          () => find.byKey(Keys.sharePassphrase).evaluate().isNotEmpty,
        );
        return tester
            .widget<SelectableText>(find.byKey(Keys.sharePassphrase))
            .data!;
      }

      // Backing out shares nothing and keeps the dialog open.
      await askPassphrase();
      await tester.tap(find.byKey(Keys.sharePassphraseCancel));
      await tester.pumpAndSettle();
      expect(shareCalls, 0);
      expect(find.byKey(Keys.shareDialog), findsOneWidget);

      final phrase = await askPassphrase();
      expect(phrase.split(' '), hasLength(6));
      expect(shareCalls, 0, reason: 'nothing is shared before it is shown');
      await tester.tap(find.byKey(Keys.sharePassphraseContinue));
      await settleReal(
        tester,
        () => find.byKey(Keys.shareDialog).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      expect(shareCalls, 1);
      expect(sharedMimes, ['application/octet-stream']);
      expect(sharedPaths.single, endsWith('.quietake-share'));
      expect(find.text(phrase), findsNothing);
    },
  );

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
