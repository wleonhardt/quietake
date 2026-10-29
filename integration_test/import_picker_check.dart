import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/library/import_media.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

/// Explicit OS picker check. Host selects the synthetic Download fixture or
/// cancels. No private user file is selected and no screen is captured.
void main() {
  if (!const bool.fromEnvironment('QUIETAKE_IMPORT_CHECK')) {
    throw StateError('Run explicitly with QUIETAKE_IMPORT_CHECK=true');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Files picker copies or cancels without changing originals',
    (tester) async {
      final app = await TestApp.unlocked();
      for (final entry in await app.vault.dir.list().toList()) {
        await entry.delete(recursive: true);
      }
      await tester.pumpWidget(app.widget());
      await tester.pump(const Duration(seconds: 1));
      List<dynamic>? selected;
      Object? error;
      importChannel
          .invokeListMethod<dynamic>('pick')
          .then<void>(
            (items) {
              selected = items ?? [];
            },
            onError: (Object e) {
              error = e;
            },
          );
      const cancelled = bool.fromEnvironment('QUIETAKE_IMPORT_CANCEL');
      if (cancelled) await importChannel.invokeMethod<void>('cancel');
      debugPrint('NATIVE_IMPORT_WAITING_FOR_HOST');
      final end = DateTime.now().add(const Duration(seconds: 90));
      while (selected == null && error == null) {
        if (DateTime.now().isAfter(end)) {
          fail('Native picker host checkpoint timed out');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(error, isNull);
      final inputs = selected!.map((raw) {
        final entry = raw as Map;
        return ImportInput(
          name: entry['name'] as String,
          path: entry['path'] as String?,
          error: entry['error'] as String?,
        );
      }).toList();
      final temp = await getTemporaryDirectory();
      final staging = Directory('${temp.path}/quietake-import');
      final results = await MediaImporter(app.vault, staging).run(inputs);
      if (cancelled || const bool.fromEnvironment('QUIETAKE_IMPORT_LIMIT')) {
        expect(
          inputs.single.error,
          cancelled ? 'Cancelled' : 'Import size limit exceeded.',
        );
        expect(inputs.single.path, isNull);
        expect(await app.vault.list(), isEmpty);
      } else if (const bool.fromEnvironment('QUIETAKE_IMPORT_SELECT')) {
        expect(
          results.single.status,
          ImportStatus.imported,
          reason: results.map((r) => r.message).join(','),
        );
        expect(
          await app.vault.readAll((await app.vault.list()).single),
          fixtureBytes('tiny.jpg'),
        );
      } else {
        expect(inputs, isEmpty);
        expect(await app.vault.list(), isEmpty);
      }
      expect(await staging.exists(), isFalse);
      await importChannel.invokeMethod<void>('clear');
      await tester.pumpWidget(const SizedBox());
      await app.close();
    },
  );
}
