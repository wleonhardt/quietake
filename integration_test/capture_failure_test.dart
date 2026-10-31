import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/sync/sync_settings.dart';

import '../test_support/integration_binding.dart';
import '../test_support/controlled_camera.dart';
import '../test_support/fake_webdav_server.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  initializeIntegrationBinding();
  for (final scenario in [
    (video: false, background: false),
    (video: true, background: false),
    (video: true, background: true),
  ]) {
    final video = scenario.video;
    testWidgets(
      'empty native ${video ? 'video' : 'photo'} fails without backup and allows retry; background=${scenario.background}',
      (tester) async {
        final app = await TestApp.unlocked();
        for (final entry in await app.vault.dir.list().toList()) {
          await entry.delete(recursive: true);
        }
        final temp = await getTemporaryDirectory();
        final camera = ControlledCamera(temp);
        final original = CameraPlatform.instance;
        CameraPlatform.instance = camera;
        final dav = await FakeWebDavServer.start();
        await SyncSettings(
          url: dav.url.toString(),
          username: dav.username,
          password: dav.password,
        ).save();
        await app.session.sync.sync();
        final catalog = await app.vault.catalog.file.readAsBytes();
        await app.vault.catalog.validate(app.vault.catalog.file);
        expect(dav.files, {'quietake.catalog': catalog});
        dav.log.clear();
        Future<void> until(bool Function() done) async {
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (!done()) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Empty capture checkpoint timed out');
            }
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        try {
          await tester.pumpWidget(app.widget());
          await until(() => find.byKey(Keys.preview).evaluate().isNotEmpty);
          if (video) {
            await tester.tap(find.byKey(Keys.videoToggle));
            await until(
              () =>
                  find
                      .byKey(Keys.captureRecordingFrame)
                      .evaluate()
                      .isNotEmpty &&
                  tester
                          .widget<IconButton>(find.byKey(Keys.videoToggle))
                          .onPressed !=
                      null,
            );
            if (scenario.background) {
              for (final state in [
                AppLifecycleState.inactive,
                AppLifecycleState.hidden,
                AppLifecycleState.paused,
              ]) {
                tester.binding.handleAppLifecycleStateChanged(state);
              }
              await tester.runAsync(() async {
                final end = DateTime.now().add(const Duration(seconds: 20));
                while (camera.outputs.isEmpty) {
                  if (DateTime.now().isAfter(end)) {
                    fail('Background capture did not stop');
                  }
                  await Future<void>.delayed(const Duration(milliseconds: 20));
                }
                // Let the background error propagate before the reopen clears it.
                await Future<void>.delayed(const Duration(milliseconds: 100));
              });
              for (final state in [
                AppLifecycleState.hidden,
                AppLifecycleState.inactive,
                AppLifecycleState.resumed,
              ]) {
                tester.binding.handleAppLifecycleStateChanged(state);
              }
            } else {
              await tester.tap(find.byKey(Keys.videoToggle));
            }
          } else {
            await tester.tap(find.byKey(Keys.shutter));
          }
          await until(
            () =>
                camera.outputs.isNotEmpty &&
                tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed !=
                    null,
          );
          expect(
            tester.widget<Text>(find.byKey(Keys.status)).data,
            video
                ? 'No video frames were recorded. Try again.'
                : 'Could not save capture. Try again.',
          );
          final semantics = tester.ensureSemantics();
          await tester.pump();
          expect(
            tester
                .getSemantics(find.byKey(Keys.status))
                .flagsCollection
                .isLiveRegion,
            isTrue,
          );
          semantics.dispose();
          expect(await app.vault.list(), isEmpty);
          expect(dav.files, {'quietake.catalog': catalog});
          expect(dav.log.where((line) => line.startsWith('PUT ')), isEmpty);
          expect(await camera.outputs.single.exists(), isFalse);
          camera.empty = false;
          if (video) {
            await tester.tap(find.byKey(Keys.videoToggle));
            await until(
              () =>
                  find
                      .byKey(Keys.captureRecordingFrame)
                      .evaluate()
                      .isNotEmpty &&
                  tester
                          .widget<IconButton>(find.byKey(Keys.videoToggle))
                          .onPressed !=
                      null,
            );
            await tester.tap(find.byKey(Keys.videoToggle));
          } else {
            await tester.tap(find.byKey(Keys.shutter));
          }
          await until(
            () =>
                dav.files.keys.where((name) => name.endsWith('.shtr')).length ==
                    1 &&
                !app.session.sync.isSyncing &&
                tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed !=
                    null,
          );
          final saved = (await app.vault.list()).single;
          expect(
            await app.vault.readAll(saved),
            fixtureBytes(video ? 'tiny.mp4' : 'tiny.jpg'),
          );
          expect(
            dav.files[saved.uri.pathSegments.last],
            await saved.readAsBytes(),
          );
          expect(await camera.outputs.last.exists(), isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await until(() => camera.disposed.length == camera.created);
          await tester.pump(const Duration(milliseconds: 100));
          CameraPlatform.instance = original;
          await app.close();
          await dav.close();
        }
      },
    );
  }
  testWidgets(
    'pending capture survives storage failure and retries on reopen',
    (tester) async {
      final app = await TestApp.unlocked();
      for (final entry in await app.vault.dir.list().toList()) {
        await entry.delete(recursive: true);
      }
      final work = await Directory(
        '${app.vault.dir.path}/.captures/2099-pending',
      ).create(recursive: true);
      final plain = await File('${work.path}/capture.mp4')
          .writeAsBytes(fixtureBytes('tiny.mp4'), flush: true);
      final blocked = await Directory('${plain.path}.shtr.part').create();
      final camera = ControlledCamera(await getTemporaryDirectory());
      final previous = CameraPlatform.instance;
      CameraPlatform.instance = camera;
      Future<void> until(Future<bool> Function() done) async {
        final end = DateTime.now().add(const Duration(seconds: 30));
        while (!await done()) {
          if (DateTime.now().isAfter(end)) {
            fail('Pending capture retry deadline');
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      try {
        await tester.pumpWidget(app.widget());
        await until(() async => find.byKey(Keys.preview).evaluate().isNotEmpty);
        expect(
          tester.widget<Text>(find.byKey(Keys.status)).data,
          'Capture waiting for secure save. Free storage, then lock and unlock to retry.',
        );
        expect(await app.vault.list(), isEmpty);
        expect(await plain.readAsBytes(), fixtureBytes('tiny.mp4'));
        await blocked.delete();
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
        await until(
          () async =>
              (await app.vault.list()).length == 1 && !await work.exists(),
        );
        final saved = (await app.vault.list()).single;
        expect(await app.vault.readAll(saved), fixtureBytes('tiny.mp4'));
        await until(() async => find.byKey(Keys.preview).evaluate().isNotEmpty);
        expect(
          tester.widget<Text>(find.byKey(Keys.status)).data,
          contains('Recovered 1 capture'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await until(() async => camera.disposed.length == camera.created);
        CameraPlatform.instance = previous;
        await app.close();
      }
    },
  );
}
