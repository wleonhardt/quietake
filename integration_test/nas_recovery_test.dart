import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/backup/restore_startup_gate.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/sync/webdav_client.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/main.dart';
import 'package:quietake/sync/background_uploads.dart';
import 'package:quietake/sync/nas_recovery.dart';
import 'package:quietake/sync/nas_recovery_screen.dart';
import 'package:quietake/sync/sync_service.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/integration_binding.dart';
import '../test_support/fake_authenticator.dart';
import '../test_support/fake_cast_backend.dart';
import '../test_support/fake_webdav_server.dart';
import '../test_support/fixtures.dart';
import 'harness.dart';

class _PauseStore extends MasterKeyStore {
  _PauseStore(super.sodium, super.dir, this.pause)
    : plain = MasterKeyStore(sodium, dir);
  final MasterKeyStore plain;
  final VoidCallback pause;
  bool fired = false;
  @override
  Future<File> preparePortableKeyfile(SecureKey key, String pin) =>
      plain.preparePortableKeyfile(key, pin);
  @override
  Future<SecureKey> unlockWithPasscode(String pin) =>
      plain.unlockWithPasscode(pin);
  @override
  Future<SecureKey> openBackupKey(List<int> bytes, String phrase) =>
      plain.openBackupKey(bytes, phrase);
  @override
  File get keyfile {
    if (!fired && File('${dir.path}/.portable-restore/ready').existsSync()) {
      fired = true;
      pause();
    }
    return super.keyfile;
  }
}

