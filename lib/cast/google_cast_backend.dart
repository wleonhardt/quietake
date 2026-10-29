import 'dart:async';
import 'dart:io';

import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/models.dart';
import 'package:flutter_chrome_cast/session.dart';

import 'cast_backend.dart';

/// Google Cast SDK via flutter_chrome_cast, Default Media Receiver.
///
/// The SDK is initialised lazily on the first cast action, never at app
/// start: on the OnePlus 13 `setSharedInstanceWithOptions` blocked the UI
/// thread indefinitely when awaited from `main()` (2026-10-17), and the
/// camera must not depend on Play services being happy.
class GoogleCastBackend implements CastBackend {
  GoogleCastBackend();

  Future<void>? _init;
  Completer<bool>? _connection;
  final _devicesById = <String, GoogleCastDevice>{};

  Future<void> _ensureInit() => _init ??= () async {
        const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
        final GoogleCastOptions options = Platform.isIOS
            ? IOSGoogleCastOptions(
                GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
                stopCastingOnAppTerminated: true,
              )
            : GoogleCastOptionsAndroid(appId: appId, stopCastingOnAppTerminated: true);
        try {
          await GoogleCastContext.instance
              .setSharedInstanceWithOptions(options)
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          _init = null; // allow a retry on the next cast action
          throw StateError('Cast SDK did not start: $e');
        }
      }();

  @override
  Stream<List<CastDevice>> get devices =>
      GoogleCastDiscoveryManager.instance.devicesStream.map((list) {
        _devicesById
          ..clear()
          ..addEntries(list.map((d) => MapEntry(d.uniqueID, d)));
        return [for (final d in list) CastDevice(d.uniqueID, d.friendlyName)];
      });

  @override
  Stream<void> get disconnected => GoogleCastSessionManager.instance.currentSessionStream
      .map((s) => s?.connectionState == GoogleCastConnectState.connected)
      .distinct()
      .skipWhile((active) => !active)
      .where((active) => !active)
      .map((_) {});

  @override
  Future<void> startDiscovery() async {
    await _ensureInit();
    await GoogleCastDiscoveryManager.instance.startDiscovery();
  }

  @override
  Future<void> stopDiscovery() => GoogleCastDiscoveryManager.instance.stopDiscovery();

  @override
  Future<void> connect(CastDevice device) async {
    await _ensureInit();
    final d = _devicesById[device.id];
    if (d == null) throw StateError('device ${device.name} no longer visible');
    // Native acceptance only starts route selection; media needs a connected session.
    final ready = _connection = Completer<bool>();
    final subscription = GoogleCastSessionManager.instance.currentSessionStream.listen((session) {
      if (!ready.isCompleted && session?.connectionState == GoogleCastConnectState.connected &&
          session?.device?.uniqueID == device.id) {
        ready.complete(true);
      }
    });
    try {
      final ok = await GoogleCastSessionManager.instance.startSessionWithDevice(d);
      if (!ok) throw StateError('could not start a session with ${device.name}');
      if (!await ready.future.timeout(const Duration(seconds: 30))) {
        throw StateError('Cast connection cancelled');
      }
    } finally {
      if (identical(_connection, ready)) _connection = null;
      await subscription.cancel();
    }
  }

  @override
  Future<void> load(Uri url, String contentType, {required String title}) =>
      GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformation(
          contentId: url.pathSegments.last,
          streamType: CastMediaStreamType.buffered,
          contentUrl: url,
          contentType: contentType,
          metadata: contentType.startsWith('image/')
              ? GoogleCastPhotoMediaMetadata(title: title)
              : GoogleCastMovieMediaMetadata(title: title),
        ),
      );

  @override
  Future<void> disconnect() async {
    final pending = _connection;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }
}
