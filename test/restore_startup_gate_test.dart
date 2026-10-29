import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/backup/restore_startup_gate.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/privacy/screen_privacy.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Directory root;
  late File ready;
  late File unrelated;
  late MasterKeyStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('restore-startup-test');
    final pending = await Directory('${root.path}/.portable-restore').create();
    ready = await File('${pending.path}/ready')
        .writeAsString('invalid journal');
    unrelated = await File('${root.path}/unrelated').writeAsBytes([7]);
    store = MasterKeyStore(await SodiumSumoInit.init(), root);
  });
  tearDown(() => root.delete(recursive: true));
  testWidgets(
    'interrupted-restore error acknowledges its protected native frame and can retry',
    (tester) async {
      final acknowledged = <int>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ScreenPrivacy.channel,
        (call) async {
          if (call.method == 'status') {
            return {'generation': 7, 'captured': false, 'backgrounded': false};
          }
          if (call.method == 'ready') acknowledged.add(call.arguments as int);
          return null;
        },
      );
      Future<void> ioUntil(Finder target) async {
        for (var i = 0; i < 100; i++) {
          if (target.evaluate().isNotEmpty) return;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        fail('Startup restore checkpoint timed out');
      }

      try {
        await tester.pumpWidget(
          RestoreStartupGate(
            store: store,
            child: const MaterialApp(home: Text('Startup complete')),
          ),
        );
        await ioUntil(find.byKey(Keys.portableStartupRetry));
        await tester.pump();
        expect(find.text('Startup complete'), findsNothing);
        expect(
          await tester.runAsync(() => ready.readAsString()),
          'invalid journal',
        );
        expect(
          acknowledged,
          contains(7),
          reason: 'A retry screen must not remain hidden behind the iOS startup privacy cover',
        );
        await tester.runAsync(() => ready.delete());
        await tester.tap(find.byKey(Keys.portableStartupRetry));
        await ioUntil(find.text('Startup complete'));
        expect(await tester.runAsync(() => unrelated.readAsBytes()), [7]);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ScreenPrivacy.channel,
          null,
        );
      }
    },
  );
}
