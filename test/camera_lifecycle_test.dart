import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/capture_screen.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  for (final superseded in [false, true]) {
    testWidgets(
      'camera replacement waits for old initialization; superseded=$superseded',
      (tester) async {
        late Directory root;
        late Session session;
        await tester.runAsync(() async {
          final sodium = await SodiumSumoInit.init();
          root = await Directory.systemTemp.createTemp(
            'quietake-camera-lifecycle',
          );
          final vault = Vault(
            VaultCrypto(sodium),
            sodium.crypto.secretBox.keygen(),
            root,
          );
          session = Session(
            vault: vault,
            server: await MediaServer.start(vault),
            cast: CastController(vault, FakeCastBackend()),
            store: MasterKeyStore(sodium, root),
          );
        });
        final first = Completer<List<Object?>>();
        var queries = 0;
        const channel = MethodChannel('plugins.flutter.io/camera');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            expect(call.method, 'availableCameras');
            queries++;
            return queries == 1 ? first.future : <Object?>[];
          },
        );
        addTearDown(() async {
          if (!first.isCompleted) first.complete([]);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pump();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          await tester.runAsync(() async {
            await session.close();
            await root.delete(recursive: true);
          });
        });
        Widget camera(int generation) => MaterialApp(
          home: CaptureScreen(key: ValueKey(generation), session: session),
        );
        Future<void> untilQueries(int count) async {
          final end = DateTime.now().add(const Duration(seconds: 5));
          while (queries < count) {
            if (DateTime.now().isAfter(end)) fail('Camera query deadline');
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
        }

        await tester.pumpWidget(camera(0));
        await tester.pump();
        await untilQueries(1);
        expect(queries, 1);
        await tester.pumpWidget(camera(1));
        await tester.pump();
        if (superseded) {
          await tester.pumpWidget(camera(2));
          await tester.pump();
        }
        expect(
          queries,
          1,
          reason: 'A new state must not touch the shared native camera until its predecessor has shut down',
        );
        first.complete([]);
        await tester.pump();
        await untilQueries(2);
        await tester.pumpAndSettle();
        expect(queries, 2, reason: 'Only the surviving replacement may open');
        expect(find.text('No camera'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
