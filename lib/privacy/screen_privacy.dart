import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native covers stay up until the current scene has a fresh protected frame.
class ScreenPrivacy {
  ScreenPrivacy(this.onCaptured, {this.onBackground});
  final void Function(bool) onCaptured;
  final Future<void> Function()? onBackground;
  static const channel = MethodChannel('quietake/privacy');
  static ScreenPrivacy? _owner;
  int _generation = -1;
  int _attempt = 0;

  Future<void> start() async {
    _owner = this;
    channel.setMethodCallHandler((call) async {
      if (!identical(_owner, this)) return;
      if (call.method == 'userLeaving') {
        await onBackground?.call();
        return;
      }
      if (call.method != 'state') return;
      await _apply(Map<String, dynamic>.from(call.arguments as Map));
    });
    try {
      final state = await channel.invokeMapMethod<String, dynamic>('status');
      if (state != null) await _apply(state);
    } on MissingPluginException {
      // Host widget tests have no native application window.
    }
  }

  Future<void> _apply(Map<String, dynamic> state) async {
    final generation = state['generation'] as int? ?? 0;
    if (!identical(_owner, this) || generation < _generation) return;
    _generation = generation;
    final attempt = ++_attempt;
    if (state['backgrounded'] == true) {
      try {
        await onBackground?.call();
      } catch (_) {
        // The native cover still needs its acknowledgment below; the lock gate
        // itself is driven by the Dart lifecycle, not by this callback.
      }
    }
    if (!identical(_owner, this) || attempt != _attempt) return;
    onCaptured(state['captured'] == true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!identical(_owner, this) || attempt != _attempt) return;
      try {
        await channel.invokeMethod<void>('ready', generation);
      } on MissingPluginException {
        // Host widget tests have no native application window.
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void dispose() {
    if (identical(_owner, this)) {
      _owner = null;
      channel.setMethodCallHandler(null);
    }
  }
}
