import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/backup/portable_backup.dart';
import 'package:quietake/backup/portable_screen.dart';
import 'package:quietake/backup/restore_startup_gate.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/main.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';
import '../test_support/fake_cast_backend.dart';
import '../test_support/fixtures.dart';
import '../test_support/legacy_backup.dart';
import 'harness.dart';

class _PauseAtReadyStore extends MasterKeyStore {
  _PauseAtReadyStore(super.sodium, super.dir, this.pause)
    : _plain = MasterKeyStore(sodium, dir);
  final MasterKeyStore _plain;
  final void Function() pause;
  @override
  Future<File> preparePortableKeyfile(SecureKey key, String passcode) =>
      _plain.preparePortableKeyfile(key, passcode);
  @override
  Future<SecureKey> unlockWithPasscode(String passcode) =>
      _plain.unlockWithPasscode(passcode);
  bool fired = false;
  @override
  File get keyfile {
    if (!fired && File('${dir.path}/.portable-restore/ready').existsSync()) {
      fired = true;
      pause();
    }
    return super.keyfile;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  void lifecycle(bool foreground) {
    final states = foreground
        ? [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]
        : [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ];
    final current = binding.lifecycleState;
    if (foreground && current == AppLifecycleState.resumed ||
        !foreground && current == AppLifecycleState.paused) {
      return;
    }
    for (final state in states) {
      binding.handleAppLifecycleStateChanged(state);
    }
  }

  late Directory cache;
  late Directory docs;
  setUp(() async {
    cache = Directory(
      '${(await getTemporaryDirectory()).path}/quietake-backup',
    );
    docs = await getApplicationDocumentsDirectory();
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      portableChannel,
      null,
    );
    lifecycle(true);
    if (await cache.exists()) await cache.delete(recursive: true);
  });

  Future<void> until(WidgetTester tester, bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Portable backup checkpoint timed out');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byKey(key).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        220,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> enter(WidgetTester tester, Key key, String value) async {
    final field = find.byKey(key);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    final controller = tester.widget<TextField>(field).controller!;
    if (controller.text != value) controller.text = value;
  }

  Future<void> seed(TestApp app) async {
    for (final entry in await app.vault.dir.list().toList()) {
      await entry.delete(recursive: true);
    }
    for (final name in ['tiny.jpg', 'tiny.mp4']) {
      final input = await File(
        '${(await getTemporaryDirectory()).path}/portable-$name',
      ).writeAsBytes(fixtureBytes(name));
      await app.vault.ingestAs(input, 'portable-$name');
    }
    await app.vault.catalog.renameItem(
      'portable-tiny.jpg.shtr',
      'Private favorite',
    );
    await app.vault.catalog.organize({
      'portable-tiny.jpg.shtr',
    }, favorite: true);
  }

