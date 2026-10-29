import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/crypto/vault_crypto.dart';
import 'package:quietake/library/private_catalog.dart';
import 'package:quietake/vault/vault.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late Vault vault;
  late Directory dir;
  late PrivateCatalog catalog;
  setUp(() async {
    final sodium = await SodiumSumoInit.init();
    final crypto = VaultCrypto(sodium);
    dir = await Directory.systemTemp.createTemp('private-catalog-');
    vault = Vault(crypto, crypto.generateMasterKey(), dir);
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
}
