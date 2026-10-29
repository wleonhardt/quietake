import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/gallery/share_media.dart';

import '../test_support/fixtures.dart';
import 'harness.dart';

// Explicit host-driven, cross-UID check. The normal suite never opens a chooser.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native recipient reads granted copy before return cleanup', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('QUIETAKE_SHARE_CHECK')) {
      return;
    }
    final app = await TestApp.unlocked();
    final root = await getTemporaryDirectory();
    try {
      for (final file in await app.vault.list()) {
        await file.delete();
      }
      const names = bool.fromEnvironment('QUIETAKE_SHARE_BATCH')
          ? ['tiny.jpg', 'tiny.mp4', 'wide.png']
          : ['tiny.jpg'];
      final items = <VaultItem>[];
      final originals = <String, List<int>>{};
      for (final name in names) {
        final source = await File('${root.path}/receiver-source')
            .writeAsBytes(fixtureBytes(name));
        final item = VaultItem(
          await app.vault.ingestAs(source, 'receiver-$name'),
        );
        items.add(item);
        originals[item.file.path] = await item.file.readAsBytes();
      }
      await tester.pumpWidget(app.widget());
      await tester.pump(const Duration(seconds: 1));
      final pending = shareMediaCopies(
        app.vault,
        items,
        origin: const Rect.fromLTWH(10, 10, 48, 48),
        isActive: () => true,
      );
      // Host selects its fresh recipient, validates the separate UID receipt,
      // then presses Back. The service must keep exports alive until that return.
      // ignore: avoid_print
      print('NATIVE_SHARE_READY');
      var finished = false;
      Object? failure;
      pending.then<void>(
        (_) {
          finished = true;
        },
        onError: (Object error) {
          failure = error;
          finished = true;
        },
      );
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (!finished) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Share did not finish after recipient return');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (failure != null) throw failure!;
      for (var i = 0; i < items.length; i++) {
        expect(
          await items[i].file.readAsBytes(),
          originals[items[i].file.path],
        );
        expect(await app.vault.readAll(items[i].file), fixtureBytes(names[i]));
      }
      expect(await Directory('${root.path}/quietake-share').exists(), isFalse);
      expect(await Directory('${root.path}/share_plus').exists(), isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await app.close();
    }
  });
}
