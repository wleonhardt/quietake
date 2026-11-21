import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/sync/background_uploads.dart';
import 'package:quietake/sync/sync_settings.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('foreground lease is released after failure', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundUploads.channel, (call) async {
          calls.add(call.method);
          return call.method == 'begin' ? 'lease-fixture' : null;
        });
    final background = BackgroundUploads(enabled: true);
    await expectLater(
      background.foreground<void>(() async {
        throw StateError('synthetic failure');
      }),
      throwsStateError,
    );
    expect(calls, ['begin', 'end']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundUploads.channel, null);
  });

  test('a failing end keeps the operation error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundUploads.channel, (call) async {
          if (call.method == 'end') throw PlatformException(code: 'gate');
          return call.method == 'begin' ? 'lease-fixture' : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BackgroundUploads.channel, null),
    );
    final background = BackgroundUploads(enabled: true);
    await expectLater(
      background.foreground<void>(() async => throw StateError('transfer')),
      throwsStateError,
    );
    await expectLater(
      background.foreground<int>(() async => 1),
      throwsA(isA<PlatformException>()),
    );
  });

  test('old saved settings leave background work disabled', () {
    const settings = SyncSettings(
      url: 'https://example.com/vault/',
      username: 'fixture',
      password: 'synthetic',
    );
    expect(settings.backgroundUploads, isFalse);
    expect(settings.mobileData, isFalse);
    expect(settings.isConfigured, isTrue);
    expect(
      const SyncSettings(
        url: 'https://example.com/vault/',
        username: 'fixture',
        password: '',
      ).isConfigured,
      isFalse,
      reason: 'decision 039: never send user: Basic auth by accident',
    );
  });

  test(
    'scheduler repair failure still allows authenticated foreground work',
    () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(BackgroundUploads.channel, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'request') {
          throw PlatformException(code: 'background');
        }
        return call.method == 'begin' ? 'lease-fixture' : null;
      });
      try {
        final background = BackgroundUploads(enabled: true);
        await background.request();
        expect(await background.foreground(() async => 7), 7);
        expect(calls, ['request', 'begin', 'end']);
      } finally {
        messenger.setMockMethodCallHandler(BackgroundUploads.channel, null);
      }
    },
  );

  group('native scheduler channel', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late Vault vault;
    late Directory root;
    Object? status;

    setUp(() async {
      calls = [];
      status = 'scheduled';
      messenger.setMockMethodCallHandler(BackgroundUploads.channel, (
        call,
      ) async {
        calls.add(call);
        return switch (call.method) {
          'begin' => 'lease-fixture',
          'status' => status,
          _ => null,
        };
      });
      final sodium = await SodiumSumoInit.init();
      root = await Directory.systemTemp.createTemp('quietake-background');
      vault = Vault(
        VaultCrypto(sodium),
        sodium.crypto.secretBox.keygen(),
        Directory('${root.path}/vault')..createSync(),
      );
    });
    tearDown(() async {
      messenger.setMockMethodCallHandler(BackgroundUploads.channel, null);
      vault.dispose();
      await root.delete(recursive: true);
    });

    const settings = SyncSettings(
      url: 'https://nas.example/vault/',
      username: 'fixture',
      password: 'synthetic',
      backgroundUploads: true,
      mobileData: true,
    );

    test('disabled uploads never touch the channel', () async {
      final background = BackgroundUploads(enabled: false);
      expect(await background.foreground(() async => 3), 3);
      await background.configure(settings, vault, 'proof', {'a'});
      await background.reset();
      await background.request();
      expect(await background.status(), 'disabled');
      expect(calls, isEmpty);
    });

    test('mapped names reach the channel only when given', () async {
      final seen = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(BackgroundUploads.channel, (
        call,
      ) async {
        if (call.method == 'begin') return 'lease';
        if (call.method == 'configure') {
          seen.add((call.arguments as Map)['config'] as Map<Object?, Object?>);
        }
        return null;
      });
      final background = BackgroundUploads(enabled: true);
      await background.foreground(() async {
        await background.configure(settings, vault, 'proof', {'a'});
        await background.configure(
          settings,
          vault,
          'proof',
          {'a'},
          remoteNames: {'b.shtr': '0123456789abcdef0123456789abcdef.shtr'},
        );
      });
      expect(seen.first.containsKey('remoteNames'), isFalse);
      expect(seen.last['remoteNames'], {
        'b.shtr': '0123456789abcdef0123456789abcdef.shtr',
      });
    });

    test('a missing lease stops foreground work before it starts', () async {
      messenger.setMockMethodCallHandler(
        BackgroundUploads.channel,
        (_) async => null,
      );
      var ran = false;
      await expectLater(
        BackgroundUploads(enabled: true).foreground(() async => ran = true),
        throwsStateError,
      );
      expect(ran, isFalse);
    });

    test(
      'configure sends the lease, paths and confirmed media, no key',
      () async {
        final background = BackgroundUploads(enabled: true);
        await background.foreground(
          () => background.configure(settings, vault, 'proof', {'a', 'b'}),
        );
        final sent =
            calls.singleWhere((c) => c.method == 'configure').arguments as Map;
        expect(sent['lease'], 'lease-fixture');
        final config = sent['config'] as Map;
        expect(config['url'], settings.url);
        expect(config['ownership'], 'proof');
        expect(config['mobileData'], isTrue);
        expect(config['vault'], vault.dir.path);
        expect(config['keyfile'], '${root.path}/vault.keyfile.json');
        expect(config['confirmed'], unorderedEquals(['a', 'b']));
        expect(
          config.keys,
          isNot(anyOf(contains('key'), contains('masterKey'))),
          reason: 'no media key crosses this channel',
        );
      },
    );

    test(
      'configure is skipped without proof or when the user opted out',
      () async {
        final background = BackgroundUploads(enabled: true);
        await background.configure(settings, vault, null, {'a'});
        await background.configure(
          const SyncSettings(
            url: 'https://nas.example/vault/',
            username: 'fixture',
            password: 'synthetic',
          ),
          vault,
          'proof',
          {'a'},
        );
        expect(calls, isEmpty);
      },
    );

    test('at most 100000 confirmed names are sent', () async {
      final background = BackgroundUploads(enabled: true);
      await background.configure(settings, vault, 'proof', {
        for (var i = 0; i < 100001; i++) 'n$i',
      });
      final config = (calls.single.arguments as Map)['config'] as Map;
      expect(config['confirmed'], hasLength(100000));
    });

    test(
      'reset and status reach the platform; status defaults to disabled',
      () async {
        final background = BackgroundUploads(enabled: true);
        await background.reset();
        expect(await background.status(), 'scheduled');
        status = null;
        expect(await background.status(), 'disabled');
        expect(calls.map((c) => c.method), ['reset', 'status', 'status']);
      },
    );
  });
}
