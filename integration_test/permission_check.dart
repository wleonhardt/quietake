import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';

import '../test_support/fixtures.dart';
import '../test_support/mp4.dart';
import 'harness.dart';

/// Explicit Android check: host denies permissions before launch, then grants
/// them at the checkpoint. Never run against the release package or a phone.
void main() {
  if (!Platform.isAndroid ||
      !const bool.fromEnvironment('QUIETAKE_PERMISSION_CHECK')) {
    throw StateError(
      'Run explicitly on Android with QUIETAKE_PERMISSION_CHECK=true',
    );
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const photoOnly = bool.fromEnvironment('QUIETAKE_PHOTO_ONLY_CHECK');
  testWidgets(
    photoOnly
        ? 'photos survive microphone denial and video recovers after grant'
        : 'denied capture permissions preserve gallery and recover on resume',
    (tester) async {
      final app = await TestApp.unlocked();
      final temp = await getTemporaryDirectory();
      final plain = await File('${temp.path}/permission-input.jpg')
          .writeAsBytes(fixtureBytes('tiny.jpg'));
      final photo = await app.vault.ingestAs(
        plain,
        '9999-permission-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final before = (await app.vault.list()).map((file) => file.path).toSet();
      final added = <File>[];
      final marker = File(
        '${(await getTemporaryDirectory()).path}/permission-granted',
      );
      if (await marker.exists()) await marker.delete();
      Future<void> until(bool Function() ready) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (!ready()) {
          if (DateTime.now().isAfter(deadline)) {
            final status = find.byKey(Keys.status).evaluate().isEmpty
                ? 'none'
                : tester.widget<Text>(find.byKey(Keys.status)).data;
            fail(
              'Permission checkpoint timed out: status=$status; '
              'preview=${find.byKey(Keys.preview).evaluate().isNotEmpty}; '
              'shutter=${tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed != null}',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      bool has(Key key) => find.byKey(key).evaluate().isNotEmpty;
      bool shutterReady() =>
          has(Keys.preview) &&
          tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed != null;
      Future<void> takePhoto() async {
        final paths = (await app.vault.list()).map((file) => file.path).toSet();
        await tester.tap(find.byKey(Keys.shutter));
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        List<File> files = [];
        while (files.isEmpty) {
          if (DateTime.now().isAfter(deadline)) fail('Photo was not saved');
          await tester.pump(const Duration(milliseconds: 100));
          files = (await app.vault.list())
              .where((file) => !paths.contains(file.path))
              .toList();
        }
        final capture = files.single;
        added.add(capture);
        expect(capture.path, endsWith('.jpg.shtr'));
        expect((await app.vault.readAll(capture)).take(3), [0xff, 0xd8, 0xff]);
        await until(shutterReady);
      }

      try {
        await tester.pumpWidget(app.widget());
        await until(() => has(Keys.preview) || has(Keys.status));
        if (photoOnly) {
          expect(
            find.byKey(Keys.preview),
            findsOneWidget,
            reason: 'Photos must work when microphone permission is denied',
          );
          await takePhoto();
          await tester.tap(find.byKey(Keys.videoToggle));
          await until(
            () =>
                shutterReady() &&
                has(Keys.status) &&
                tester
                    .widget<Text>(find.byKey(Keys.status))
                    .data!
                    .contains('microphone'),
          );
          expect(find.byKey(Keys.captureRecordingFrame), findsNothing);
          expect(await app.vault.list(), hasLength(before.length + 1));
          await takePhoto();
        } else {
          expect(
            tester.widget<Text>(find.byKey(Keys.status)).data,
            startsWith('Camera unavailable.'),
          );
          expect(find.byKey(Keys.preview), findsNothing);
          expect(
            tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed,
            isNull,
          );
        }
        await tester.tap(find.byKey(Keys.openGallery));
        await until(
          () => find
              .byKey(Keys.gallerySettings)
              .hitTestable()
              .evaluate()
              .isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await until(
          () => find.byKey(Keys.galleryTile(0)).evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(Keys.galleryTile(0)));
        await until(() => find.byKey(Keys.viewerPhoto).evaluate().isNotEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        expect(await app.vault.readAll(photo), fixtureBytes('tiny.jpg'));
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        debugPrint('PERMISSION_CHECK_WAITING_FOR_HOST_GRANT');
        await tester.runAsync(() async {
          final deadline = DateTime.now().add(const Duration(seconds: 60));
          while (!await marker.exists()) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Host did not grant test permissions');
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        });
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await until(() => has(Keys.preview) && !has(Keys.status));
        expect(
          tester.widget<IconButton>(find.byKey(Keys.shutter)).onPressed,
          isNotNull,
        );
        expect(find.byKey(Keys.status), findsNothing);
        if (photoOnly) {
          await tester.tap(find.byKey(Keys.videoToggle));
          // Accepting a native permission prompt also produces this transient
          // lifecycle pair while the audio-enabled controller is opening.
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await until(() => has(Keys.captureRecordingFrame));
          await tester.pump(const Duration(seconds: 2));
          await tester.tap(find.byKey(Keys.videoToggle));
          await until(shutterReady);
          final video = (await app.vault.list()).singleWhere(
            (file) =>
                !before.contains(file.path) &&
                !added.any((capture) => capture.path == file.path),
          );
          added.add(video);
          expect(video.path, endsWith('.mp4.shtr'));
          final bytes = await app.vault.readAll(video);
          expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');
          expect(
            mp4SampleEntries(bytes),
            containsAll(['avc1', 'mp4a']),
            reason: 'Granted recording must contain H.264 and AAC',
          );
          await takePhoto();
          expect(
            await Directory.systemTemp
                .list(recursive: true)
                .where(
                  (file) =>
                      file.path.endsWith('.jpg') || file.path.endsWith('.mp4'),
                )
                .length,
            0,
            reason: 'No plaintext capture may remain',
          );
        }
        expect(tester.takeException(), isNull);
        expect((await app.vault.list()).map((file) => file.path).toSet(), {
          ...before,
          ...added.map((file) => file.path),
        });
        expect(await plain.exists(), isFalse);
      } finally {
        if (await marker.exists()) await marker.delete();
        await tester.pumpWidget(const SizedBox());
        if (await photo.exists()) await photo.delete();
        for (final capture in added) {
          if (await capture.exists()) await capture.delete();
        }
        await app.close();
      }
    },
  );
}
