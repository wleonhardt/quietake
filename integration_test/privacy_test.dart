import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/privacy/screen_privacy.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:video_player/video_player.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestApp app;
  late File photo, video;
  const oldPasscode = 'privacy-test-current';
  const newPasscode = 'privacy-test-replacement';

  setUpAll(() async {
    app = await TestApp.unlocked();
    (await app.session.store.createWithPasscode(oldPasscode)).dispose();
    for (final file in await app.vault.list()) {
      await file.delete();
    }
    final temp = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final jpg = await File('${temp.path}/privacy.jpg')
        .writeAsBytes(fixtureBytes('tiny.jpg'));
    final mp4 = await File('${temp.path}/privacy.mp4')
        .writeAsBytes(fixtureBytes('tiny.mp4'));
    photo = await app.vault.ingestAs(jpg, '9999-z-$stamp.jpg');
    video = await app.vault.ingestAs(mp4, '9999-a-$stamp.mp4');
    expect(await jpg.exists(), isFalse);
    expect(await mp4.exists(), isFalse);
  });
  setUp(() async {
    await const FlutterSecureStorage().write(
      key: 'privacy.idleMinutes',
      value: '0',
    );
  });
  tearDownAll(() => app.close());

  bool has(Key key) => find.byKey(key).evaluate().isNotEmpty;
  Future<void> until(WidgetTester tester, bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Privacy UI checkpoint timed out');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> begin(WidgetTester tester) async {
    await tester.pumpWidget(
      app.widget(idleTimeout: const Duration(seconds: 3)),
    );
    await until(tester, () => has(Keys.openGallery) && has(Keys.lockNow));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      if (Platform.isIOS) {
        final cover = await ScreenPrivacy.channel.invokeMapMethod<String, bool>(
          'checkCover',
        );
        expect(cover, {'opaque': true, 'fullSize': true});
      }
      final native = await ScreenPrivacy.channel
          .invokeMapMethod<String, dynamic>('status');
      if (native?['covered'] == false) break;
      if (DateTime.now().isAfter(deadline)) {
        fail('Native privacy cover obscures the foreground app');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unlock(WidgetTester tester) async {
    await until(tester, () => has(Keys.lockBiometric));
    await tap(tester, Keys.lockBiometric);
    await until(tester, () => !has(Keys.lockPasscode));
  }

  Future<void> enter(WidgetTester tester, Key key, String value) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.enterText(find.byKey(key), value);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    final controller = tester.widget<TextField>(find.byKey(key)).controller!;
    if (controller.text != value) controller.text = value;
    await tester.pump();
    expect(controller.text == value, isTrue, reason: 'Test field lost input');
  }

  Future<void> settings(WidgetTester tester) async {
    await tap(tester, Keys.openGallery);
    await until(tester, () => has(Keys.gallerySettings));
    await tap(tester, Keys.gallerySettings);
    await until(tester, () => has(Keys.settingsUrl));
  }

  Future<void> scrollTo(WidgetTester tester, Key key) =>
      tester.scrollUntilVisible(
        find.byKey(key),
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('native screen privacy and manual route lock preserve captures', (
    tester,
  ) async {
    await begin(tester);
    final state = await ScreenPrivacy.channel.invokeMapMethod<String, dynamic>(
      'status',
    );
    expect(state?['screenshotProtected'], Platform.isAndroid);
    if (Platform.isIOS) {
      final cover = await ScreenPrivacy.channel
          .invokeMapMethod<String, dynamic>('checkCover');
      expect(cover, {'opaque': true, 'fullSize': true});
    }
    var prompts = app.auth.reasons.length;
    await tap(tester, Keys.lockNow);
    await until(tester, () => has(Keys.lockPasscode));
    expect(
      app.auth.reasons.length,
      prompts,
      reason: 'A deliberate lock must await explicit unlock',
    );
    await unlock(tester);
    await tap(tester, Keys.openGallery);
    await until(tester, () => has(Keys.galleryTile(0)));
    await tap(tester, Keys.galleryTile(0));
    await until(tester, () => has(Keys.viewerPhoto));
    prompts = app.auth.reasons.length;
    await tap(tester, Keys.viewerControls);
    expect(has(Keys.viewerShare), isFalse);
    await tap(tester, Keys.lockNow);
    await until(tester, () => has(Keys.lockPasscode));
    expect(has(Keys.viewerPhoto), isFalse);
    expect(app.auth.reasons.length, prompts);
    await unlock(tester);
    expect(has(Keys.viewerPhoto), isTrue);
    await tap(tester, Keys.viewerControls);
    expect(has(Keys.viewerShare), isTrue);
    expect(await app.vault.readAll(photo), fixtureBytes('tiny.jpg'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'current passcode changes without replacing media or recovery identity',
    (tester) async {
      await begin(tester);
      final encrypted = await photo.readAsBytes();
      final key = await app.session.store.unlockWithPasscode(oldPasscode);
      final recovery = app.session.store.exportRecovery(key);
      key.dispose();
      await settings(tester);
      await scrollTo(tester, Keys.settingsChangePasscode);
      await tap(tester, Keys.settingsChangePasscode);
      await until(tester, () => has(Keys.currentPasscode));
      await enter(tester, Keys.currentPasscode, oldPasscode);
      await enter(tester, Keys.newPasscode, newPasscode);
      await enter(tester, Keys.confirmPasscode, 'mismatch');
      await tap(tester, Keys.changePasscodeSubmit);
      expect(
        tester.widget<Text>(find.byKey(Keys.changePasscodeError)).data,
        'Passcodes do not match',
      );
      await enter(tester, Keys.currentPasscode, 'incorrect-test');
      await enter(tester, Keys.confirmPasscode, newPasscode);
      await tap(tester, Keys.changePasscodeSubmit);
      await until(tester, () => has(Keys.changePasscodeError));
      expect(
        tester.widget<Text>(find.byKey(Keys.changePasscodeError)).data,
        'Current passcode is incorrect',
      );
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        expect(
          tester.getSemantics(find.byKey(Keys.changePasscodeError))
              .flagsCollection.isLiveRegion,
          isTrue,
        );
      } finally {
        semantics.dispose();
      }
      await enter(tester, Keys.currentPasscode, oldPasscode);
      await tap(tester, Keys.changePasscodeSubmit);
      await until(tester, () => !has(Keys.changePasscodeSubmit));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<Text>(find.byKey(Keys.settingsAccessResult)).data,
        'Passcode changed',
      );
      await tester.ensureVisible(find.byKey(Keys.settingsAccessResult));
      expect(find.byKey(Keys.settingsAccessResult).hitTestable(), findsOneWidget);
      await expectLater(
        app.session.store.unlockWithPasscode(oldPasscode),
        throwsA(isA<WrongPasscodeException>()),
      );
      final unlocked = await app.session.store.unlockWithPasscode(newPasscode);
      expect(app.session.store.exportRecovery(unlocked) == recovery, isTrue);
      unlocked.dispose();
      expect(await photo.readAsBytes(), encrypted);
      expect(await app.vault.readAll(photo), fixtureBytes('tiny.jpg'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'saved idle preference locks privately and off retains manual lock',
    (tester) async {
      await begin(tester);
      await settings(tester);
      await scrollTo(tester, Keys.idleTimeout);
      await tap(tester, Keys.idleTimeout);
      await tester.tap(find.text('1 minute').last);
      await until(tester, () => has(Keys.lockPasscode));
      await unlock(tester);
      await tap(tester, Keys.idleTimeout);
      await tester.tap(find.text('Off').last);
      await tester.pump(const Duration(seconds: 4));
      expect(has(Keys.lockPasscode), isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'privacy.idleMinutes'),
        '0',
      );
      await tap(tester, Keys.lockNow);
      await until(tester, () => has(Keys.lockPasscode));
      await unlock(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('recording delays idle but manual lock saves encrypted video', (
    tester,
  ) async {
    await begin(tester);
    if ((await availableCameras()).isEmpty) {
      await until(tester, () => find.text('No camera').evaluate().isNotEmpty);
    } else {
      await until(tester, () => has(Keys.preview));
      final before = (await app.vault.list()).map((f) => f.path).toSet();
      await tap(tester, Keys.videoToggle);
      await until(tester, () => has(Keys.captureTimer));
      final privacy = PrivacyScope.maybeOf(
        tester.element(find.byKey(Keys.videoToggle)),
      )!;
      await privacy.setMinutes(1);
      await tester.pump(const Duration(seconds: 4));
      expect(has(Keys.lockPasscode), isFalse);
      expect(has(Keys.captureTimer), isTrue);
      await tap(tester, Keys.lockNow);
      await until(tester, () => has(Keys.lockPasscode));
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      List<File> added = [];
      while (added.isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Recording did not save after locking');
        }
        await tester.pump(const Duration(milliseconds: 100));
        added = (await app.vault.list())
            .where((f) => !before.contains(f.path))
            .toList();
      }
      final head = await app.vault.read(added.single).first;
      expect(String.fromCharCodes(head.sublist(4, 8)), 'ftyp');
      await unlock(tester);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'playback delays idle and a protected gate ends the Cast session',
    (tester) async {
      await begin(tester);
      await tap(tester, Keys.openGallery);
      await until(tester, () => has(Keys.galleryTile(1)));
      await tap(tester, Keys.galleryTile(1));
      await until(tester, () => has(Keys.viewerVideo));
      final player = tester
          .widget<VideoPlayer>(find.byKey(Keys.viewerVideo))
          .controller;
      await player.setLooping(true);
      await player.seekTo(Duration.zero);
      await player.play();
      final privacy = PrivacyScope.maybeOf(
        tester.element(find.byKey(Keys.viewerVideo)),
      )!;
      await privacy.setMinutes(1);
      await tester.pump(const Duration(seconds: 4));
      expect(has(Keys.lockPasscode), isFalse);
      expect(player.value.isPlaying, isTrue);
      await app.session.cast.start(
        app.backend.available.first,
        VaultItem(video),
      );
      await app.session.cast.show(VaultItem(video));
      await tester.pump(const Duration(milliseconds: 500));
      if (Platform.isIOS) {
        final cover = await ScreenPrivacy.channel.invokeMapMethod<String, bool>(
          'checkCover',
        );
        expect(cover, {'opaque': true, 'fullSize': true});
      }
      final native = await ScreenPrivacy.channel
          .invokeMapMethod<String, dynamic>('status');
      final generation = native?['generation'] as int? ?? 0;
      ui.channelBuffers.push(
        ScreenPrivacy.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('state', {'captured': true, 'generation': generation}),
        ),
        (_) {},
      );
      await until(
        tester,
        () => has(Keys.lockPasscode) && !player.value.isPlaying,
      );
      await until(tester, () => has(Keys.lockBiometric));
      await tap(tester, Keys.lockBiometric);
      expect(
        has(Keys.lockPasscode),
        isTrue,
        reason: 'Capture protection cannot be unlocked through',
      );
      // Decision 040: a lock stops casting so nothing streams behind the gate.
      await until(tester, () => !app.session.cast.isCasting);
      expect(app.backend.loadedUrl, isNull);
      expect(app.backend.log.last, 'disconnect');
      ui.channelBuffers.push(
        ScreenPrivacy.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('state', {'captured': false, 'generation': generation}),
        ),
        (_) {},
      );
      await tester.pump();
      await unlock(tester);
      await app.session.cast.stop();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('licenses need no NAS setup and respect the lock gate', (
    tester,
  ) async {
    await begin(tester);
    expect((await SyncSettings.load()).isConfigured, isFalse);
    await settings(tester);
    await scrollTo(tester, Keys.settingsLicenses);
    await tap(tester, Keys.settingsLicenses);
    await until(
      tester,
      () =>
          has(Keys.licensesPage) &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    final appLicense = find.widgetWithText(ListTile, 'Quietake');
    await tester.scrollUntilVisible(
      appLicense,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(appLicense);
    await tester.pump(const Duration(milliseconds: 500));
    await until(
      tester,
      () => find
          .textContaining('Mozilla Public License Version 2.0')
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.textContaining('https://github.com/wleonhardt/quietake'),
      findsWidgets,
    );
    if (appLicense.hitTestable().evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Back').hitTestable());
      await tester.pump(const Duration(milliseconds: 500));
    }
    if (Platform.isAndroid) {
      final nativeNotice = find.widgetWithText(
        ListTile,
        'kotlinx.coroutines (Android)',
      );
      await tester.scrollUntilVisible(
        nativeNotice,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(nativeNotice);
      await tester.pump(const Duration(milliseconds: 500));
      await until(
        tester,
        () => find
            .textContaining(
              'Copyright 2016-2024 JetBrains s.r.o and contributors',
            )
            .evaluate()
            .isNotEmpty,
      );
      if (nativeNotice.hitTestable().evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Back').hitTestable());
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
    final effLicense = find.widgetWithText(ListTile, 'EFF Long Wordlist');
    await tester.scrollUntilVisible(
      effLicense,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(effLicense, findsOneWidget);
    await tester.tap(effLicense);
    await tester.pump(const Duration(milliseconds: 500));
    final attribution = find.textContaining('CC BY 4.0');
    await until(tester, () => attribution.evaluate().isNotEmpty);
    final privacy = PrivacyScope.maybeOf(tester.element(attribution.first))!;
    await privacy.setMinutes(1);
    await tester.pump(const Duration(seconds: 4));
    await until(tester, () => has(Keys.lockPasscode));
    expect(find.byKey(Keys.licensesPage), findsNothing);
    expect(attribution, findsNothing);
    await unlock(tester);
    expect(await app.vault.readAll(photo), fixtureBytes('tiny.jpg'));
    expect(await app.vault.readAll(video), fixtureBytes('tiny.mp4'));
    expect((await SyncSettings.load()).isConfigured, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
