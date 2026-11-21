import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Whether Delete first moves a capture to Recently deleted. On unless the owner
/// turns it off. An unreadable value counts as on, which is the safer default.
class TrashSetting {
  const TrashSetting._();
  static const _storage = FlutterSecureStorage();
  static const _key = 'trash.keep';

  static Future<bool> load() async {
    try {
      return await _storage.read(key: _key) != 'off';
    } catch (_) {
      return true;
    }
  }

  static Future<void> save(bool keep) =>
      _storage.write(key: _key, value: keep ? 'on' : 'off');
}
