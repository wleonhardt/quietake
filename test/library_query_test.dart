import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/gallery/item.dart';
import 'package:quietake/library/library_query.dart';
import 'package:quietake/library/private_catalog.dart';

void main() {
  final items = [
    VaultItem(File('/vault/2026-01.jpg.shtr')),
    VaultItem(File('/vault/2026-03.mp4.shtr')),
    VaultItem(File('/vault/2026-02.png.shtr')),
  ];
  final details = {
    items[0].name: const CaptureDetails(
      title: 'Sunset',
      favorite: true,
      albums: {'a'},
    ),
    items[1].name: const CaptureDetails(title: 'Morning', albums: {'a'}),
  };
  List<String> names(LibraryQuery query) =>
      query.apply(items, details, {'a': 'Holiday'}).map((i) => i.name).toList();

  test('default newest, oldest, and display-name order are deterministic', () {
    expect(names(const LibraryQuery()), [
      items[1].name,
      items[2].name,
      items[0].name,
    ]);
    expect(names(const LibraryQuery(sort: LibrarySort.oldest)), [
      items[0].name,
      items[2].name,
      items[1].name,
    ]);
    expect(names(const LibraryQuery(sort: LibrarySort.name)), [
      items[2].name,
      items[1].name,
      items[0].name,
    ]);
  });
  test('media, favorites, album, and search scopes combine', () {
    expect(names(const LibraryQuery(kind: MediaKind.video)), [items[1].name]);
    expect(names(const LibraryQuery(kind: MediaKind.photo, favorites: true)), [
      items[0].name,
    ]);
    expect(names(const LibraryQuery(tags: {'a'}, text: ' holiday ')), [
      items[1].name,
      items[0].name,
    ]);
    expect(names(const LibraryQuery(text: 'SUNSET')), [items[0].name]);
    expect(
      names(const LibraryQuery(text: '2026-02')),
      isEmpty,
      reason: 'vault filenames are not searchable (decision 036)',
    );
    expect(names(const LibraryQuery(text: 'jpg')), isEmpty);
    expect(
      names(const LibraryQuery(kind: MediaKind.video, favorites: true)),
      isEmpty,
    );
    expect(names(const LibraryQuery(tags: {'missing'})), isEmpty);
  });

  test('tag intersection, union and untagged have explicit scopes', () {
    final metadata = {
      items[0].name: const CaptureDetails(
        albums: {'subject', 'action'},
        favorite: true,
      ),
      items[1].name: const CaptureDetails(albums: {'subject'}),
    };
    const tags = {'subject': 'Alex', 'action': 'Running outdoors'};
    List<String> match(LibraryQuery query) =>
        query.apply(items, metadata, tags).map((i) => i.name).toList();
    expect(match(const LibraryQuery(tags: {'subject', 'action'})), [
      items[0].name,
    ]);
    expect(
      match(const LibraryQuery(tags: {'subject', 'action'}, matchAnyTag: true)),
      [items[1].name, items[0].name],
    );
    expect(
      match(
        const LibraryQuery(
          tags: {'subject'},
          kind: MediaKind.video,
          favorites: true,
        ),
      ),
      isEmpty,
    );
    expect(
      match(const LibraryQuery(tags: {'subject'}, text: 'running outdoors')),
      [items[0].name],
    );
    expect(match(const LibraryQuery(tags: {'missing'})), isEmpty);
    expect(match(const LibraryQuery(untagged: true)), [items[2].name]);
    expect(
      match(const LibraryQuery(tags: {'subject'}, untagged: true)),
      isEmpty,
    );
    expect(
      match(const LibraryQuery(text: 'Alex running')),
      isEmpty,
      reason: 'A plain phrase does not silently become recognition or tokens',
    );
  });
}
