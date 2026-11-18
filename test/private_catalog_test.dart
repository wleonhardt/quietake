import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Vault vault;
  late Directory dir;
  late PrivateCatalog catalog;
  late SecureKey masterKey;
  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    dir = await Directory.systemTemp.createTemp('private-catalog-');
    masterKey = crypto.generateMasterKey();
    vault = Vault(crypto, masterKey, dir);
    catalog = vault.catalog;
  });
  tearDown(() async {
    await catalog.close();
    vault.dispose();
    await dir.delete(recursive: true);
  });

  test(
    'metadata is authenticated, private, atomic, and survives reopen',
    () async {
      await catalog.load();
      expect(await catalog.file.exists(), isFalse);
      final album = await catalog.createAlbum('Hidden holiday');
      await catalog.organize({'one.jpg.shtr'}, favorite: true, albumId: album);
      await catalog.renameItem('one.jpg.shtr', 'Evening light');
      final encrypted = await catalog.file.readAsBytes();
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('Hidden holiday')),
      );
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('Evening light')),
      );
      expect(await vault.list(), isEmpty, reason: 'Catalog is not media');
      final reopened = PrivateCatalog(vault);
      await reopened.load();
      expect(reopened.details('one.jpg.shtr').favorite, isTrue);
      expect(reopened.details('one.jpg.shtr').title, 'Evening light');
      expect(reopened.details('one.jpg.shtr').albums, {album});
      expect(reopened.albums[album], 'Hidden holiday');
      await reopened.close();
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), [
        'quietake.catalog',
      ]);
    },
  );

  test(
    'queued edits preserve other changes; album removal keeps media',
    () async {
      final media = await File('${dir.path}/one.jpg.shtr').writeAsBytes([1]);
      final album = await catalog.createAlbum('First');
      await Future.wait([
        catalog.organize({'one.jpg.shtr'}, favorite: true),
        catalog.organize({'one.jpg.shtr'}, albumId: album),
        catalog.renameItem('one.jpg.shtr', 'A title'),
      ]);
      expect(catalog.details('one.jpg.shtr').favorite, isTrue);
      expect(catalog.details('one.jpg.shtr').title, 'A title');
      expect(catalog.details('one.jpg.shtr').albums, {album});
      await catalog.renameAlbum(album, 'Second');
      await catalog.deleteAlbum(album);
      expect(catalog.details('one.jpg.shtr').albums, isEmpty);
      expect(catalog.details('one.jpg.shtr').favorite, isTrue);
      expect(await media.exists(), isTrue);
      expect(await vault.deletedNames(), isEmpty);
    },
  );

  test(
    'multiple album memberships and bulk favorite removal remain independent',
    () async {
      final first = await catalog.createAlbum('First');
      final second = await catalog.createAlbum('Second');
      await catalog.organize(
        {'one.jpg.shtr', 'two.mp4.shtr'},
        favorite: true,
        albumId: first,
      );
      await catalog.organize({'one.jpg.shtr'}, albumId: second);
      await catalog.organize(
        {'one.jpg.shtr'},
        favorite: false,
        albumId: first,
        remove: true,
      );
      await catalog.renameItem('one.jpg.shtr', '  ');
      expect(catalog.details('one.jpg.shtr').favorite, isFalse);
      expect(catalog.details('one.jpg.shtr').title, '');
      expect(catalog.details('one.jpg.shtr').albums, {second});
      expect(catalog.details('two.mp4.shtr').favorite, isTrue);
      expect(catalog.details('two.mp4.shtr').albums, {first});
      expect(
        await vault.list(),
        isEmpty,
        reason: 'Membership does not create media copies',
      );
    },
  );

  test('duplicate album names fail without changing committed bytes', () async {
    final first = await catalog.createAlbum('First');
    final second = await catalog.createAlbum('Second');
    final before = await catalog.file.readAsBytes();
    await expectLater(catalog.createAlbum(' FIRST '), throwsFormatException);
    await expectLater(
      catalog.renameAlbum(second, 'first'),
      throwsFormatException,
    );
    expect(await catalog.file.readAsBytes(), before);
    await catalog.renameAlbum(first, 'FIRST');
    expect(catalog.albums[first], 'FIRST');
  });

  test(
    'atomic tag batches preserve schema-one identities and unrelated metadata',
    () async {
      final subject = await catalog.createAlbum('Alex');
      final action = await catalog.createAlbum('Running outdoors');
      final other = await catalog.createAlbum('Field notes');
      await catalog.organize({'one.jpg.shtr'}, favorite: true, albumId: other);
      await catalog.renameItem('one.jpg.shtr', 'Original title');
      final revision = catalog.revision;
      await catalog.organize(
        {'one.jpg.shtr', 'two.mp4.shtr'},
        tagIds: {subject, action},
      );
      expect(catalog.revision, revision + 1);
      expect(catalog.details('one.jpg.shtr').albums, {subject, action, other});
      await catalog.organize(
        {'one.jpg.shtr'},
        tagIds: {subject, action},
        remove: true,
      );
      expect(catalog.details('one.jpg.shtr').albums, {other});
      expect(catalog.details('one.jpg.shtr').title, 'Original title');
      expect(catalog.details('one.jpg.shtr').favorite, isTrue);
      final decoded =
          jsonDecode(utf8.decode(await vault.readAll(catalog.file))) as Map;
      expect(decoded['version'], 1);
      expect(decoded['albums'], {
        subject: 'Alex',
        action: 'Running outdoors',
        other: 'Field notes',
      });
      final reopened = PrivateCatalog(vault);
      await reopened.load();
      expect(reopened.details('two.mp4.shtr').albums, {subject, action});
      await reopened.close();
    },
  );

  test('merge unions memberships including pending references without deleting media', () async {
    final source = await catalog.createAlbum('Running');
    final target = await catalog.createAlbum('Run');
    final other = await catalog.createAlbum('Alex');
    final media = await File('${dir.path}/one.jpg.shtr').writeAsBytes([7]);
    await catalog.organize(
      {'one.jpg.shtr'},
      tagIds: {source, target, other},
      favorite: true,
    );
    await catalog.organize({'pending.mp4.shtr'}, tagIds: {source});
    final revision = catalog.revision;
    await catalog.mergeTags(source, target);
    expect(catalog.revision, revision + 1);
    expect(catalog.albums, {target: 'Run', other: 'Alex'});
    expect(catalog.details('one.jpg.shtr').albums, {target, other});
    expect(catalog.details('pending.mp4.shtr').albums, {target});
    expect(catalog.details('one.jpg.shtr').favorite, isTrue);
    expect(await media.readAsBytes(), [7]);
    expect(await vault.deletedNames(), isEmpty);
    final before = await catalog.file.readAsBytes();
    await expectLater(
      catalog.organize({'one.jpg.shtr'}, tagIds: {source, other}),
      throwsFormatException,
    );
    await expectLater(catalog.mergeTags(target, target), throwsFormatException);
    await expectLater(
      catalog.mergeTags('missing', target),
      throwsFormatException,
    );
    expect(await catalog.file.readAsBytes(), before);
  });

  test(
    'failed tag batch and merge retain complete prior state for retry',
    () async {
      final source = await catalog.createAlbum('Source');
      final target = await catalog.createAlbum('Target');
      await catalog.organize({'one.jpg.shtr'}, tagIds: {source});
      final before = await catalog.file.readAsBytes();
      await Directory('${catalog.file.path}.part').create();
      await expectLater(
        catalog.organize({'one.jpg.shtr', 'two.mp4.shtr'}, tagIds: {target}),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        catalog.mergeTags(source, target),
        throwsA(isA<FileSystemException>()),
      );
      expect(catalog.albums.keys, containsAll([source, target]));
      expect(catalog.details('one.jpg.shtr').albums, {source});
      expect(catalog.details('two.mp4.shtr').albums, isEmpty);
      expect(await catalog.file.readAsBytes(), before);
      await Directory('${catalog.file.path}.part').delete();
      await catalog.mergeTags(source, target);
      await catalog.load();
      expect(catalog.details('one.jpg.shtr').albums, {target});
    },
  );

  test(
    'queued tag edits snapshot caller sets and reject stale tags atomically',
    () async {
      final tag = await catalog.createAlbum('Tag');
      final names = {'one.jpg.shtr'};
      final tags = {tag};
      final update = catalog.organize(names, tagIds: tags);
      names.add('two.mp4.shtr');
      tags.clear();
      await update;
      expect(catalog.details('one.jpg.shtr').albums, {tag});
      expect(catalog.details('two.mp4.shtr').albums, isEmpty);
      final deleted = catalog.deleteAlbum(tag);
      final stale = catalog.organize({'three.jpg.shtr'}, tagIds: {tag});
      await deleted;
      await expectLater(stale, throwsFormatException);
      expect(catalog.details('three.jpg.shtr').albums, isEmpty);
    },
  );

  test(
    'rejects corrupt/unknown schema and preserves committed bytes',
    () async {
      await vault.writeMetadata(catalog.file, utf8.encode('{"version":99}'));
      final before = await catalog.file.readAsBytes();
      await expectLater(catalog.load(), throwsFormatException);
      await expectLater(
        catalog.createAlbum('Never overwrite'),
        throwsFormatException,
      );
      expect(await catalog.file.readAsBytes(), before);
      await catalog.file.writeAsBytes([1, 2, 3]);
      await expectLater(catalog.load(), throwsA(anything));
      expect(await catalog.file.readAsBytes(), [1, 2, 3]);
    },
  );

  test('failed reload blocks writes after a previously valid load', () async {
    await catalog.createAlbum('Previously valid');
    await catalog.file.writeAsBytes([1, 2, 3]);
    await expectLater(catalog.load(), throwsA(anything));
    await expectLater(
      catalog.createAlbum('Must not replace corruption'),
      throwsA(anything),
    );
    expect(await catalog.file.readAsBytes(), [1, 2, 3]);
  });

  test(
    'invalid names and missing albums do not change committed state',
    () async {
      final album = await catalog.createAlbum('First');
      final before = await catalog.file.readAsBytes();
      await expectLater(catalog.createAlbum('  '), throwsFormatException);
      await expectLater(
        catalog.organize({'../escape.shtr'}, favorite: true),
        throwsFormatException,
      );
      await expectLater(
        catalog.organize({'one.jpg.shtr'}, albumId: 'missing'),
        throwsFormatException,
      );
      expect(await catalog.file.readAsBytes(), before);
      expect(catalog.albums, {album: 'First'});
    },
  );

  test(
    'failed atomic replacement preserves prior state and permits retry',
    () async {
      await catalog.createAlbum('Saved');
      await Directory('${catalog.file.path}.part').create();
      await expectLater(
        catalog.createAlbum('Not saved'),
        throwsA(isA<FileSystemException>()),
      );
      expect(catalog.albums.values, ['Saved']);
      await Directory('${catalog.file.path}.part').delete();
      await catalog.createAlbum('Retry');
      final reopened = PrivateCatalog(vault);
      await reopened.load();
      expect(reopened.albums.values, ['Saved', 'Retry']);
      await reopened.close();
    },
  );

  test(
    'reopen clears abandoned encrypted uploads but preserves live snapshot',
    () async {
      await catalog.createAlbum('Saved');
      final abandoned = await dir.createTemp('.catalog-upload-');
      await catalog.file.copy('${abandoned.path}/quietake.catalog');
      final reopened = PrivateCatalog(vault);
      await reopened.load();
      expect(await abandoned.exists(), isFalse);
      expect(reopened.albums.values, ['Saved']);
      final snapshot = await reopened.snapshot();
      await reopened.load();
      expect(await snapshot!.exists(), isTrue);
      await snapshot.parent.delete(recursive: true);
      await reopened.close();
    },
  );

  test('backup snapshot remains immutable while local edits commit', () async {
    await catalog.createAlbum('Before');
    final snapshot = await catalog.snapshot();
    await catalog.createAlbum('After');
    final restored = PrivateCatalog(vault);
    final bytes = await vault.readAll(snapshot!);
    expect(utf8.decode(bytes), contains('Before'));
    expect(utf8.decode(bytes), isNot(contains('After')));
    await snapshot.parent.delete(recursive: true);
    await restored.close();
  });

  test(
    'remote adoption authenticates and never replaces local edits',
    () async {
      final incoming = File('${dir.path}/incoming');
      await vault.writeMetadata(
        incoming,
        utf8.encode('{"version":1,"albums":{"remote":"Restored"},"items":{}}'),
      );
      expect(await catalog.restore(incoming), isTrue);
      expect(catalog.albums, {'remote': 'Restored'});
      final before = await catalog.file.readAsBytes();
      await incoming.writeAsBytes([1, 2]);
      expect(await catalog.restore(incoming), isFalse);
      expect(await catalog.file.readAsBytes(), before);
    },
  );

  test('wrong-key and oversized manifests cannot be adopted', () async {
    final incoming = File('${dir.path}/incoming');
    final other = Vault(vault.crypto, vault.crypto.generateMasterKey(), dir);
    await other.writeMetadata(
      incoming,
      utf8.encode('{"version":1,"albums":{},"items":{}}'),
    );
    other.dispose();
    await expectLater(catalog.restore(incoming), throwsA(anything));
    expect(await catalog.file.exists(), isFalse);
    await vault.writeMetadata(
      incoming,
      List.filled(PrivateCatalog.maxBytes + 1, 32),
    );
    await expectLater(catalog.restore(incoming), throwsFormatException);
    expect(await catalog.file.exists(), isFalse);
  });

  test('damaged remote manifest cannot become authoritative', () async {
    final incoming = await File('${dir.path}/incoming').writeAsBytes([1, 2]);
    await expectLater(catalog.restore(incoming), throwsA(anything));
    expect(await catalog.file.exists(), isFalse);
    await catalog.createAlbum('Local remains usable');
    expect(catalog.albums.values, ['Local remains usable']);
  });

  test(
    'a library too large to save is refused and leaves state unchanged',
    () async {
      await catalog.load();
      // Enough long names to pass the size limit, whatever it is.
      final names = {
        for (var i = 0; i < PrivateCatalog.maxBytes ~/ 200; i++)
          'capture-${'x' * 200}-$i.shtr',
      };
      await expectLater(
        catalog.organize(names, favorite: true),
        throwsA(isA<FormatException>()),
      );
      expect(catalog.items, isEmpty);
      expect(await catalog.file.exists(), isFalse);
    },
  );

  test('a catalog larger than the size limit is refused on load', () async {
    final padding = 'x' * (PrivateCatalog.maxBytes + 1);
    await vault.writeMetadata(
      catalog.file,
      utf8.encode(
        jsonEncode({'version': 1, 'albums': {}, 'items': {}, 'pad': padding}),
      ),
    );
    await expectLater(
      PrivateCatalog(vault).load(),
      throwsA(isA<FormatException>()),
    );
  });

  test('edits naming a deleted tag are refused and change nothing', () async {
    await catalog.load();
    final tag = await catalog.createAlbum('Gone');
    await catalog.deleteAlbum(tag);
    await expectLater(catalog.renameAlbum(tag, 'Back'), throwsFormatException);
    await expectLater(
      catalog.organize({'one.jpg.shtr'}, albumId: tag),
      throwsFormatException,
    );
    expect(catalog.albums, isEmpty);
    expect(catalog.items, isEmpty);
  });

  group('tag covers', () {
    const cover = 'one.jpg.shtr';

    test(
      'a cover survives reopen and a file without covers still loads',
      () async {
        await catalog.load();
        final tag = await catalog.createAlbum('Trips');
        expect(catalog.covers, isEmpty);
        final plain = jsonDecode(
          utf8.decode(await _plain(vault, catalog.file)),
        );
        expect(plain.containsKey('covers'), isFalse);

        await catalog.setCover(tag, cover);
        final reopened = PrivateCatalog(vault);
        await reopened.load();
        expect(reopened.covers, {tag: cover});
        await reopened.close();

        await catalog.setCover(tag, null);
        expect(catalog.covers, isEmpty);
      },
    );

    test('older schema-one files without covers decode unchanged', () async {
      await vault.writeMetadata(
        catalog.file,
        utf8.encode('{"version":1,"albums":{"a":"Old"},"items":{}}'),
      );
      await catalog.load();
      expect(catalog.albums, {'a': 'Old'});
      expect(catalog.covers, isEmpty);
    });

    test('invalid covers are rejected before adoption', () async {
      for (final covers in [
        '{"unknown":"$cover"}',
        '{"a":"../x.shtr"}',
        '{"a":"photo.jpg"}',
        '{"a":3}',
        '[]',
      ]) {
        await vault.writeMetadata(
          catalog.file,
          utf8.encode(
            '{"version":1,"albums":{"a":"Old"},"items":{},"covers":$covers}',
          ),
        );
        await expectLater(
          PrivateCatalog(vault).load(),
          throwsA(isA<FormatException>()),
          reason: covers,
        );
      }
    });

    test('setCover refuses a missing tag and a bad name', () async {
      await catalog.load();
      await expectLater(catalog.setCover('nope', cover), throwsFormatException);
      final tag = await catalog.createAlbum('Trips');
      await expectLater(catalog.setCover(tag, 'x.jpg'), throwsFormatException);
      expect(catalog.covers, isEmpty);
    });

    test(
      'deleting a tag, deleting the media and merging keep covers consistent',
      () async {
        await catalog.load();
        final a = await catalog.createAlbum('A');
        final b = await catalog.createAlbum('B');
        final c = await catalog.createAlbum('C');
        await catalog.setCover(a, cover);
        await catalog.setCover(b, 'two.jpg.shtr');
        await catalog.setCover(c, 'three.jpg.shtr');

        await catalog.mergeTags(a, b);
        // The destination keeps its own cover; the source cover is dropped.
        expect(catalog.covers, {b: 'two.jpg.shtr', c: 'three.jpg.shtr'});

        await catalog.deleteAlbum(c);
        expect(catalog.covers, {b: 'two.jpg.shtr'});

        await File('${dir.path}/two.jpg.shtr').writeAsBytes([1]);
        await vault.delete(File('${dir.path}/two.jpg.shtr'));
        await catalog.forgetDeleted();
        expect(catalog.covers, isEmpty);
      },
    );

    test(
      'merging gives the destination the source cover when it has none',
      () async {
        await catalog.load();
        final a = await catalog.createAlbum('A');
        final b = await catalog.createAlbum('B');
        await catalog.setCover(a, cover);
        await catalog.mergeTags(a, b);
        expect(catalog.covers, {b: cover});
      },
    );
  });

  test('a closed catalog refuses edits', () async {
    await catalog.load();
    await catalog.close();
    await expectLater(catalog.createAlbum('Late'), throwsStateError);
  });

  group('remote names', () {
    const media = 'one.jpg.shtr';

    test('no mapping writes no field and a plain file still loads', () async {
      await catalog.load();
      await catalog.createAlbum('Trips');
      final plain = jsonDecode(utf8.decode(await _plain(vault, catalog.file)));
      expect(plain.containsKey('remoteNames'), isFalse);
      expect(catalog.remoteNames.isEmpty, isTrue);
    });

    test(
      'an assigned name is stable, survives reopen and other edits',
      () async {
        await catalog.load();
        final first = await catalog.assignRemoteName(media, Random(1));
        expect(first, matches(RegExp(r'^[0-9a-f]{32}\.shtr$')));
        expect(await catalog.assignRemoteName(media, Random(2)), first);
        await catalog.createAlbum('Trips');
        await catalog.organize({media}, favorite: true);
        final reopened = PrivateCatalog(vault);
        await reopened.load();
        expect(reopened.remoteNames.remoteFor(media), first);
        await reopened.close();
        final plain = utf8.decode(await _plain(vault, catalog.file));
        expect(plain, contains(first));
        final raw = utf8.decode(
          await catalog.file.readAsBytes(),
          allowMalformed: true,
        );
        expect(raw, isNot(contains(first)));
      },
    );

    test('invalid mappings are rejected before adoption', () async {
      for (final names in [
        '{"a.shtr":"dir/b.shtr"}',
        '{"a.shtr":"b.txt"}',
        '[]',
        '{"a.shtr":"s.shtr","b.shtr":"s.shtr"}',
      ]) {
        await vault.writeMetadata(
          catalog.file,
          utf8.encode(
            '{"version":1,"albums":{},"items":{},"remoteNames":$names}',
          ),
        );
        await expectLater(
          PrivateCatalog(vault).load(),
          throwsA(isA<FormatException>()),
          reason: names,
        );
      }
    });

    test('a restored catalog brings its mapping with it', () async {
      await catalog.load();
      final name = await catalog.assignRemoteName(media, Random(1));
      final copy = File('${dir.path}/copy.catalog');
      await catalog.file.copy(copy.path);
      final other = Directory('${dir.path}/other')..createSync();
      final peer = PrivateCatalog(Vault(vault.crypto, masterKey, other));
      await peer.restore(copy);
      expect(peer.remoteNames.remoteFor(media), name);
      await peer.close();
    });
  });
}

Future<List<int>> _plain(Vault vault, File file) async => [
  for (final chunk in await vault.read(file).toList()) ...chunk,
];
