import '../test_support/fixtures.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/vault/vault.dart';

import 'harness.dart';

/// Casting through the real UI with a scripted Cast SDK: pick a TV, the
/// LAN-bound server comes up, the "receiver" (this test) fetches the current
/// item over the LAN address, swiping switches it, stopping tears it down.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp app;
  late Vault vault;
  final client = HttpClient();

  setUpAll(() async {
    app = await TestApp.unlocked();
    vault = app.vault;
    for (final f in await vault.list()) {
      await f.delete();
    }
    final tmp = await getTemporaryDirectory();
    for (final name in ['tiny.jpg', 'tiny.mp4']) {
      final data = fixtureBytes(name);
      final f = File('${tmp.path}/$name')..writeAsBytesSync(data);
      await vault.ingestAs(
        f,
        '${name.endsWith('jpg') ? '2026-02' : '2026-01'}.$name',
      );
    }
  });

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('timed out after $timeout');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 500));

  /// Fetch like the TV would. The iOS simulator shares the Mac's network
  /// stack and the macOS application firewall silently drops inbound
  /// connections to it, so there the same port is reached on loopback.
  Future<(int, int)> fetch(Uri url) async {
    final target = Platform.isIOS ? url.replace(host: '127.0.0.1') : url;
    final res = await (await client.getUrl(target))
        .close()
        .timeout(const Duration(seconds: 10));
    var n = 0;
    await for (final c in res) {
      n += c.length;
    }
    return (res.statusCode, n);
  }

  testWidgets('cast the current item, follow swipes, stop', (tester) async {
    await tester.pumpWidget(app.widget());
    await pumpUntil(
      tester,
      () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Keys.openGallery));
    await pumpUntil(
      tester,
      () => find.byKey(Keys.galleryTile(1)).evaluate().isNotEmpty,
    );
    await settle(tester);
    await tester.tap(find.byKey(Keys.galleryTile(0)));
    await pumpUntil(
      tester,
      () => find.byKey(Keys.viewerCast).evaluate().isNotEmpty,
    );
    await settle(tester);

    // Open the picker; the fake scan finds one TV.
    await tester.tap(find.byKey(Keys.viewerCast));
    await pumpUntil(
      tester,
      () => find.byKey(Keys.castDevice(0)).evaluate().isNotEmpty,
    );
    expect(find.text('Living Room TV'), findsOneWidget);
    await settle(tester);
    await tester.ensureVisible(find.byKey(Keys.castDevice(0)));
    expect(find.byKey(Keys.castDevice(0)).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(Keys.castDevice(0)));

    if (await MediaServer.lanAddress() == null) {
      await pumpUntil(
        tester,
        () => find.byKey(Keys.viewerCastState).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.byKey(Keys.viewerCastState)).data,
        contains('Could not cast'),
      );
      return;
    }

    await pumpUntil(
      tester,
      () => app.session.cast.isCasting && app.backend.loadedUrl != null,
    );
    await pumpUntil(
      tester,
      () => find.byKey(Keys.viewerCastState).evaluate().isNotEmpty,
    );
    expect(
      tester.widget<Text>(find.byKey(Keys.viewerCastState)).data,
      'casting to Living Room TV',
    );
    expect(app.backend.loadedType, 'image/jpeg');
    await pumpUntil(tester, () => app.backend.log.contains('stopDiscovery'));
    expect(
      app.backend.log.indexOf('stopDiscovery'),
      greaterThan(app.backend.log.indexOf('connect tv-1')),
      reason: 'discovery must retain the receiver route through connection',
    );
    final photoUrl = app.backend.loadedUrl!;
    expect(photoUrl.host, isNot('127.0.0.1'));
    final (s1, n1) = await fetch(photoUrl);
    expect(s1, 200);
    expect(n1, 5905, reason: 'the receiver gets the decrypted JPEG');

    // Swipe to the video: receiver is told the new URL, the old one is dead.
    await tester.fling(
      find.byKey(Keys.viewerPager),
      const Offset(0, -400),
      1500,
    );
    await pumpUntil(tester, () => app.backend.loadedType == 'video/mp4');
    final (s2, n2) = await fetch(app.backend.loadedUrl!);
    expect(s2, 200);
    expect(n2, 5400);
    expect((await fetch(photoUrl)).$1, 404);

    // Back in the gallery the session is still on and can be stopped there.
    final videoUrl = app.backend.loadedUrl!;
    await settle(tester);
    await tester.tap(find.byKey(Keys.viewerControls));
    await tester.pump();
    // Hidden chrome leaves the tree once its 200 ms fade finishes.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(Keys.viewerShare), findsNothing);
    expect(find.byKey(Keys.viewerCast).hitTestable(), findsOneWidget);
    expect(
      find.byTooltip('Stop casting to Living Room TV').hitTestable(),
      findsOneWidget,
    );
    expect(app.session.cast.isCasting, isTrue);
    expect(app.backend.loadedUrl, videoUrl);
    await tester.pageBack();
    await pumpUntil(
      tester,
      () => find.byKey(Keys.libraryTools).evaluate().isNotEmpty,
    );
    await settle(tester);
    expect(app.session.cast.isCasting, isTrue);
    expect(find.byKey(Keys.galleryCast).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(Keys.galleryCast));
    await pumpUntil(
      tester,
      () => !app.session.cast.isCasting && app.backend.connected == null,
    );
    await expectLater(
      fetch(videoUrl),
      throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
    );
    expect(app.backend.log.where((l) => l.startsWith('load')).length, 2);
  });
}
