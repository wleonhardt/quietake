import 'dart:io';

import 'package:flutter/services.dart';

import '../vault/vault.dart';
import 'sync_settings.dart';

/// Android owns durable scheduling. No media key crosses this channel.
class BackgroundUploads {
  BackgroundUploads({bool? enabled}) : enabled = enabled ?? Platform.isAndroid;
  final bool enabled;
  static const channel = MethodChannel('quietake/background');
  String? _lease;

  Future<T> foreground<T>(Future<T> Function() operation) async {
    if (!enabled) return operation();
    final token = await channel.invokeMethod<String>('begin');
    if (token == null) throw StateError('Background lease unavailable');
    _lease = token;
    var failed = false;
    try {
      return await operation();
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      _lease = null;
      try {
        await channel.invokeMethod<void>('end', {'lease': token});
      } catch (_) {
        // The operation's own error is the one worth reporting.
        if (!failed) rethrow;
      }
    }
  }

  Future<void> configure(
    SyncSettings settings,
    Vault vault,
    String? proof,
    Set<String> confirmedMedia,
  ) async {
    if (!enabled || !settings.backgroundUploads || proof == null) return;
    await channel.invokeMethod<void>('configure', {
      'lease': _lease,
      'config': {
        'url': settings.url,
        'username': settings.username,
        'password': settings.password,
        'vault': vault.dir.path,
        'keyfile': '${vault.dir.parent.path}/vault.keyfile.json',
        'ownership': proof,
        'mobileData': settings.mobileData,
        'confirmed': confirmedMedia.take(100000).toList(),
      },
    });
  }

  Future<void> reset() async {
    if (enabled) await channel.invokeMethod<void>('reset');
  }

  Future<void> request() async {
    if (!enabled) return;
    try {
      await channel.invokeMethod<void>('request');
    } on PlatformException {
      // Foreground authentication/configuration can repair stale native state.
    }
  }

  Future<String> status() async => enabled
      ? await channel.invokeMethod<String>('status') ?? 'disabled'
      : 'disabled';
}
