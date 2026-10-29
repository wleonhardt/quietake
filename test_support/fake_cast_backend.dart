import 'dart:async';

import 'package:quietake/cast/cast_backend.dart';

/// Scripted Cast SDK for tests: devices appear on discovery, every call is
/// logged, and the test can fetch what the "receiver" was told to load.
class FakeCastBackend implements CastBackend {
  FakeCastBackend({
    this.available = const [CastDevice('tv-1', 'Living Room TV')],
  });

  final List<CastDevice> available;
  final _devices = StreamController<List<CastDevice>>.broadcast();
  final _disconnected = StreamController<void>.broadcast();
  @override
  Stream<void> get disconnected => _disconnected.stream;

  void endFromReceiver() {
    connected = null;
    _disconnected.add(null);
  }

  final log = <String>[];
  CastDevice? connected;
  Uri? loadedUrl;
  String? loadedType;
  bool failConnect = false;
  bool failDiscovery = false;
  bool _discovering = false;

  @override
  Stream<List<CastDevice>> get devices async* {
    if (_discovering) yield available;
    yield* _devices.stream;
  }

  @override
  Future<void> startDiscovery() async {
    log.add('startDiscovery');
    if (failDiscovery) throw StateError('discovery unavailable');
    _discovering = true;
    _devices.add(available);
  }

  @override
  Future<void> stopDiscovery() async {
    _discovering = false;
    log.add('stopDiscovery');
  }

  @override
  Future<void> connect(CastDevice device) async {
    log.add('connect ${device.id}');
    if (failConnect) throw StateError('receiver refused');
    connected = device;
  }

  @override
  Future<void> load(
    Uri url,
    String contentType, {
    required String title,
  }) async {
    log.add('load $contentType $title');
    loadedUrl = url;
    loadedType = contentType;
  }

  @override
  Future<void> disconnect() async {
    log.add('disconnect');
    connected = null;
    loadedUrl = null;
  }
}
