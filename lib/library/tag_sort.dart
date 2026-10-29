/// Tags matching [query] (case-insensitive substring), sorted by name, used
/// by the picker, the merge target sheet and the Tags screen alike.
List<MapEntry<String, String>> sortedTags(
  Map<String, String> albums,
  String query, {
  String? exclude,
}) {
  final needle = query.trim().toLowerCase();
  return albums.entries
      .where(
        (entry) =>
            entry.key != exclude && entry.value.toLowerCase().contains(needle),
      )
      .toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
}
