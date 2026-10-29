import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/cast/google_cast_backend.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/main.dart' as app;

/// Exercises real startup, including platform initialization omitted by the harness.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real entry point reaches the vault gate without initializing Cast',
    (tester) async {
      await app.main();
      final end = DateTime.now().add(const Duration(seconds: 30));
      while (find.byKey(Keys.setupSubmit).evaluate().isEmpty &&
          find.byKey(Keys.lockUnlock).evaluate().isEmpty &&
          find.byKey(Keys.openGallery).evaluate().isEmpty) {
        if (DateTime.now().isAfter(end)) {
          fail('Real startup did not reach a usable screen');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'Quietake',
      );
      if (find.byKey(Keys.openGallery).evaluate().isEmpty) {
        expect(find.text('Quietake'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('native Android Cast SDK initializes and stops discovery', (
    tester,
  ) async {
    final backend = GoogleCastBackend();
    await tester.runAsync(() async {
      await backend.startDiscovery().timeout(const Duration(seconds: 20));
      await backend.stopDiscovery().timeout(const Duration(seconds: 5));
    });
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isAndroid);
  testWidgets('native microphone bridge returns the granted permission', (
    tester,
  ) async {
    // The emulator runners grant audio before launch; no native dialog is needed.
    expect(
      await const MethodChannel('quietake/camera')
          .invokeMethod<bool>('requestMicrophone'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native video preparation rejects damaged media without deleting input',
    (tester) async {
      final temp = await getTemporaryDirectory();
      final input = await File('${temp.path}/invalid-video.mp4')
          .writeAsBytes([1, 2, 3]);
      try {
        await expectLater(
          const MethodChannel(
            'quietake/camera',
          ).invokeMethod<String>('prepareVideo', {
            'path': input.path,
            'pending':
                '${(await getApplicationDocumentsDirectory()).path}/vault/.captures',
          }),
          throwsA(isA<PlatformException>()),
        );
        expect(await input.readAsBytes(), [1, 2, 3]);
        expect(
          await Directory('${temp.path}/video-preparation').list().length,
          0,
        );
      } finally {
        await input.delete();
      }
    },
    skip: !Platform.isAndroid,
  );
}
