// Explicit native Files-provider probe. Only synthetic encrypted ZIPs are used.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/backup/portable_backup.dart';
import 'package:quietake/backup/portable_screen.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

void main() {
  if (!const bool.fromEnvironment('PORTABLE_FILES_CHECK')) {
    throw StateError('Run explicitly with PORTABLE_FILES_CHECK=true');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native encrypted ZIP save, pick and cancellation', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    final temporary = await getTemporaryDirectory();
    final cache = Directory('${temporary.path}/quietake-backup');
    try {
      for (final entry in await app.vault.dir.list().toList()) {
        await entry.delete(recursive: true);
      }
      final plain = await File('${temporary.path}/portable-native.jpg')
          .writeAsBytes(fixtureBytes('tiny.jpg'));
      await app.vault.ingestAs(plain, 'portable-native.jpg');
      await cache.create(recursive: true);
      final source = File('${cache.path}/Quietake-backup.zip');
      final backup = PortableBackup(app.vault, app.vault.masterKeyForTests);
      await backup.export(source);
      final encrypted = await source.readAsBytes();
      await tester.pumpWidget(app.widget());
      await tester.pump(const Duration(seconds: 1));

      Future<T?> checkpoint<T>(
        String method, [
        Map<String, dynamic>? arguments,
      ]) async {
        T? value;
        Object? error;
        var done = false;
        portableChannel
            .invokeMethod<T>(method, arguments)
            .then(
              (result) {
                value = result;
                done = true;
              },
              onError: (Object failure) {
                error = failure;
                done = true;
              },
            );
        debugPrint('PORTABLE_FILES_HOST_$method');
        final deadline = DateTime.now().add(const Duration(seconds: 120));
        while (!done) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Native Files checkpoint deadline: $method');
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(error, isNull);
        return value;
      }

      expect(await checkpoint<bool>('save', {'path': source.path}), isTrue);
      final selected = await checkpoint<String>('pick');
      expect(selected, isNotNull);
      final copy = File(selected!);
      expect(
        sha256.convert(await copy.readAsBytes()),
        sha256.convert(encrypted),
      );
      final validated = await backup.stage(copy, app.session.store.dir);
      await validated.delete(recursive: true);
      expect(await copy.readAsBytes(), encrypted);
      expect(await checkpoint<String>('pick'), isNull);
      expect(await checkpoint<bool>('save', {'path': source.path}), isFalse);
      await portableChannel.invokeMethod<void>('clear');
      expect(await cache.exists(), isFalse);
      final containers = await app.vault.list();
      expect(containers, hasLength(1));
      expect(
        await app.vault.readAll(containers.single),
        fixtureBytes('tiny.jpg'),
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await app.close();
      if (await cache.exists()) await cache.delete(recursive: true);
    }
  });
}
