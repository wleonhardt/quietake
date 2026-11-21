import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/cast/device_picker.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

void main() {
  late Directory dir;
  late Vault vault;

  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    dir = await Directory.systemTemp.createTemp('quietake-picker');
    vault = Vault(
      crypto,
      crypto.generateMasterKey(),
      Directory('${dir.path}/vault')..createSync(),
    );
  });

  tearDown(() async {
    vault.dispose();
    await dir.delete(recursive: true);
  });

  Future<(FakeCastBackend, CastController)> open(
    WidgetTester tester,
    FakeCastBackend backend,
  ) async {
    final cast = CastController(vault, backend);
    addTearDown(cast.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: CastButton(cast: cast)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Cast to TV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return (backend, cast);
  }

  testWidgets('lists discovered TVs with the unencrypted-stream warning', (
    tester,
  ) async {
    final (backend, _) = await open(tester, FakeCastBackend());
    expect(find.byKey(Keys.castSheet), findsOneWidget);
    expect(find.text('Living Room TV'), findsOneWidget);
    expect(find.textContaining('unencrypted'), findsOneWidget);
    await tester.tap(find.byKey(Keys.castClose));
    await tester.pumpAndSettle();
    expect(find.byKey(Keys.castSheet), findsNothing);
    expect(backend.log, ['startDiscovery', 'stopDiscovery']);
    expect(backend.connected, isNull);
  });

  testWidgets('discovery failure shows a notice and no picker', (tester) async {
    final (backend, _) = await open(
      tester,
      FakeCastBackend()..failDiscovery = true,
    );
    expect(find.byKey(Keys.castSheet), findsNothing);
    expect(find.textContaining('Could not search for TVs'), findsOneWidget);
    expect(backend.connected, isNull);
  });

  testWidgets('empty list waits, then offers a retry that restarts search', (
    tester,
  ) async {
    final (backend, _) = await open(tester, FakeCastBackend(available: []));
    expect(find.text('Looking for TVs on this network'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('No TVs found'), findsOneWidget);
    await tester.tap(find.byKey(Keys.castRetry));
    await tester.pump();
    await tester.pump();
    expect(backend.log, ['startDiscovery', 'stopDiscovery', 'startDiscovery']);
    expect(find.text('Looking for TVs on this network'), findsOneWidget);
    await tester.tap(find.byKey(Keys.castClose));
    await tester.pumpAndSettle();
  });

  testWidgets('choosing a TV connects and explains what happens next', (
    tester,
  ) async {
    if (await tester.runAsync(MediaServer.lanAddress) == null) return;
    final (backend, cast) = await open(tester, FakeCastBackend());
    await tester.runAsync(() => tester.tap(find.byKey(Keys.castDevice(0))));
    for (var i = 0; i < 100 && !cast.isCasting; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(backend.log, contains('connect tv-1'));
    expect(cast.isCasting, isTrue);
    expect(
      find.text('Connected to Living Room TV. Open a capture to cast it.'),
      findsOneWidget,
    );
    await tester.runAsync(cast.stop);
  });
}
