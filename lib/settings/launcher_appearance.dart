import 'package:flutter/services.dart';

/// The optional plain launcher icon and name (decision 029). Android switches
/// between two launcher entries of the same app; platforms without the native
/// side report no support. This only reduces casual notice and hides nothing
/// from the package list or system settings.
class LauncherAppearance {
  const LauncherAppearance._();
  static const _channel = MethodChannel('quietake/appearance');

  /// Whether the plain entry is the active one, or null when unsupported.
  static Future<bool?> neutral() async {
    try {
      return await _channel.invokeMethod<bool>('neutral');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Switches the launcher entry; false when it could not be switched.
  static Future<bool> setNeutral(bool on) async {
    try {
      await _channel.invokeMethod<void>('setNeutral', on);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
