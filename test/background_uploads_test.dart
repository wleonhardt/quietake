import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:quietake/sync/background_uploads.dart';
import 'package:quietake/sync/sync_settings.dart';

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
}
