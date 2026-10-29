import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session UI locking; vault keys and active Cast sessions keep their owners.
class PrivacyController extends ChangeNotifier {
  PrivacyController({required this.onLock, this.timeoutOverride});
  final VoidCallback onLock;
  @visibleForTesting
  final Duration? timeoutOverride;
  static const choices = [0, 1, 5, 15];
  static const _storage = FlutterSecureStorage();
  static const _key = 'privacy.idleMinutes';
  final _holds = <Object>{};
  Timer? _timer;
  int minutes = 5;
  bool enabled = false;
  bool _disposed = false;

  Future<void> load() async {
    final saved = int.tryParse(await _storage.read(key: _key) ?? '');
    if (_disposed) return;
    if (choices.contains(saved)) minutes = saved!;
    activity();
    notifyListeners();
  }

  Future<void> setMinutes(int value) async {
    if (!choices.contains(value)) throw ArgumentError.value(value, 'minutes');
    await _storage.write(key: _key, value: '$value');
    if (_disposed) return;
    minutes = value;
    activity();
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_disposed || enabled == value) return;
    enabled = value;
    activity();
    notifyListeners();
  }

  void activity() {
    _timer?.cancel();
    if (!_disposed && enabled && minutes > 0 && _holds.isEmpty) {
      _timer = Timer(timeoutOverride ?? Duration(minutes: minutes), lock);
    }
  }

  void hold(Object owner, bool active) {
    final changed = active ? _holds.add(owner) : _holds.remove(owner);
    if (changed) activity();
  }

  void lock() {
    if (!enabled || _disposed) return;
    setEnabled(false);
    onLock();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _holds.clear();
    super.dispose();
  }
}