const phrase = 'synthetic river violet paper lantern canyon';
void main() {
  final binding = initializeIntegrationBinding();
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
    if (foreground && binding.lifecycleState == AppLifecycleState.resumed ||
        !foreground && binding.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    for (final state in states) {
      binding.handleAppLifecycleStateChanged(state);
    }
  }

  Future<void> until(WidgetTester tester, bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        fail(
          'NAS recovery checkpoint: ${find.byKey(Keys.nasResult).evaluate().isEmpty ? 'no result' : tester.widget<Text>(find.byKey(Keys.nasResult)).data}',
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byKey(key).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await reveal(tester, key);
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> enter(WidgetTester tester, Key key, String value) async {
    await reveal(tester, key);
    final controller = tester.widget<TextField>(find.byKey(key)).controller!;
    await tester.enterText(find.byKey(key), value);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    if (controller.text != value) controller.text = value;
  }

  Future<void> seed(TestApp app, {bool media = true}) async {
    await BackgroundUploads().reset();
    for (final f in await app.vault.dir.list().toList()) {
      await f.delete(recursive: true);
    }
    (await app.session.store.restoreFromRecovery(
      app.session.store.exportRecovery(app.vault.masterKeyForTests),
      'recovery-local-passcode',
    )).dispose();
    if (media) {
      for (final name in ['tiny.jpg', 'tiny.mp4']) {
        final input = await File(
          '${(await getTemporaryDirectory()).path}/recovery-$name',
        ).writeAsBytes(fixtureBytes(name));
        await app.vault.ingestAs(input, 'recovery-$name');
      }
    }
  }

  String result(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(Keys.nasResult)).data ?? '';
  testWidgets(
    'saved NAS passphrase requires current passcode, changes safely and disables explicitly',
    (tester) async {
      final app = await TestApp.unlocked();
      final dav = await FakeWebDavServer.start();
      try {
        await seed(app);
        await app.session.sync.saveSettings(
          SyncSettings(
            url: dav.url.toString(),
            username: dav.username,
            password: dav.password,
          ),
        );
        await app.session.sync.sync();
        final originals = {
          for (final f in await app.vault.list())
            f.uri.pathSegments.last: await f.readAsBytes(),
        };
        final keyfile = await app.session.store.keyfile.readAsBytes();
        await tester.pumpWidget(app.widget());
        await until(
          tester,
          () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
        );
        await tap(tester, Keys.openGallery);
        await tap(tester, Keys.gallerySettings);
        await tap(tester, Keys.nasRecoveryOpen);
        await enter(tester, Keys.nasPin, 'wrong');
        await tap(tester, Keys.nasGenerate);
        final generated = tester
            .widget<TextField>(find.byKey(Keys.nasPhrase))
            .controller!
            .text;
        expect(generated.split(' '), hasLength(6));
        await enter(tester, Keys.nasPhraseConfirm, generated);
        await tap(tester, Keys.nasSave);
        await tap(tester, Keys.nasChangeConfirm);
        await until(tester, () => result(tester).contains('Wrong current'));
        expect(dav.files.containsKey(MasterKeyStore.recoveryBoxName), isFalse);
        await enter(tester, Keys.nasPin, 'recovery-local-passcode');
        await enter(tester, Keys.nasPhrase, phrase);
        await enter(tester, Keys.nasPhraseConfirm, phrase);
        await tap(tester, Keys.nasSave);
        await tap(tester, Keys.nasChangeConfirm);
        await until(tester, () => result(tester).contains('passphrase saved'));
        final opened = await app.session.store.openBackupKey(
          dav.files[MasterKeyStore.recoveryBoxName]!,
          phrase,
        );
        try {
          expect(app.vault.matchesKey(opened), isTrue);
        } finally {
          opened.dispose();
        }
        // An unchanged catalog cannot mask a concurrently changed envelope.
        final concurrent = [...dav.files[MasterKeyStore.recoveryBoxName]!, 32];
        dav.beforeRequest = (request) async {
          if (request.method == 'MOVE') {
            dav.files[MasterKeyStore.recoveryBoxName] = concurrent;
          }
        };
        await expectLater(
          app.session.sync.recoveryOperation(
            (client) => NasRecovery(app.session.store, client).change(
              app.vault,
              'recovery-local-passcode',
              'another meadow silver lantern river canopy',
            ),
          ),
          throwsA(isA<WebDavException>()),
        );
        expect(dav.files[MasterKeyStore.recoveryBoxName], concurrent);
        dav.beforeRequest = null;
        await enter(tester, Keys.nasPin, 'recovery-local-passcode');
        await tap(tester, Keys.nasDisable);
        await tap(tester, Keys.nasDisableConfirm);
        await until(tester, () => result(tester).contains('recovery disabled'));
        await app.session.sync.sync();
        expect(dav.files.containsKey(MasterKeyStore.recoveryBoxName), isFalse);
        expect(await app.session.store.keyfile.readAsBytes(), keyfile);
        for (final entry in originals.entries) {
          expect(dav.files[entry.key], entry.value);
          expect(
            await File('${app.vault.dir.path}/${entry.key}').readAsBytes(),
            entry.value,
          );
        }
        expect(
          await app.vault.dir
              .list()
              .where((e) => e.path.endsWith('.part'))
              .toList(),
          isEmpty,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await app.close();
        await BackgroundUploads().reset();
        await dav.close();
      }
    },
  );
  testWidgets('locked recovery confirmation cannot reuse a pre-lock passcode', (
    tester,
  ) async {
    final app = await TestApp.unlocked();
    final dav = await FakeWebDavServer.start();
    try {
      await seed(app);
      await app.session.sync.saveSettings(
        SyncSettings(
          url: dav.url.toString(),
          username: dav.username,
          password: dav.password,
        ),
      );
      await app.session.sync.sync();
      await tester.pumpWidget(app.widget());
      await until(
        tester,
        () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
      );
      await tap(tester, Keys.openGallery);
      await tap(tester, Keys.gallerySettings);
      await tap(tester, Keys.nasRecoveryOpen);
      await enter(tester, Keys.nasPin, 'recovery-local-passcode');
      await enter(tester, Keys.nasPhrase, phrase);
      await enter(tester, Keys.nasPhraseConfirm, phrase);
      await tap(tester, Keys.nasSave);
      PrivacyScope.maybeOf(tester.element(find.byKey(Keys.nasChangeConfirm)))!
          .lock();
      await until(
        tester,
        () => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty,
      );
      await enter(tester, Keys.lockPasscode, 'recovery-local-passcode');
      await tap(tester, Keys.lockUnlock);
      await tap(tester, Keys.nasChangeConfirm);
      await tester.pump(const Duration(seconds: 1));
      expect(dav.files.containsKey(MasterKeyStore.recoveryBoxName), isFalse);
      await reveal(tester, Keys.nasPin);
      expect(
        tester.widget<TextField>(find.byKey(Keys.nasPin)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await app.close();
      await BackgroundUploads().reset();
      await dav.close();
    }
  });

  testWidgets(
    'NAS recovery confirmation fits landscape with large text and keyboard',
    (tester) async {
      await SyncSettings.clear();
      final app = await TestApp.unlocked();
      try {
        // Isolate the layout from the root native privacy gate: artificial
        // metrics must not manufacture lifecycle locks during this assertion.
        await tester.pumpWidget(
          MaterialApp(
            theme: quietakeTheme(),
            home: NasRecoveryScreen(
              store: app.session.store,
              session: app.session,
            ),
          ),
        );
        tester.view.physicalSize = Size(
          740 * tester.view.devicePixelRatio,
          360 * tester.view.devicePixelRatio,
        );
        await tester.binding.setSurfaceSize(const Size(740, 360));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pump(const Duration(milliseconds: 500));
        await enter(tester, Keys.nasPin, 'unused-fixture-pin');
        await enter(tester, Keys.nasPhrase, phrase);
        await enter(tester, Keys.nasPhraseConfirm, phrase);
        await reveal(tester, Keys.nasSave);
        tester.view.viewInsets = FakeViewPadding(
          bottom: 180 * tester.view.devicePixelRatio,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.byKey(Keys.nasSave));
        await tester.tap(find.byKey(Keys.nasSave));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.byKey(Keys.nasChangeConfirm));
        expect(
          tester.takeException(),
          isNull,
          reason: 'Confirmation must fit the available space',
        );
        expect(find.byKey(Keys.nasChangeConfirm).hitTestable(), findsOneWidget);
        final button = find.byKey(Keys.nasChangeConfirm);
        expect(button, findsOneWidget);
        await tester.tap(find.text('Cancel').last);
        await tester.pump(const Duration(milliseconds: 500));
      } finally {
        tester.view.resetViewInsets();
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        await app.close();
      }
    },
  );

  for (final mode in ['media', 'metadata', 'background']) {
    testWidgets(
      'fresh NAS passphrase restore $mode authenticates originals and requires new unlock',
      (tester) async {
        final app = await TestApp.unlocked();
        final dav = await FakeWebDavServer.start();
        final docs = await getApplicationDocumentsDirectory();
        SecureKey? originalKey;
        try {
          await seed(app, media: mode != 'metadata');
          final client = SyncSettings(
            url: dav.url.toString(),
            username: dav.username,
            password: dav.password,
          ).client();
          try {
            await SyncService(app.vault, client).sync();
            await NasRecovery(
              app.session.store,
              client,
            ).change(app.vault, 'recovery-local-passcode', phrase);
          } finally {
            client.close();
          }
          originalKey = app.vault.masterKeyForTests.copy();
          final crypto = app.vault.crypto;
          final original = {
            for (final entry in dav.files.entries)
              entry.key: List<int>.of(entry.value),
          };
          await app.close();
          await Directory('${docs.path}/vault').delete(recursive: true);
          await const FlutterSecureStorage().deleteAll();
          final store = mode == 'background'
              ? _PauseStore(crypto.sodium, docs, () => lifecycle(false))
              : MasterKeyStore(crypto.sodium, docs);
          if (await store.hasKeyfile) await store.keyfile.delete();
          final abandoned = await Directory('${docs.path}/.portable-restore')
              .create();
          expect(await File('${abandoned.path}/ready').exists(), isFalse);
          await tester.pumpWidget(
            RestoreStartupGate(
              store: store,
              child: QuietakeApp(
                store: store,
                auth: FakeAuthenticator(isAvailable: false),
                castBackend: FakeCastBackend(),
              ),
            ),
          );
          await until(
            tester,
            () => find.byKey(Keys.nasRestoreOpen).evaluate().isNotEmpty,
          );
          expect(
            await abandoned.exists(),
            isFalse,
            reason: 'Fresh launch must clear uncommitted restore staging',
          );
          await tap(tester, Keys.nasRestoreOpen);
          await enter(tester, Keys.nasUrl, dav.url.toString());
          await enter(tester, Keys.nasUser, dav.username);
          await enter(tester, Keys.nasPassword, dav.password);
          await enter(tester, Keys.nasPin, 'restored-passcode');
          await enter(tester, Keys.nasPinConfirm, 'restored-passcode');
          await enter(tester, Keys.nasPhrase, phrase);
          expect(
            tester.widget<TextField>(find.byKey(Keys.nasPhrase)).obscureText,
            isTrue,
          );
          await reveal(tester, Keys.nasStartRestore);
          await tester.tap(find.byKey(Keys.nasStartRestore));
          if (mode == 'background') {
            final deadline = DateTime.now().add(const Duration(seconds: 60));
            while (!await File('${docs.path}/vault.keyfile.json').exists()) {
              if (DateTime.now().isAfter(deadline)) {
                fail('Restore commit deadline');
              }
              // The simulated background state disables frames until resumed.
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }
            expect(binding.lifecycleState, AppLifecycleState.paused);
            lifecycle(true);
            expect((store as _PauseStore).fired, isTrue);
          }
          await until(
            tester,
            () => find.byKey(Keys.lockPasscode).evaluate().isNotEmpty,
          );
          expect(find.byKey(Keys.openGallery), findsNothing);
          expect(dav.files, original);
          await enter(tester, Keys.lockPasscode, 'restored-passcode');
          await tap(tester, Keys.lockUnlock);
          await until(
            tester,
            () => find.byKey(Keys.openGallery).evaluate().isNotEmpty,
          );
          final key = await store.unlockWithPasscode('restored-passcode');
          final recovered = Vault(crypto, key, Directory('${docs.path}/vault'));
          try {
            expect(recovered.matchesKey(originalKey), isTrue);
            final files = await recovered.list();
            expect(files, hasLength(mode == 'metadata' ? 0 : 2));
            if (files.isNotEmpty) {
              expect(
                await recovered.readAll(
                  files.firstWhere((f) => f.path.endsWith('.mp4.shtr')),
                ),
                fixtureBytes('tiny.mp4'),
              );
            }
            await recovered.catalog.validate(recovered.catalog.file);
          } finally {
            await recovered.catalog.close();
            recovered.dispose();
          }
          expect((await SyncSettings.load()).backgroundUploads, isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          lifecycle(true);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          originalKey?.dispose();
          await BackgroundUploads().reset();
          await dav.close();
        }
      },
    );
  }
}
