import '../test_support/test_vault.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quietake/cast/cast_controller.dart';
import 'package:quietake/main.dart';
import 'package:quietake/media/media_server.dart';
import 'package:quietake/session.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:quietake/vault/vault.dart';

import '../test_support/fake_authenticator.dart';
import '../test_support/fake_cast_backend.dart';

/// An already-unlocked app for tests that are not about the lock screen:
/// the vault opens with the keystore key, no keyfile is written, so the
/// capture screen is the first thing on screen.
class TestApp {
  TestApp._(this.session, this.backend, this.auth);

  final Session session;
  final FakeCastBackend backend;
  final FakeAuthenticator auth;

  Vault get vault => session.vault;

  static Future<TestApp> unlocked() async {
    final vault = await openTestVault();
    final docs = await getApplicationDocumentsDirectory();
    final store = MasterKeyStore(vault.crypto.sodium, docs);
    if (await store.hasKeyfile) await store.keyfile.delete();
    final backend = FakeCastBackend();
    final session = Session(
      vault: vault,
      server: await MediaServer.start(vault),
      cast: CastController(vault, backend),
      store: store,
    );
    return TestApp._(session, backend, FakeAuthenticator());
  }

  Widget widget({Duration? idleTimeout}) => QuietakeApp(
        idleTimeout: idleTimeout,
        store: session.store,
        auth: auth,
        castBackend: backend,
        session: session,
      );

  Future<void> close() async {
    await session.close();
  }
}
