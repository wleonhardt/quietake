import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/camera/ingest_video.dart';
import 'package:quietake/camera/capture_store.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

class _FailingCrypto extends VaultCrypto {
  _FailingCrypto(super.sodium, this.failAt);
  final int failAt;
  int writes = 0;
  @override
  Future<void> encryptFile(File plain, File out, SecureKey key) async {
    if (++writes == failAt) {
      await out.writeAsBytes(VaultCrypto.magic);
      throw const FileSystemException('simulated full disk');
    }
    await super.encryptFile(plain, out, key);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('quietake/camera');
  late Directory root;
  late Vault vault;
  late File source;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    root = await Directory.systemTemp.createTemp('video-ingest-test');
    final sodium = await SodiumSumoInit.init();
    vault = Vault(
      VaultCrypto(sodium),
      sodium.crypto.secretBox.keygen(),
      await Directory('${root.path}/vault').create(),
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('quietake/captures'),
      (_) async => true,
    );
    source = await File('${root.path}/source.mp4').writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('quietake/captures'),
      null,
    );
    debugDefaultTargetPlatformOverride = null;
    vault.dispose();
    await root.delete(recursive: true);
  });

  test(
    'conversion encrypts prepared media and removes both plaintext files',
    () async {
      final prepared = await File('${root.path}/prepared.mp4')
          .writeAsBytes([4, 5]);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'prepareVideo');
        expect(
          await File((call.arguments as Map)['path'] as String).readAsBytes(),
          [1, 2, 3],
        );
        return prepared.path;
      });
      final saved = await ingestVideo(vault, source);
      expect(saved.castReady, isTrue);
      expect(await vault.readAll(saved.container), [4, 5]);
      expect(await source.exists(), isFalse);
      expect(await prepared.exists(), isFalse);
      expect((await vault.list()).map((file) => file.path), [
        saved.container.path,
      ]);
    },
  );

  test('compatible recordings remain byte-identical', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => (call.arguments as Map)['path'],
    );
    final saved = await ingestVideo(vault, source);
    expect(saved.castReady, isTrue);
    expect(await vault.readAll(saved.container), [1, 2, 3]);
    expect(await source.exists(), isFalse);
  });

  test(
    'native failure preserves encrypted original and marks casting unavailable',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw PlatformException(code: 'video_preparation');
      });
      final saved = await ingestVideo(vault, source);
      expect(saved.castReady, isFalse);
      expect(await vault.readAll(saved.container), [1, 2, 3]);
      expect(await source.exists(), isFalse);
      expect((await vault.list()).map((file) => file.path), [
        saved.container.path,
      ]);
    },
  );

  test('original is encrypted before native preparation starts', () async {
    List<File> secured = [];
    List<File> visible = [];
    List<int>? original;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final pending = Directory('${vault.dir.path}/.captures');
      if (await pending.exists()) {
        secured = await pending
            .list(recursive: true)
            .where((e) => e is File && e.path.endsWith('.shtr'))
            .cast<File>()
            .toList();
        if (secured.isNotEmpty) original = await vault.readAll(secured.single);
      }
      visible = await vault.list();
      return (call.arguments as Map)['path'];
    });
    await ingestVideo(vault, source);
    expect(secured, hasLength(1));
    expect(original, [1, 2, 3]);
    expect(
      visible,
      isEmpty,
      reason: 'Do not sync an original while conversion can replace it',
    );
  });

  test('failed converted save retains encrypted original', () async {
    final key = vault.masterKeyForTests.copy();
    vault.dispose();
    vault = Vault(
      _FailingCrypto(await SodiumSumoInit.init(), 2),
      key,
      vault.dir,
    );
    final prepared = await File('${root.path}/prepared.mp4')
        .writeAsBytes([4, 5]);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => prepared.path,
    );
    final saved = await ingestVideo(vault, source);
    expect(saved.castReady, isFalse);
    expect(await vault.readAll(saved.container), [1, 2, 3]);
    expect(await prepared.exists(), isFalse);
    expect(await source.exists(), isFalse);
    expect(
      await vault.dir.list().where((e) => e.path.endsWith('.part')).length,
      0,
    );
  });

  test('empty converted output retains encrypted original', () async {
    final prepared = await File('${root.path}/empty.mp4').writeAsBytes([]);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => prepared.path,
    );
    final saved = await ingestVideo(vault, source);
    expect(saved.castReady, isFalse);
    expect(await vault.readAll(saved.container), [1, 2, 3]);
  });

  test(
    'initial encryption failure retains private pending recording',
    () async {
      final key = vault.masterKeyForTests.copy();
      vault.dispose();
      vault = Vault(
        _FailingCrypto(await SodiumSumoInit.init(), 1),
        key,
        vault.dir,
      );
      var preparationCalls = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        preparationCalls++;
        return source.path;
      });
      await expectLater(
        ingestVideo(vault, source),
        throwsA(isA<PendingCaptureException>()),
      );
      expect(preparationCalls, 0);
      final pending = Directory('${vault.dir.path}/.captures');
      expect(await pending.exists(), isTrue);
      final files = await pending
          .list(recursive: true)
          .where((e) => e is File && e.path.endsWith('.mp4'))
          .cast<File>()
          .toList();
      expect(files, hasLength(1));
      expect(await files.single.readAsBytes(), [1, 2, 3]);
      expect(await vault.list(), isEmpty);
      expect(await CaptureStore(vault).recover(), (
        recovered: 1,
        pending: 0,
        unnormalized: 1,
      ));
      expect(await vault.readAll((await vault.list()).single), [1, 2, 3]);
      expect(await pending.list(recursive: true).length, 0);
    },
  );

  test('iOS keeps its AAC recording without Android conversion', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('Android conversion on iOS'),
    );
    final saved = await ingestVideo(vault, source);
    expect(saved.castReady, isTrue);
    expect(await vault.readAll(saved.container), [1, 2, 3]);
  });
}
