import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/portable_screen.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/vault.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

class _MemStorage extends FlutterSecureStoragePlatform {
  final map = <String, String>{};
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => map[key] = value;
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => map[key];
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => map.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => map.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      map.clear();
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(map);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late SodiumSumo sodium;
  late Directory dir;
  late MasterKeyStore store;
  late List<String> calls;
  Object? pickResult;

  setUpAll(() async => sodium = await SodiumSumoInit.init());
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('quietake-portable');
    FlutterSecureStoragePlatform.instance = _MemStorage();
    store = MasterKeyStore(sodium, dir);
    calls = [];
    pickResult = '/private/backup.zip';
    binding.defaultBinaryMessenger.setMockMethodCallHandler(portableChannel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'pick') {
        if (pickResult is PlatformException) throw pickResult!;
        return pickResult;
      }
      return null;
    });
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      portableChannel,
      null,
    );
    await dir.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: PortableScreen(store: store)));
    await tester.pump();
  }

  String result(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(Keys.portableResult)).data!;

  Future<void> start(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(Keys.portableStart));
    await tester.tap(find.byKey(Keys.portableStart));
    await tester.pump();
  }

  testWidgets('restore needs a chosen backup before anything runs', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Restore encrypted backup'), findsOneWidget);
    await start(tester);
    expect(result(tester), contains('Choose a backup'));
    expect(calls, isEmpty);
  });

  testWidgets('Check backup only also needs a backup and its recovery key', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(Keys.portableCheck));
    await tester.tap(find.byKey(Keys.portableCheck));
    await tester.pump();
    expect(result(tester), 'Choose a backup and enter its recovery key.');
    expect(calls, isEmpty);
  });

  testWidgets('picking reports selection, cancellation and copy failure', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.portablePick));
    await tester.pumpAndSettle();
    expect(result(tester), contains('Backup selected'));
    expect(calls, ['pick']);

    pickResult = null;
    await tester.tap(find.byKey(Keys.portablePick));
    await tester.pumpAndSettle();
    expect(result(tester), 'Selection cancelled.');
    // A new pick first discards the previous private copy.
    expect(calls, ['pick', 'clear', 'pick']);

    pickResult = PlatformException(code: 'io');
    await tester.tap(find.byKey(Keys.portablePick));
    await tester.pumpAndSettle();
    expect(result(tester), contains('Could not copy backup'));
  });

  testWidgets('a pick that finishes after leaving discards its private copy', (
    tester,
  ) async {
    final picked = Completer<String?>();
    pickResult = picked.future;
    await open(tester);
    await tester.tap(find.byKey(Keys.portablePick));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    // Leaving mid-pick cancels it; a copy that still arrives is discarded.
    expect(calls, ['pick', 'cancel']);
    picked.complete('/private/late.zip');
    await tester.pump();
    await tester.pump();
    expect(calls, ['pick', 'cancel', 'clear']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short or mismatched new passcodes are rejected', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.portablePick));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.portablePasscode), '12345');
    await tester.enterText(find.byKey(Keys.portableConfirm), '12345');
    await start(tester);
    expect(result(tester), contains('at least six characters'));

    await tester.enterText(find.byKey(Keys.portablePasscode), 'abcdef');
    await tester.enterText(find.byKey(Keys.portableConfirm), 'abcdeg');
    await start(tester);
    expect(result(tester), contains('at least six characters'));
    expect(calls, ['pick']);
  });

  testWidgets('wrong recovery key clears secrets and the private copy', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(Keys.portablePick));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Keys.portableRecovery), 'not-a-key');
    await tester.enterText(find.byKey(Keys.portablePasscode), 'abcdef');
    await tester.enterText(find.byKey(Keys.portableConfirm), 'abcdef');
    await start(tester);
    for (var i = 0; i < 100 && !result(tester).contains('recovery key'); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(result(tester), contains('Enter the recovery key'));
    expect(calls.last, 'clear');
    for (final key in [
      Keys.portableRecovery,
      Keys.portablePasscode,
      Keys.portableConfirm,
    ]) {
      expect(tester.widget<TextField>(find.byKey(key)).controller!.text, '');
    }
    expect(
      tester.widget<FilledButton>(find.byKey(Keys.portableStart)).onPressed,
      isNotNull,
    );
  });

  group('export', () {
    late Session session;
    Future<void> openExport(WidgetTester tester) async {
      await tester.runAsync(() async {
        final key = await store.createWithPasscode('abcdef');
        final vault = Vault(
          VaultCrypto(sodium),
          key,
          Directory('${dir.path}/vault')..createSync(),
        );
        final plain = await File('${dir.path}/in').writeAsBytes([1, 2, 3]);
        await vault.ingestAs(plain, 'photo.jpg');
        session = Session(
          vault: vault,
          server: await MediaServer.start(vault),
          cast: CastController(vault, FakeCastBackend()),
          store: store,
        );
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(session.close);
      });
      binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        )
        ..setMockMethodCallHandler(portableChannel, (call) async {
          calls.add(call.method);
          return null;
        });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PortableScreen(store: store, session: session),
        ),
      );
      await tester.pump();
    }

    Future<void> run(WidgetTester tester, String passcode, String done) async {
      await tester.enterText(find.byKey(Keys.portablePasscode), passcode);
      await start(tester);
      for (var i = 0; i < 150 && !result(tester).contains(done); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(result(tester), contains(done));
    }

    testWidgets('has no restore-only fields', (tester) async {
      await openExport(tester);
      expect(find.text('Portable backup'), findsOneWidget);
      expect(find.byKey(Keys.portablePick), findsNothing);
      expect(find.byKey(Keys.portableRecovery), findsNothing);
      expect(find.byKey(Keys.portableConfirm), findsNothing);
    });

    testWidgets('wrong passcode saves nothing', (tester) async {
      await openExport(tester);
      await run(tester, 'wrong-pass', 'Wrong passcode');
      expect(calls, isNot(contains('save')));
    });
  });
}
