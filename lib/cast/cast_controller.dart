import 'dart:async';

import 'package:flutter/foundation.dart';

import '../gallery/item.dart';
import '../media/media_server.dart';
import '../vault/vault.dart';
import 'cast_backend.dart';

/// Owns the receiver connection and its session-scoped LAN media server.
class CastController extends ChangeNotifier {
  CastController(
    this.vault,
    this.backend, {
    this.loadTimeout = const Duration(seconds: 30),
  });

  final Vault vault;
  final CastBackend backend;

  /// A receiver that never answers a load must not leave the viewer waiting.
  final Duration loadTimeout;
  MediaServer? _server;
  CastDevice? _device;
  String? _error;
  Uri? _lastUrl;
  StreamSubscription<void>? _ended;
  int _generation = 0;
  int _shown = 0;
  bool _connecting = false;
  Future<void>? _stopping;
  bool _disposed = false;

  bool get isCasting => _device != null;
  bool get isConnecting => _connecting;
  CastDevice? get device => _device;
  String? get error => _error;
  Uri? get lastUrl => _lastUrl;
  Stream<List<CastDevice>> get devices => backend.devices;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Discovery failures belong to the picker; [error] only reports cast attempts.
  Future<bool> startDiscovery() async {
    try {
      await backend.startDiscovery();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopDiscovery() => backend.stopDiscovery();

  Future<void> start(CastDevice device, VaultItem? item) async {
    if (_connecting || _stopping != null || isCasting || _disposed) return;
    _connecting = true;
    _error = null;
    final generation = ++_generation;
    _changed();
    try {
      final lan = await MediaServer.lanAddress();
      if (generation != _generation) return;
      if (lan == null) throw StateError('Connect to Wi-Fi to cast');
      _ended ??= backend.disconnected.listen((_) {
        stop();
      });
      await backend.connect(device);
      if (generation != _generation) {
        await backend.disconnect();
        return;
      }
      // The LAN server exists only once a receiver is actually connected.
      final server = await MediaServer.start(vault, lanAddress: lan);
      if (generation != _generation) {
        await server.close();
        await backend.disconnect();
        return;
      }
      _server = server;
      _device = device;
      _changed();
      if (item != null) await show(item);
    } catch (e) {
      if (generation == _generation) {
        _error = e.toString();
        await stop();
      }
    } finally {
      _connecting = false;
      _changed();
    }
  }

  Future<void> show(VaultItem item) async {
    final server = _server;
    if (server == null || _device == null) return;
    final shown = ++_shown;
    server.revokeAll();
    final url = server.register(item.file);
    _lastUrl = url;
    try {
      await backend
          .load(url, item.contentType, title: item.name)
          .timeout(loadTimeout);
      if (shown == _shown) _error = null;
    } catch (e) {
      if (shown == _shown) _error = e.toString();
    }
    _changed();
  }

  /// Concurrent callers share one teardown, so a delete that follows a stop
  /// never runs while the receiver can still fetch the file.
  Future<void> stop() =>
      _stopping ??= _stop().whenComplete(() => _stopping = null);

  Future<void> _stop() async {
    ++_generation;
    ++_shown;
    final server = _server;
    _server = null;
    _device = null;
    _lastUrl = null;
    _changed();
    try {
      await server?.close();
      await backend.disconnect();
    } catch (_) {
      // The receiver may already have ended the session.
    } finally {
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    ++_shown;
    _ended?.cancel();
    _server?.close();
    super.dispose();
  }
}
