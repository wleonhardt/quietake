import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/portable_screen.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

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
}