  testWidgets('interrupted restore preserves files and offers working retry', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    final pending = await Directory('${docs.path}/.portable-restore').create();
    final ready = await File('${pending.path}/ready').writeAsString('invalid');
    final original = await File('${app.vault.dir.path}/preserved.shtr')
        .writeAsBytes([7, 8, 9]);
    try {
      await tester.pumpWidget(
        RestoreStartupGate(
          store: app.session.store,
          child: const MaterialApp(home: Text('Restore startup finished')),
        ),
      );
      await until(
        tester,
        () => find.byKey(Keys.portableStartupRetry).evaluate().isNotEmpty,
      );
      expect(await ready.readAsString(), 'invalid');
      expect(await original.readAsBytes(), [7, 8, 9]);
      await ready.delete();
      await tap(tester, Keys.portableStartupRetry);
      await until(
        tester,
        () => find.text('Restore startup finished').evaluate().isNotEmpty,
      );
      expect(await original.readAsBytes(), [7, 8, 9]);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await app.close();
    }
  });

  testWidgets(
    'export requires passcode, saves only encrypted ZIP and clears private copy',
    (tester) async {
      final app = await TestApp.unlocked();
      await seed(app);
      (await app.session.store.createWithPasscode('portable-passcode'))
          .dispose();
      final external = File('${docs.path}/portable-saved.zip');
      var sends = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(portableChannel, (
        call,
      ) async {
        if (call.method == 'save') {
          final file = File((call.arguments as Map)['path'] as String);
          expect(await file.exists(), isTrue);
          expect(await file.length(), greaterThan(22));
          await file.copy(external.path);
          sends++;
          return true;
        }
        if (call.method == 'clear' && await cache.exists()) {
          await cache.delete(recursive: true);
        }
        return null;
      });
      try {
        await tester.pumpWidget(app.widget());
        await until(
          tester,
          () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.openGallery);
        await until(
          tester,
          () => find.byKey(Keys.gallerySettings).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.gallerySettings);
        await until(
          tester,
          () => find.byKey(Keys.settingsUrl).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.portableExportOpen);
        expect(find.byKey(Keys.portableResult), findsNothing);
        await tap(tester, Keys.portableDetails);
        expect(find.textContaining('Up to 10,000 captures'), findsOneWidget);
        await tester.tap(find.text('Backup limits and storage'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('Up to 10,000 captures'), findsNothing);
        await enter(tester, Keys.portablePasscode, 'wrong-passcode');
        await tap(tester, Keys.portableStart);
        await until(
          tester,
          () =>
              find.byKey(Keys.portableResult).evaluate().isNotEmpty &&
              tester
                  .widget<Text>(find.byKey(Keys.portableResult))
                  .data!
                  .startsWith('Wrong passcode'),
        );
        expect(sends, 0);
        await enter(tester, Keys.portablePasscode, 'portable-passcode');
        await tap(tester, Keys.portableStart);
        await until(
          tester,
          () =>
              sends == 1 &&
              find.byKey(Keys.portableProgress).evaluate().isEmpty,
        );
        expect(await cache.exists(), isFalse);
        final key = await app.session.store.unlockWithPasscode(
          'portable-passcode',
        );
        try {
          final restored = await PortableBackup(
            app.vault,
            key,
          ).stage(external, docs);
          final vault = Vault(app.vault.crypto, key.copy(), restored);
          try {
            expect(await vault.list(), hasLength(2));
            expect(
              await vault.readAll(
                File('${restored.path}/portable-tiny.jpg.shtr'),
              ),
              fixtureBytes('tiny.jpg'),
            );
            await vault.catalog.load();
            expect(
              vault.catalog.details('portable-tiny.jpg.shtr').title,
              'Private favorite',
            );
          } finally {
            await vault.catalog.close();
            vault.dispose();
            await restored.delete(recursive: true);
          }
        } finally {
          key.dispose();
        }
        expect(await app.vault.list(), hasLength(2));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await app.close();
        if (await external.exists()) await external.delete();
      }
    },
  );

  for (final (pauseAtCommit, legacy) in [
    (false, false),
    (true, false),
    (false, true),
  ]) {
    testWidgets(
      '${legacy ? 'legacy' : 'fresh'} ZIP restore preserves identity${pauseAtCommit ? ' and locks completion while backgrounded' : ''}',
      (tester) async {
        final app = await TestApp.unlocked();
        await seed(app);
        final key = app.vault.masterKeyForTests.copy();
        final crypto = app.vault.crypto;
        final source = File('${docs.path}/portable-source.zip');
        final tag = await app.vault.catalog.createAlbum('Migration tag');
        await app.vault.catalog.organize(
          {'portable-tiny.jpg.shtr'},
          tagIds: {tag},
        );
        final encrypted = {
          for (final file in await app.vault.list())
            file.uri.pathSegments.last: await file.readAsBytes(),
        };
        if (legacy) {
          await writeLegacyArchive(
            app.vault,
            key,
            source,
            await app.vault.catalog.file.readAsBytes(),
            encrypted,
          );
        } else {
          await PortableBackup(app.vault, key).export(source);
        }
        final original = await source.readAsBytes();
        await app.close();
        await Directory('${docs.path}/vault').delete(recursive: true);
        await const FlutterSecureStorage().deleteAll();
        final store = pauseAtCommit
            ? _PauseAtReadyStore(crypto.sodium, docs, () => lifecycle(false))
            : MasterKeyStore(crypto.sodium, docs);
        if (await store.hasKeyfile) await store.keyfile.delete();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          portableChannel,
          (call) async {
            if (call.method == 'pick') {
              await cache.create(recursive: true);
              return (await source.copy('${cache.path}/selected.zip')).path;
            }
            if (call.method == 'clear' && await cache.exists()) {
              await cache.delete(recursive: true);
            }
            return null;
          },
        );
        try {
          await tester.pumpWidget(
            QuietakeApp(
              store: store,
              auth: FakeAuthenticator(isAvailable: false),
              castBackend: FakeCastBackend(),
            ),
          );
          await until(
            tester,
            () => find.byKey(Keys.portableRestoreOpen).evaluate().isNotEmpty,
          );
          await tap(tester, Keys.portableRestoreOpen);
          await tap(tester, Keys.portablePick);
          expect(
            tester
                .widget<TextField>(find.byKey(Keys.portableRecovery))
                .obscureText,
            isTrue,
          );
          await enter(tester, Keys.portableRecovery, store.exportRecovery(key));
          await enter(tester, Keys.portablePasscode, 'restored-passcode');
          await enter(tester, Keys.portableConfirm, 'restored-passcode');
          await tester.ensureVisible(find.byKey(Keys.portableStart));
          await tester.pumpAndSettle();
          expect(find.byKey(Keys.portableStart).hitTestable(), findsOneWidget);
          await tester.tap(find.byKey(Keys.portableStart));
          if (pauseAtCommit) {
            final deadline = DateTime.now().add(const Duration(seconds: 30));
            while (!await File('${docs.path}/vault.keyfile.json').exists()) {
              if (DateTime.now().isAfter(deadline)) {
                fail(
                  'Restore credentials were not committed: ${find.byKey(Keys.portableResult).evaluate().isEmpty ? 'no restore screen' : tester.widget<Text>(find.byKey(Keys.portableResult)).data}',
                );
              }
              // The simulated background state disables frames until resumed.
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }
            expect(binding.lifecycleState, AppLifecycleState.paused);
            lifecycle(true);
          }
          await until(
            tester,
            () => find.byKey(Keys.portableScreen).evaluate().isEmpty,
          );
          await tester.pump(const Duration(seconds: 2));
          await until(
            tester,
            () => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty,
          );
          expect(find.byKey(Keys.openGallery), findsNothing);
          if (pauseAtCommit) {
            expect((store as _PauseAtReadyStore).fired, isTrue);
          }
          await enter(tester, Keys.lockPasscode, 'restored-passcode');
          await tap(tester, Keys.lockUnlock);
          await until(
            tester,
            () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
          );
          final opened = await store.unlockWithPasscode('restored-passcode');
          final vault = Vault(crypto, opened, Directory('${docs.path}/vault'));
          try {
            expect(vault.matchesKey(key), isTrue);
            expect(
              await File('${vault.dir.path}/quietake.catalog').exists(),
              isTrue,
            );
            expect(
              await File('${vault.dir.path}/tucklight.catalog').exists(),
              isFalse,
            );
            for (final entry in encrypted.entries) {
              expect(
                await File('${vault.dir.path}/${entry.key}').readAsBytes(),
                entry.value,
              );
            }
            expect(await vault.list(), hasLength(2));
            expect(
              await vault.readAll(
                File('${vault.dir.path}/portable-tiny.mp4.shtr'),
              ),
              fixtureBytes('tiny.mp4'),
            );
            await vault.catalog.load();
            expect(vault.catalog.albums[tag], 'Migration tag');
            expect(vault.catalog.details('portable-tiny.jpg.shtr').albums, {
              tag,
            });
            expect(
              vault.catalog.details('portable-tiny.jpg.shtr').favorite,
              isTrue,
            );
          } finally {
            await vault.catalog.close();
            vault.dispose();
          }
          expect(await source.readAsBytes(), original);
          expect(await cache.exists(), isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          lifecycle(true);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          key.dispose();
          if (await source.exists()) await source.delete();
        }
      },
    );
  }
}
