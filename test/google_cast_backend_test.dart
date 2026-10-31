import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/cast/google_cast_backend.dart';

import '../test_support/cast_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const context = MethodChannel('google_cast.context');
  const discovery = MethodChannel('google_cast.discovery_manager');
  const sessions = MethodChannel('google_cast.session_manager');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var accepted = true;
  var requests = 0;

  Map<String, Object?> device(String id) => {
    'deviceID': id,
    'uniqueID': id,
    'friendlyName': 'Test TV',
    'modelName': 'Cast',
    'isOnLocalNetwork': true,
    'category': 'cast',
    'index': 0,
  };

  Future<void> event(MethodChannel channel, String method, Object? data) =>
      messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall(method, data)),
        (_) {},
      );

  Future<void> session(String id, GoogleCastConnectState state) =>
      event(sessions, 'onCurrentSessionChanged', {
        'device': device(id),
        'sessionID': 'session',
        'connectionState': state.index,
        'currentDeviceMuted': false,
        'currentDeviceVolume': 0.5,
      });

  Future<GoogleCastBackend> discovered() async {
    final backend = GoogleCastBackend();
    await backend.startDiscovery();
    await event(discovery, 'onDevicesChanged', [device('selected')]);
    await backend.devices.firstWhere((list) => list.isNotEmpty);
    return backend;
  }

  setUp(() async {
    accepted = true;
    requests = 0;
    messenger.setMockMethodCallHandler(context, (_) async => true);
    messenger.setMockMethodCallHandler(discovery, (_) async => null);
    messenger.setMockMethodCallHandler(sessions, (call) async {
      if (call.method == 'startSessionWithDevice') {
        requests++;
        return accepted;
      }
      return true;
    });
    // Initialize the plugin's native-event handler before sending events.
    await GoogleCastSessionManager.instance.currentSessionStream.first;
    await event(sessions, 'onCurrentSessionChanged', null);
  });

  tearDown(() {
    for (final channel in [context, discovery, sessions]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test('photo load sends only selected stream and title', () async {
    await checkCastLoadPayload('image/jpeg', 4);
  });
  test('video load sends only selected stream and title', () async {
    await checkCastLoadPayload('video/mp4', 1);
  });

  test(
    'accepted request waits for selected receiver to be connected',
    () async {
      final backend = await discovered();
      final selected = (await backend.devices.first).single;
      var connected = false;
      final pending = backend.connect(selected).then((_) => connected = true);
      await pumpEventQueue();
      expect(requests, 1);
      expect(
        connected,
        isFalse,
        reason: 'native acceptance is not a connection',
      );
      await session('other', GoogleCastConnectState.connected);
      await pumpEventQueue();
      expect(
        connected,
        isFalse,
        reason: 'a stale receiver cannot satisfy the request',
      );
      await session('selected', GoogleCastConnectState.connecting);
      await pumpEventQueue();
      expect(connected, isFalse);
      await session('selected', GoogleCastConnectState.connected);
      await pending;
      expect(connected, isTrue);
    },
  );

  test('rejected session request fails immediately', () async {
    final backend = await discovered();
    accepted = false;
    await expectLater(
      backend.connect((await backend.devices.first).single),
      throwsStateError,
    );
  });

  test(
    'loss of an established receiver emits once, initial connecting does not',
    () async {
      final backend = GoogleCastBackend();
      var ended = 0;
      final subscription = backend.disconnected.listen((_) {
        ended++;
      });
      try {
        await session('selected', GoogleCastConnectState.connecting);
        await pumpEventQueue();
        expect(ended, 0);
        await session('selected', GoogleCastConnectState.connected);
        await pumpEventQueue();
        expect(ended, 0);
        await session('selected', GoogleCastConnectState.connecting);
        await pumpEventQueue();
        expect(
          ended,
          1,
          reason: 'SDK resumption means the receiver is no longer connected',
        );
        await event(sessions, 'onCurrentSessionChanged', null);
        await pumpEventQueue();
        expect(ended, 1);
      } finally {
        await subscription.cancel();
      }
    },
  );

  test('disconnect cancels a pending connection immediately', () async {
    final backend = await discovered();
    final selected = (await backend.devices.first).single;
    var result = 'pending';
    final pending = backend
        .connect(selected)
        .then(
          (_) {
            result = 'connected';
          },
          onError: (Object _) {
            result = 'cancelled';
          },
        );
    try {
      await pumpEventQueue();
      await backend.disconnect();
      await pumpEventQueue();
      expect(result, 'cancelled');
    } finally {
      await session('selected', GoogleCastConnectState.connected);
      await pending;
    }
  });

  test('an accepted request without a connection has a deadline', () async {
    final backend = await discovered();
    final failure = expectLater(
      backend.connect((await backend.devices.first).single),
      throwsA(isA<TimeoutException>()),
    );
    await failure;
  }, timeout: const Timeout(Duration(seconds: 40)));
}
