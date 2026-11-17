import 'dart:math';

import '../vault/file_name.dart';

/// Maps a capture's local file name to the name its container has on the NAS.
///
/// A capture without an entry keeps its local name, so vaults that already
/// uploaded captures keep working. New captures can get a random name so the
/// NAS cannot read the capture time or media type from the file name.
class RemoteNames {
  RemoteNames._(this._remoteByLocal)
    : _localByRemote = {for (final e in _remoteByLocal.entries) e.value: e.key};
  const RemoteNames.empty()
    : _remoteByLocal = const {},
      _localByRemote = const {};

  final Map<String, String> _remoteByLocal;
  final Map<String, String> _localByRemote;

  bool get isEmpty => _remoteByLocal.isEmpty;

  String remoteFor(String local) => _remoteByLocal[local] ?? local;

  String localFor(String remote) => _localByRemote[remote] ?? remote;

  /// Returns a copy with a fresh random remote name for [local].
  RemoteNames assign(String local, Random random) {
    checkedFileName(local);
    if (_remoteByLocal.containsKey(local)) {
      throw StateError('Capture already has a remote name');
    }
    final taken = {..._remoteByLocal.values, ..._remoteByLocal.keys};
    String name;
    do {
      final hex = StringBuffer();
      for (var i = 0; i < 16; i++) {
        hex.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
      }
      name = '$hex.shtr';
    } while (taken.contains(name) || name == local);
    return RemoteNames._({..._remoteByLocal, local: name});
  }

  RemoteNames forget(String local) =>
      RemoteNames._({..._remoteByLocal}..remove(local));

  Map<String, String> toJson() => Map.of(_remoteByLocal);

  static RemoteNames fromJson(Object? json) {
    if (json == null) return const RemoteNames.empty();
    if (json is! Map) throw const FormatException('Expected a name mapping');
    final map = <String, String>{};
    for (final e in json.entries) {
      final local = e.key;
      final remote = e.value;
      if (local is! String || remote is! String) {
        throw const FormatException('Expected text names');
      }
      checkedFileName(local);
      checkedFileName(remote);
      if (!remote.endsWith('.shtr')) {
        throw const FormatException('Expected a container name');
      }
      map[local] = remote;
    }
    final remotes = map.values.toSet();
    if (remotes.length != map.length || map.keys.any(remotes.contains)) {
      throw const FormatException('Remote names must be unique');
    }
    return RemoteNames._(Map.unmodifiable(map));
  }
}
