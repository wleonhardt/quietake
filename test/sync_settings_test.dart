import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/sync/sync_settings.dart';

class _Storage extends FlutterSecureStoragePlatform {
  final values = <String, String>{};
  Completer<void>? wrote;
  Completer<void>? release;
  bool failWrite = false;
  String? failDelete;
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    if (key == failDelete) throw PlatformException(code: 'storage-unavailable');
    values.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    values.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(values);
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (failWrite) throw PlatformException(code: 'storage-unavailable');
    values[key] = value;
    if (wrote != null && !wrote!.isCompleted) {
      wrote!.complete();
      await release!.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  const old = SyncSettings(
    url: 'https://old.example/vault/',
    username: 'old-user',
    password: 'old-test-password',
  );
  const next = SyncSettings(
    url: 'https://new.example/vault/',
    username: 'new-user',
    password: 'new-test-password',
  );
  (String, String, String) values(SyncSettings settings) =>
      (settings.url, settings.username, settings.password);
  setUp(() {
    storage = _Storage();
    FlutterSecureStoragePlatform.instance = storage;
  });

  test(
    'saving new NAS settings never mixes credentials during automatic load',
    () async {
      await old.save();
      storage.wrote = Completer<void>();
      storage.release = Completer<void>();
      final saving = next.save();
      await storage.wrote!.future;
      final during = await SyncSettings.load();
      storage.release!.complete();
      await saving;
      expect(values(during), isIn([values(old), values(next)]));
      expect(values(await SyncSettings.load()), values(next));
    },
  );

  test(
    'legacy saved settings remain readable when an atomic update arrives',
    () async {
      storage.values.addAll({
        'sync.url': old.url,
        'sync.username': old.username,
        'sync.password': old.password,
      });
      expect(values(await SyncSettings.load()), values(old));
      await next.save();
      expect(values(await SyncSettings.load()), values(next));
    },
  );

  test(
    'failed settings write preserves the previous complete target',
    () async {
      await old.save();
      storage.failWrite = true;
      await expectLater(next.save(), throwsA(isA<PlatformException>()));
      expect(values(await SyncSettings.load()), values(old));
    },
  );

  test('unconfigured settings round trip without a network target', () async {
    storage.values.addAll({
      'sync.url': old.url,
      'sync.username': old.username,
      'sync.password': old.password,
    });
    await const SyncSettings(url: '', username: '', password: '').save();
    expect((await SyncSettings.load()).isConfigured, isFalse);
  });
  test(
    'disconnect erases both credential schemas and preserves unrelated keys',
    () async {
      storage.values.addAll({
        'sync.url': old.url,
        'sync.username': old.username,
        'sync.password': old.password,
        'unrelated': 'keep',
      });
      await next.save();
      await SyncSettings.clear();
      expect(values(await SyncSettings.load()), ('', '', ''));
      expect(storage.values.keys.toSet(), {'sync.settings', 'unrelated'});
      expect(storage.values['unrelated'], 'keep');
    },
  );

  test(
    'partial legacy cleanup cannot revive backup and can be retried',
    () async {
      storage.values.addAll({
        'sync.url': old.url,
        'sync.username': old.username,
        'sync.password': old.password,
      });
      storage.failDelete = 'sync.username';
      await expectLater(
        SyncSettings.clear(),
        throwsA(isA<PlatformException>()),
      );
      expect(values(await SyncSettings.load()), ('', '', ''));
      storage.failDelete = null;
      await SyncSettings.clear();
      expect(storage.values.keys, ['sync.settings']);
    },
  );

  test(
    'failed disconnect write reports failure and preserves the current target',
    () async {
      await old.save();
      storage.failWrite = true;
      await expectLater(
        SyncSettings.clear(),
        throwsA(isA<PlatformException>()),
      );
      expect(values(await SyncSettings.load()), values(old));
    },
  );
}
