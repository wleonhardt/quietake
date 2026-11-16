import 'package:flutter/services.dart';

/// Keeps the screen on while the slideshow runs. The native side sets the
/// platform flag only for the visible app window, and a failure is ignored: the
/// screen may then sleep, which is the normal behavior.
class KeepAwake {
  const KeepAwake._();
  static const _channel = MethodChannel('quietake/screen');

  static Future<void> set(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepAwake', on);
    } catch (_) {}
  }
}
