import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/recovery_screen.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/main.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/privacy/screen_privacy.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';
import '../test_support/fake_cast_backend.dart';

void main() {
  for (final backgroundBeforeReady in [false, true]) {
    testWidgets(
      'background lock hides pushed routes and restores route after unlock; queued=$backgroundBeforeReady',
      (tester) async {
        late Directory dir;
        late Session session;
        final auth = FakeAuthenticator(isAvailable: false, answer: false);
        await tester.runAsync(() async {
          final sodium = await SodiumSumoInit.init();
          dir = await Directory.systemTemp.createTemp('quietake-lock');
          await File('${dir.path}/vault.keyfile.json').writeAsString('{}');
          final store = MasterKeyStore(sodium, dir);
          final vault = Vault(
            VaultCrypto(sodium),
            sodium.crypto.secretBox.keygen(),
            Directory('${dir.path}/vault')..createSync(),
          );
          session = Session(
            vault: vault,
            server: await MediaServer.start(vault),
            cast: CastController(vault, FakeCastBackend()),
            store: store,
          );
        });
        final camerasReady = Completer<List<Object?>>();
        var cameraQueries = 0;
        addTearDown(() {
          if (!camerasReady.isCompleted) camerasReady.complete([]);
        });
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/camera'),
          (call) async {
            if (call.method != 'availableCameras') return null;
            cameraQueries++;
            return camerasReady.future;
          },
        );
        await tester.pumpWidget(
          QuietakeApp(
            store: session.store,
            auth: auth,
            castBackend: session.cast.backend,
            session: session,
          ),
        );
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.title, 'Quietake');
        expect(app.themeMode, ThemeMode.system);
        expect(app.theme!.brightness, Brightness.light);
        expect(app.darkTheme!.brightness, Brightness.dark);
        expect(app.highContrastTheme, isNotNull);
        expect(app.highContrastDarkTheme, isNotNull);
        final readyBy = DateTime.now().add(const Duration(seconds: 5));
        while (find.byKey(Keys.openGallery).evaluate().isEmpty ||
            cameraQueries == 0) {
          if (DateTime.now().isAfter(readyBy)) {
            fail('Authenticated camera recovery did not finish');
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(
          tester.widget<IconButton>(find.byKey(Keys.openGallery)).onPressed,
          isNotNull,
          reason: 'An initial gallery tap must queue until recovery is ready',
        );
        final semantics = tester.ensureSemantics();
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        await tester.tap(find.byKey(Keys.openGallery));
        await tester.tap(find.byKey(Keys.openGallery));
        await tester.pump();
        expect(find.byKey(Keys.gallerySettings), findsNothing);
        if (backgroundBeforeReady) {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.pump();
          expect(find.byKey(Keys.lockUnlock).hitTestable(), findsOneWidget);
          tester
              .widget<LockScreen>(find.byType(LockScreen))
              .onUnlocked(session.vault.masterKeyForTests.copy());
          await tester.pump();
        }
        camerasReady.complete([]);
        if (backgroundBeforeReady) {
          final unlockedBy = DateTime.now().add(const Duration(seconds: 5));
          while (tester
                  .widget<IconButton>(find.byKey(Keys.openGallery))
                  .onPressed ==
              null) {
            if (DateTime.now().isAfter(unlockedBy)) {
              fail('Camera reopen deadline');
            }
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          expect(
            find.byKey(Keys.gallerySettings),
            findsNothing,
            reason: 'A queued pre-lock tap cannot navigate after unlock',
          );
          await tester.tap(find.byKey(Keys.openGallery));
        }
        final galleryBy = DateTime.now().add(const Duration(seconds: 5));
        while (find.byKey(Keys.gallerySettings).evaluate().isEmpty) {
          if (DateTime.now().isAfter(galleryBy)) {
            fail('Queued gallery navigation deadline');
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        for (final brightness in Brightness.values) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            Theme.of(tester.element(find.byKey(Keys.gallerySettings)))
                .brightness,
            brightness,
          );
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.byKey(Keys.gallerySettings).hitTestable(),
          findsNothing,
          reason: 'Rapid taps must not push duplicate gallery routes',
        );
        await tester.tap(find.byKey(Keys.openGallery));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(Keys.gallerySettings).hitTestable(), findsNothing);
        expect(find.byKey(Keys.lockUnlock).hitTestable(), findsOneWidget);
        tester
            .widget<LockScreen>(find.byType(LockScreen))
            .onUnlocked(session.vault.masterKeyForTests.copy());
        await tester.pump();
        expect(find.byKey(Keys.gallerySettings).hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        await tester.runAsync(() async {
          await session.server.close();
          session.cast.dispose();
          session.vault.masterKeyForTests.dispose();
          await dir.delete(recursive: true);
        });
        await tester.pump();
      },
    );
  }
  testWidgets('an unlock from a superseded lock gate is rejected', (
    tester,
  ) async {
    late Directory dir;
    late Session session;
    await tester.runAsync(() async {
      final sodium = await SodiumSumoInit.init();
      dir = await Directory.systemTemp.createTemp('quietake-epoch');
      await File('${dir.path}/vault.keyfile.json').writeAsString('{}');
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
    const camera = MethodChannel('plugins.flutter.io/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      camera,
      (call) async => call.method == 'availableCameras' ? <Object?>[] : null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ScreenPrivacy.channel,
      (call) async => call.method == 'status' ? {'captured': false} : null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        camera,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ScreenPrivacy.channel,
        null,
      );
    });
    void capture(bool captured, int generation) {
      ui.channelBuffers.push(
        ScreenPrivacy.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('state', {
            'captured': captured,
            'backgrounded': false,
            'generation': generation,
          }),
        ),
        (_) {},
      );
    }

    await tester.pumpWidget(
      QuietakeApp(
        store: session.store,
        auth: FakeAuthenticator(isAvailable: false),
        castBackend: session.cast.backend,
        session: session,
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    }

    await settle();
    // Background lock opens gate A.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle();
    final stale = tester.widget<LockScreen>(find.byType(LockScreen)).onUnlocked;
    // A screen-capture lock while locked opens gate B and retires A.
    capture(true, 1);
    await tester.pump();
    capture(false, 2);
    await tester.pump();
    stale(session.vault.masterKeyForTests.copy());
    await tester.pump();
    expect(find.byKey(Keys.lockUnlock).hitTestable(), findsOneWidget);
    tester
        .widget<LockScreen>(find.byType(LockScreen))
        .onUnlocked(session.vault.masterKeyForTests.copy());
    await tester.pump();
    expect(find.byKey(Keys.lockUnlock).hitTestable(), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      // Like the test above: the shell's unlock queued a sync whose fake-async
      // work never settles, so close the owned resources directly.
      await session.server.close();
      session.cast.dispose();
      session.vault.masterKeyForTests.dispose();
      await dir.delete(recursive: true);
    });
  });

  for (final size in [const Size(800, 360), const Size(360, 640)]) {
    testWidgets('recovery fits $size at large text scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: RecoveryScreen(
            recoveryKey: List.filled(11, 'TEST').join(' '),
            fingerprint: 'abcd ef01',
            onDone: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(Keys.recoveryDone),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.byKey(Keys.recoveryDone).hitTestable(), findsOneWidget);
    });
  }
  testWidgets('recovery explains retained files and optional NAS passphrase', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryScreen(
          recoveryKey: 'SYNTHETIC TEST VALUE',
          fingerprint: 'abcd ef01',
          onDone: () {},
        ),
      ),
    );
    expect(find.textContaining('encrypted files'), findsOneWidget);
    expect(find.textContaining('enabled'), findsOneWidget);
    expect(find.textContaining('There is no other way'), findsNothing);
    expect(find.textContaining('key alone'), findsNothing);
  });
}
