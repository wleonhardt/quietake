import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/privacy/privacy_controller.dart';
import 'package:quietake/privacy/privacy_scope.dart';
import 'package:quietake/session.dart';
import 'package:quietake/sync/nas_recovery_screen.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_cast_backend.dart';

class _Store extends MasterKeyStore {
  _Store(super.sodium, super.dir);
  int unlocks = 0;
  @override
  Future<SecureKey> unlockWithPasscode(String pin) async {
    unlocks++;
    FlutterSecureStorage.setMockInitialValues({});
    throw WrongPasscodeException();
  }
}

void main() {
  for (final mode in ['lock', 'coalesced', 'background']) {
    testWidgets('late recovery confirmation cannot survive $mode', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      await const SyncSettings(
        url: 'https://fixture.example/vault/',
        username: 'fixture',
        password: 'synthetic',
      ).save();
      late Directory dir;
      late Session session;
      late _Store store;
      await tester.runAsync(() async {
        final sodium = await SodiumSumoInit.init();
        dir = await Directory.systemTemp.createTemp('recovery-lock-');
        final vault = Vault(
          VaultCrypto(sodium),
          sodium.crypto.secretBox.keygen(),
          dir,
        );
        store = _Store(sodium, dir);
        session = Session(
          vault: vault,
          server: await MediaServer.start(vault),
          cast: CastController(vault, FakeCastBackend()),
          store: store,
        );
      });
      final privacy = PrivacyController(onLock: () {})
        ..minutes = 0
        ..setEnabled(true);
      addTearDown(() async {
        if (tester.binding.lifecycleState == AppLifecycleState.paused) {
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        await tester.pumpWidget(const SizedBox());
        privacy.dispose();
        await tester.runAsync(() async {
          await session.close();
          await dir.delete(recursive: true);
        });
      });
      await tester.pumpWidget(
        PrivacyScope(
          controller: privacy,
          child: MaterialApp(
            theme: quietakeTheme(),
            home: NasRecoveryScreen(store: store, session: session),
          ),
        ),
      );
      for (final field in [
        Keys.nasPin,
        Keys.nasPhrase,
        Keys.nasPhraseConfirm,
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(field),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.byKey(field),
          field == Keys.nasPin
              ? 'old-pin'
              : 'synthetic river violet paper lantern canyon',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.byKey(Keys.nasSave),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(Keys.nasSave));
      await tester.pumpAndSettle();
      if (mode == 'background') {
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
      } else {
        privacy.setEnabled(false);
        if (mode == 'lock') await tester.pump();
        privacy.setEnabled(true);
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(Keys.nasChangeConfirm));
      await tester.tap(find.byKey(Keys.nasChangeConfirm));
      await tester.pumpAndSettle();
      expect(
        store.unlocks,
        0,
        reason: 'A pre-lock PIN must not authorize a late confirmation',
      );
    });
  }
}
