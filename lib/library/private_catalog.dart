import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../vault/file_name.dart';
import '../vault/vault.dart';

class CaptureDetails {
  const CaptureDetails({
    this.title = '',
    this.favorite = false,
    this.albums = const {},
  });
  final String title;
  final bool favorite;
  final Set<String> albums;
}

/// Authenticated metadata for one installation. References never delete media.
class PrivateCatalog extends ChangeNotifier {
  PrivateCatalog(this.vault);
  static const fileName = 'quietake.catalog';
  static const maxBytes = 1024 * 1024;
  final Vault vault;
  File get file => File('${vault.dir.path}/$fileName');
  Map<String, String> _albums = {};
  Map<String, CaptureDetails> _items = {};
  Map<String, String> get albums => UnmodifiableMapView(_albums);
  Map<String, CaptureDetails> get items => UnmodifiableMapView(_items);
  CaptureDetails details(String name) => _items[name] ?? const CaptureDetails();
  Future<void> _tail = Future.value();
  bool _loaded = false;
  bool _cleanedUploads = false;
  bool _closed = false;
  int _revision = 0;
  int get revision => _revision;
  bool get isLoaded => _loaded;

  Future<T> _serial<T>(Future<T> Function() action) {
    if (_closed) return Future.error(StateError('Catalog closed'));
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> load() => _serial(() async {
    await _read();
    notifyListeners();
  });

  Future<void> _ensure() async {
    if (!_loaded || !_cleanedUploads) await _read();
  }

  Future<void> _read() async {
    _loaded = false;
    // Once per catalog owner, before it creates any upload snapshot. Later
    // gallery reloads must leave this session's in-flight snapshot untouched.
    if (!_cleanedUploads) {
      await for (final entry in vault.dir.list()) {
        if (entry is Directory &&
            entry.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last
                .startsWith('.catalog-upload-')) {
          await entry.delete(recursive: true);
        }
      }
      _cleanedUploads = true;
    }
    final state = await file.exists()
        ? await _decode(file)
        : (<String, String>{}, <String, CaptureDetails>{});
    _albums = state.$1;
    _items = state.$2;
    _loaded = true;
  }

  Future<(Map<String, String>, Map<String, CaptureDetails>)> _decode(
    File source,
  ) async {
    final bytes = <int>[];
    await for (final chunk in vault.read(source)) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Catalog too large');
      }
      bytes.addAll(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['albums'] is! Map<String, dynamic> ||
        value['items'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported private library');
    }
    final albums = <String, String>{};
    for (final entry in (value['albums'] as Map<String, dynamic>).entries) {
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(entry.key) ||
          entry.value is! String) {
        throw const FormatException('Invalid album');
      }
      albums[entry.key] = _name(entry.value as String);
    }
    final items = <String, CaptureDetails>{};
    for (final entry in (value['items'] as Map<String, dynamic>).entries) {
      _mediaName(entry.key);
      final detail = entry.value;
      if (detail is! Map<String, dynamic> ||
          detail['title'] is! String ||
          detail['favorite'] is! bool ||
          detail['albums'] is! List) {
        throw const FormatException('Invalid capture metadata');
      }
      final memberships = <String>{};
      for (final id in detail['albums'] as List) {
        if (id is! String || !albums.containsKey(id)) {
          throw const FormatException('Unknown album');
        }
        memberships.add(id);
      }
      items[entry.key] = CaptureDetails(
        title: _name(detail['title'] as String, empty: true),
        favorite: detail['favorite'] as bool,
        albums: Set.unmodifiable(memberships),
      );
    }
    return (albums, items);
  }

  static String _name(String value, {bool empty = false}) {
    final name = value.trim();
    if ((!empty && name.isEmpty) || name.length > 120) {
      throw const FormatException('Use a name of 1–120 characters');
    }
    return name;
  }

  static void _mediaName(String name) {
    checkedFileName(name);
    if (!name.endsWith('.shtr')) {
      throw const FormatException('Expected capture name');
    }
  }

  Future<void> _save(
    Map<String, String> albums,
    Map<String, CaptureDetails> items,
  ) async {
    final bytes = utf8.encode(
      jsonEncode({
        'version': 1,
        'albums': albums,
        'items': {
          for (final entry in items.entries)
            entry.key: {
              'title': entry.value.title,
              'favorite': entry.value.favorite,
              'albums': entry.value.albums.toList()..sort(),
            },
        },
      }),
    );
    if (bytes.length > maxBytes) {
      throw const FormatException('Private library is full');
    }
    await vault.writeMetadata(file, bytes);
    _albums = albums;
    _items = items;
    _loaded = true;
    _revision++;
    notifyListeners();
  }

