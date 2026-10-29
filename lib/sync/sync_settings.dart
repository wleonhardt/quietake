import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'webdav_client.dart';

/// WebDAV share settings, kept in the platform keystore.
class SyncSettings {
  const SyncSettings({
    required this.url,
    required this.username,
    required this.password,
    this.backgroundUploads = false,
    this.mobileData = false,
  });

  final String url;
  final String username;
  final String password;
  final bool backgroundUploads;
  final bool mobileData;

  /// Decision 039: an empty password would send `user:` Basic auth.
  bool get isConfigured =>
      url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  static const _store = FlutterSecureStorage();
  static const _kSettings = 'sync.settings';
  static const _kUrl = 'sync.url';
  static const _kUser = 'sync.username';
  static const _kPass = 'sync.password';

  static Future<SyncSettings> load() async {
    final saved = await _store.read(key: _kSettings);
    if (saved != null) {
      final value = jsonDecode(saved) as Map<String, dynamic>;
      return SyncSettings(
        url: value['url'] as String,
        username: value['username'] as String,
        password: value['password'] as String,
        backgroundUploads: value['backgroundUploads'] == true,
        mobileData: value['mobileData'] == true,
      );
    }
    return SyncSettings(
      url: await _store.read(key: _kUrl) ?? '',
      username: await _store.read(key: _kUser) ?? '',
      password: await _store.read(key: _kPass) ?? '',
    );
  }

  Future<void> save() => _store.write(
    key: _kSettings,
    value: jsonEncode({
      'url': url,
      'username': username,
      'password': password,
      'backgroundUploads': backgroundUploads,
      'mobileData': mobileData,
    }),
  );

  static Future<void> clear() async {
    // Publish the disconnected state before removing legacy fields, so a load
    // cannot fall back to partially erased credentials, even if cleanup fails.
    await const SyncSettings(url: '', username: '', password: '').save();
    for (final key in [_kUrl, _kUser, _kPass]) {
      await _store.delete(key: key);
    }
  }

  WebDavClient client() => WebDavClient(
    base: Uri.parse(url),
    username: username,
    password: password,
  );
}
