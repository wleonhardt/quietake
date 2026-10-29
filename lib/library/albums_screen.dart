import 'package:flutter/material.dart';

import '../gallery/gallery_screen.dart';
import '../keys.dart';
import 'tag_sort.dart';
import '../privacy/privacy_scope.dart';
import '../privacy/privacy_controller.dart';
import '../session.dart';
import 'merge_target.dart';
import 'name_dialog.dart';
import 'private_catalog.dart';

/// The historical class name does not change schema-one album identities.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, required this.session});
  final Session session;
  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final _search = TextEditingController();
  late Future<Set<String>> _available = _loadNames();
  PrivateCatalog get _catalog => widget.session.vault.catalog;
  PrivacyController? _privacy;
  var _wasProtected = false;
  var _privacyEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final privacy = PrivacyScope.maybeOf(context);
    if (identical(privacy, _privacy)) return;
    _privacy?.removeListener(_privacyChanged);
    _privacy = privacy;
    _wasProtected = privacy?.enabled ?? false;
    privacy?.addListener(_privacyChanged);
  }

  void _privacyChanged() {
    final protected = _privacy?.enabled ?? false;
    if (_wasProtected && !protected) _privacyEpoch++;
    _wasProtected = protected;
  }

  Future<Set<String>> _loadNames() async => {
    for (final file in await widget.session.vault.list())
      file.uri.pathSegments.last,
  };

  @override
  void initState() {
    super.initState();
    widget.session.sync.addListener(_onSync);
  }

  void _onSync() {
    if (mounted && !widget.session.sync.isSyncing) {
      setState(() {
        _available = _loadNames();
      });
    }
  }

  @override
  void dispose() {
    widget.session.sync.removeListener(_onSync);
    _privacy?.removeListener(_privacyChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _browse({String? tag, bool untagged = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GalleryScreen(
          session: widget.session,
          searchMode: true,
          initialTags: tag == null ? const {} : {tag},
          initialUntagged: untagged,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _available = _loadNames();
      });
    }
  }

  Future<void> _delete(String id) async {
    final epoch = _privacyEpoch;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text(
          'Remove “${_catalog.albums[id]}” from all captures? Photos and videos stay in your vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Keys.albumDeleteConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete tag'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && epoch == _privacyEpoch) {
      await updateLibrary(context, () => _catalog.deleteAlbum(id));
    }
  }

  Future<void> _merge(String source) async {
    final epoch = _privacyEpoch;
    final target = await chooseMergeTarget(context, _catalog, source);
    if (!mounted || epoch != _privacyEpoch || target == null) return;
    final names = await _loadNames();
    if (!mounted ||
        epoch != _privacyEpoch ||
        !_catalog.albums.containsKey(source) ||
        !_catalog.albums.containsKey(target)) {
      return;
    }
    final combined = names.where((name) {
      final tags = _catalog.details(name).albums;
      return tags.contains(source) || tags.contains(target);
    }).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge tags?'),
        content: Text(
          'Merge “${_catalog.albums[source]}” into “${_catalog.albums[target]}”? $combined ${combined == 1 ? 'capture' : 'captures'} will use the remaining tag. The source tag is removed. Photos, videos and other tags stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Keys.tagMergeConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge tags'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && epoch == _privacyEpoch) {
      await updateLibrary(context, () => _catalog.mergeTags(source, target));
    }
  }

  Future<void> _create(BuildContext context) => editLibraryName(
    context,
    title: 'Create tag',
    initial: _search.text.trim(),
    save: (name) async {
      await _catalog.createAlbum(name);
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tags'),
      actions: [
        const LockButton(),
        IconButton(
          key: Keys.albumCreate,
          tooltip: 'Create tag',
          icon: const Icon(Icons.add),
          onPressed: () => _create(context),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: Keys.tagSearch,
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Find tags',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<Set<String>>(
            future: _available,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _available = _loadNames();
                    }),
                    child: const Text('Could not count captures. Retry'),
                  ),
                );
              }
              final names = snapshot.data;
              if (names == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListenableBuilder(
                listenable: _catalog,
                builder: (context, _) {
                  final entries = sortedTags(_catalog.albums, _search.text);
                  final counts = <String, int>{};
                  var untagged = 0;
                  for (final name in names) {
                    final tags = _catalog.details(name).albums;
                    if (tags.isEmpty) untagged++;
                    for (final id in tags) {
                      counts.update(id, (n) => n + 1, ifAbsent: () => 1);
                    }
                  }
                  String count(int value) =>
                      '$value ${value == 1 ? 'capture' : 'captures'}';
                  return ListView.builder(
                    itemCount: entries.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Card(
                            child: ListTile(
                              key: Keys.libraryUntagged,
                              leading: const Icon(Icons.label_off_outlined),
                              title: const Text('Untagged'),
                              subtitle: Text(count(untagged)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _browse(untagged: true),
                            ),
                          ),
                        );
                      }
                      if (index == 1) {
                        if (entries.isNotEmpty) return const Divider();
                        final searching = _search.text.trim().isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sell_outlined,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                searching ? 'No matching tags' : 'No tags yet',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                searching
                                    ? 'Try another name or create this one.'
                                    : 'Tags group captures across the Library.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                key: Keys.albumCreateFirst,
                                onPressed: () => _create(context),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  searching
                                      ? "Create '${_search.text.trim()}'"
                                      : 'Create first tag',
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final entry = entries[index - 2];
                      return ListTile(
                        key: Keys.tagBrowse(entry.key),
                        leading: const Icon(Icons.sell_outlined),
                        title: Text(entry.value),
                        subtitle: Text(count(counts[entry.key] ?? 0)),
                        onTap: () => _browse(tag: entry.key),
                        trailing: PopupMenuButton<String>(
                          key: Keys.albumMenu(entry.key),
                          tooltip: 'Tag options',
                          onSelected: (action) {
                            switch (action) {
                              case 'rename':
                                editLibraryName(
                                  context,
                                  title: 'Rename tag',
                                  initial: entry.value,
                                  save: (name) =>
                                      _catalog.renameAlbum(entry.key, name),
                                );
                              case 'merge':
                                _merge(entry.key);
                              case 'delete':
                                _delete(entry.key);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              key: Keys.albumRename,
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'merge',
                              key: Keys.tagMerge,
                              enabled: _catalog.albums.length > 1,
                              child: const Text('Merge into…'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              key: Keys.albumDelete,
                              child: Text('Delete tag'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