  Future<String> createAlbum(String name) => _serial(() async {
    await _ensure();
    final title = _name(name);
    if (_albums.values.any((n) => n.toLowerCase() == title.toLowerCase())) {
      throw const FormatException('A tag with this name already exists');
    }
    final id = vault.crypto.sodium.randombytes
        .buf(16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _save({..._albums, id: title}, {..._items});
    return id;
  });

  Future<void> renameAlbum(String id, String name) => _serial(() async {
    await _ensure();
    if (!_albums.containsKey(id)) {
      throw const FormatException('Tag no longer exists');
    }
    final title = _name(name);
    if (_albums.entries.any(
      (e) => e.key != id && e.value.toLowerCase() == title.toLowerCase(),
    )) {
      throw const FormatException('A tag with this name already exists');
    }
    await _save({..._albums, id: title}, {..._items});
  });

  Future<void> deleteAlbum(String id) => _serial(() async {
    await _ensure();
    final albums = {..._albums}..remove(id);
    final items = {
      for (final e in _items.entries)
        e.key: CaptureDetails(
          title: e.value.title,
          favorite: e.value.favorite,
          albums: Set.unmodifiable({...e.value.albums}..remove(id)),
        ),
    };
    await _save(albums, items);
  });

  Future<void> renameItem(String name, String title) => _serial(() async {
    await _ensure();
    _mediaName(name);
    final old = details(name);
    await _save(
      {..._albums},
      {
        ..._items,
        name: CaptureDetails(
          title: _name(title, empty: true),
          favorite: old.favorite,
          albums: old.albums,
        ),
      },
    );
  });

  Future<void> organize(
    Set<String> names, {
    bool? favorite,
    String? albumId,
    Set<String> tagIds = const {},
    bool remove = false,
  }) {
    final selectedNames = {...names};
    final selectedTags = {...tagIds, ?albumId};
    return _serial(() async {
      await _ensure();
      if (!selectedTags.every(_albums.containsKey)) {
        throw const FormatException(
          'A tag no longer exists. Choose tags again.',
        );
      }
      final items = {..._items};
      for (final name in selectedNames) {
        _mediaName(name);
        final old = details(name);
        final memberships = {...old.albums};
        if (remove) {
          memberships.removeAll(selectedTags);
        } else {
          memberships.addAll(selectedTags);
        }
        items[name] = CaptureDetails(
          title: old.title,
          favorite: favorite ?? old.favorite,
          albums: Set.unmodifiable(memberships),
        );
      }
      await _save({..._albums}, items);
    });
  }

  /// Schema-one album IDs remain the stable wire identity of reusable tags.
  Future<void> mergeTags(String source, String destination) =>
      _serial(() async {
        await _ensure();
        if (source == destination ||
            !_albums.containsKey(source) ||
            !_albums.containsKey(destination)) {
          throw const FormatException('Choose two different existing tags.');
        }
        final items = {
          for (final entry in _items.entries)
            entry.key: CaptureDetails(
              title: entry.value.title,
              favorite: entry.value.favorite,
              albums: Set.unmodifiable({
                for (final id in entry.value.albums)
                  if (id == source) destination else id,
              }),
            ),
        };
        await _save({..._albums}..remove(source), items);
      });

  /// Only the local deletion journal authorizes metadata cleanup.
  Future<void> forgetDeleted() => _serial(() async {
    await _ensure();
    final deleted = await vault.deletedNames();
    final items = {..._items}..removeWhere((name, _) => deleted.contains(name));
    if (items.length != _items.length) await _save({..._albums}, items);
  });

  /// Read-only authentication and schema validation for an incoming backup.
  Future<void> validate(File source) async {
    await _decode(source);
  }

  /// A nonempty backup needs a small encrypted ownership proof, even without edits.
  Future<void> ensurePersisted() => _serial(() async {
    await _ensure();
    if (!await file.exists()) await _save({..._albums}, {..._items});
  });

  /// An immutable encrypted snapshot; caller removes its temporary directory.
  Future<File?> snapshot() => _serial(() async {
    await _ensure();
    if (!await file.exists()) return null;
    final temp = await vault.dir.createTemp('.catalog-upload-');
    try {
      return await file.copy('${temp.path}/$fileName');
    } catch (_) {
      await temp.delete(recursive: true);
      rethrow;
    }
  });

  /// Only absence permits restore. Remote metadata never replaces local edits.
  Future<bool> restore(File incoming) => _serial(() async {
    if (await file.exists()) return false;
    final state = await _decode(incoming);
    await incoming.rename(file.path);
    _albums = state.$1;
    _items = state.$2;
    _loaded = true;
    notifyListeners();
    return true;
  });

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _tail;
    dispose();
  }
}
