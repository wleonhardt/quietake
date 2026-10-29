import '../gallery/item.dart';
import 'private_catalog.dart';

enum MediaKind { all, photo, video }

enum LibrarySort { newest, oldest, name }

class LibraryQuery {
  const LibraryQuery({
    this.text = '',
    this.kind = MediaKind.all,
    this.favorites = false,
    this.tags = const {},
    this.matchAnyTag = false,
    this.untagged = false,
    this.sort = LibrarySort.newest,
  });
  final String text;
  final MediaKind kind;
  final bool favorites;
  final Set<String> tags;
  final bool matchAnyTag;
  final bool untagged;
  final LibrarySort sort;

  List<VaultItem> apply(
    List<VaultItem> items,
    Map<String, CaptureDetails> metadata,
    Map<String, String> albums,
  ) {
    final query = text.trim().toLowerCase();
    String title(VaultItem item) {
      final title = metadata[item.name]?.title ?? '';
      return title.isEmpty ? item.name : title;
    }

    final matches = items.where((item) {
      final details = metadata[item.name] ?? const CaptureDetails();
      return (kind == MediaKind.all ||
              item.isVideo == (kind == MediaKind.video)) &&
          (!favorites || details.favorite) &&
          (!untagged || details.albums.isEmpty) &&
          (tags.isEmpty ||
              (matchAnyTag
                  ? tags.any(details.albums.contains)
                  : tags.every(details.albums.contains))) &&
          // Decision 036: search covers titles and tags, never the vault
          // filename, which would match "jpg" or "shtr" on every capture.
          (query.isEmpty ||
              [
                details.title,
                ...details.albums.map((id) => albums[id] ?? ''),
              ].any((value) => value.toLowerCase().contains(query)));
    }).toList();
    matches.sort((a, b) {
      final compared = switch (sort) {
        LibrarySort.newest => b.name.compareTo(a.name),
        LibrarySort.oldest => a.name.compareTo(b.name),
        LibrarySort.name => title(
          a,
        ).toLowerCase().compareTo(title(b).toLowerCase()),
      };
      return compared == 0 ? a.name.compareTo(b.name) : compared;
    });
    return matches;
  }
}
