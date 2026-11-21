import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// How many photos a press and hold of the shutter takes.
class BurstSetting {
  const BurstSetting._();
  static const choices = [3, 5, 10];
  static const standard = 5;
  static const _storage = FlutterSecureStorage();
  static const _key = 'camera.burstSize';

  /// An unreadable or unknown saved value gives [standard].
  static Future<int> load() async {
    try {
      final saved = int.tryParse(await _storage.read(key: _key) ?? '');
      return choices.contains(saved) ? saved! : standard;
    } catch (_) {
      return standard;
    }
  }

  static Future<void> save(int size) {
    if (!choices.contains(size)) throw ArgumentError.value(size, 'size');
    return _storage.write(key: _key, value: '$size');
  }
}
