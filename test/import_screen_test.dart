import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/library/import_media.dart';
import 'package:quietake/library/import_screen.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;
  late Session session;
  late List<String> calls;
  Future<Object?> Function() pick = () async => <Object?>[];
  Future<void> Function() clear = () async {};

  setUp(() async {
    calls = [];
    pick = () async => <Object?>[];
    clear = () async {};
  });

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-import-screen');
      final vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        Directory('${dir.path}/vault')..createSync(),
      );
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
    binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(paths, (_) async => dir.path)
      ..setMockMethodCallHandler(importChannel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'pick' => await pick(),
          'clear' => await clear(),
          _ => null,
        };
      });
    addTearDown(() {
      binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(paths, null)
        ..setMockMethodCallHandler(importChannel, null);
    });
    await tester.pumpWidget(MaterialApp(home: ImportScreen(session: session)));
    await tester.pump();
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byKey(Keys.importChoose));
    // The platform calls and the final cleanup each need their own turn.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  String text(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  testWidgets('starts idle with the originals-unchanged promise', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('Originals stay unchanged'), findsOneWidget);
    expect(find.byKey(Keys.importProgress), findsNothing);
    expect(find.byKey(Keys.importSummary), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets(
    'rejected files are listed with reasons and the copy is cleared',
    (tester) async {
      pick = () async => [
        {'name': 'notes.txt', 'path': null, 'error': null},
        {'name': 'big.jpg', 'path': null, 'error': 'File is too large.'},
      ];
      await open(tester);
      await choose(tester);
      expect(
        text(tester, Keys.importSummary),
        '0 imported · 0 duplicates skipped · 2 failed',
      );
      expect(find.text('Use JPEG, PNG or MP4.'), findsOneWidget);
      expect(find.text('File is too large.'), findsOneWidget);
      expect(calls, ['pick', 'clear']);
      expect(
        tester.widget<FilledButton>(find.byKey(Keys.importChoose)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('a failing picker reports a retryable error', (tester) async {
    pick = () async => throw PlatformException(code: 'picker');
    await open(tester);
    await choose(tester);
    expect(text(tester, Keys.importError), contains('Could not open import'));
    expect(calls, ['pick', 'clear']);
  });

  testWidgets('failed cleanup tells the user to restart before retrying', (
    tester,
  ) async {
    clear = () async => throw PlatformException(code: 'clear');
    await open(tester);
    await choose(tester);
    expect(text(tester, Keys.importError), contains('Restart Quietake'));
  });

  testWidgets('cancel asks the platform to stop and disables itself', (
    tester,
  ) async {
    final gate = Completer<Object?>();
    pick = () => gate.future;
    await open(tester);
    await tester.tap(find.byKey(Keys.importChoose));
    await tester.pump();
    expect(find.byKey(Keys.importProgress), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(Keys.importChoose)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(Keys.importCancel));
    await tester.pump();
    expect(calls, ['pick', 'cancel']);
    expect(
      find.textContaining('Cancelling after current file'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextButton>(find.byKey(Keys.importCancel)).onPressed,
      isNull,
    );
    gate.complete(<Object?>[]);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byKey(Keys.importProgress), findsNothing);
  });
}
