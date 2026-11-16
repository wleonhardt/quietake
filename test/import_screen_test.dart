import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/l10n/l10n.dart';
import 'package:quietake/library/folder_import.dart';
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
  Future<Object?> Function() pickFolder = () async => null;
  late List<String> folderCalls;

  setUp(() async {
    calls = [];
    folderCalls = [];
    pickFolder = () async => null;
    pick = () async => <Object?>[];
    clear = () async {};
  });

  Future<void> open(WidgetTester tester, {Locale? locale}) async {
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
      ..setMockMethodCallHandler(folderChannel, (call) async {
        folderCalls.add(call.method);
        return switch (call.method) {
          'pick' => await pickFolder(),
          'copy' => throw PlatformException(code: 'copy'),
          _ => null,
        };
      })
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
        ..setMockMethodCallHandler(folderChannel, null)
        ..setMockMethodCallHandler(importChannel, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportScreen(session: session),
      ),
    );
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

  testWidgets('the import screen follows the device language', (tester) async {
    pick = () async => [
      {'name': 'notes.txt', 'path': null, 'error': null},
    ];
    await open(tester, locale: const Locale('es'));
    expect(find.text('Elegir archivos'), findsOneWidget);
    expect(find.text('Elegir carpeta'), findsOneWidget);
    expect(find.text('Archivos admitidos y límites'), findsOneWidget);
    await choose(tester);
    expect(
      text(tester, Keys.importSummary),
      '0 importadas · 0 duplicadas omitidas · 1 con error',
    );
    expect(find.text('Choose files'), findsNothing);
  });

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

  Future<void> chooseFolder(WidgetTester tester) async {
    // Started in the real zone: the ledger write would hang in the fake one.
    await tester.runAsync(() => tester.tap(find.byKey(Keys.importFolder)));
    // Real file work (ledger, copies) runs across many turns; wait for the end.
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byKey(Keys.importProgress).evaluate().isEmpty && i > 2) break;
    }
  }

  testWidgets('a cancelled folder picker changes nothing', (tester) async {
    await open(tester);
    await chooseFolder(tester);
    expect(find.byKey(Keys.importFolderSummary), findsNothing);
    expect(find.byKey(Keys.importError), findsNothing);
    expect(folderCalls, ['pick']);
    expect(calls, ['clear']);
    expect(
      tester.widget<OutlinedButton>(find.byKey(Keys.importFolder)).onPressed,
      isNotNull,
    );
  });

  testWidgets('files that cannot be read are counted and can be retried', (
    tester,
  ) async {
    pickFolder = () async => {
      'identity': 'folder',
      'entries': [
        {'id': 'a', 'name': 'a.jpg'},
        {'id': 'b', 'name': 'b.png'},
        {'id': 'c', 'name': 'notes.txt'},
      ],
    };
    await open(tester);
    await chooseFolder(tester);
    expect(
      text(tester, Keys.importFolderSummary),
      '0 imported · 2 failed. Choose the same folder again to continue.',
    );
    // Both copies were attempted, then access was released and copies cleared.
    expect(folderCalls, ['pick', 'copy', 'copy', 'release']);
    expect(calls, ['clear']);
  });

  testWidgets('a folder over the file limit is refused with a reason', (
    tester,
  ) async {
    pickFolder = () async => {
      'identity': 'folder',
      'entries': [
        for (var i = 0; i < 10001; i++) {'id': 'f$i', 'name': 'f$i.jpg'},
      ],
    };
    await open(tester);
    await chooseFolder(tester);
    expect(
      text(tester, Keys.importError),
      'Choose a folder with up to 10,000 files.',
    );
    expect(folderCalls, ['pick', 'release']);
  });

  testWidgets('a failing folder picker reports a retryable error', (
    tester,
  ) async {
    pickFolder = () async => throw PlatformException(code: 'list');
    await open(tester);
    await chooseFolder(tester);
    expect(text(tester, Keys.importError), contains('Folder import stopped'));
    expect(
      tester.widget<OutlinedButton>(find.byKey(Keys.importFolder)).onPressed,
      isNotNull,
    );
  });

  testWidgets('both choose buttons are disabled while a folder import runs', (
    tester,
  ) async {
    final gate = Completer<Object?>();
    pickFolder = () => gate.future;
    await open(tester);
    await tester.tap(find.byKey(Keys.importFolder));
    await tester.pump();
    expect(find.byKey(Keys.importProgress), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(Keys.importFolder)).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(Keys.importChoose)).onPressed,
      isNull,
    );
    gate.complete(null);
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byKey(Keys.importProgress), findsNothing);
  });
}
