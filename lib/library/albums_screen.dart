import 'package:flutter/material.dart';

import '../gallery/gallery_screen.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import 'tag_sort.dart';
import '../privacy/privacy_scope.dart';
import '../privacy/privacy_controller.dart';
import '../session.dart';
import 'merge_target.dart';
import 'moments_screen.dart';
import 'recently_deleted_screen.dart';
import 'name_dialog.dart';
import 'private_catalog.dart';
import 'tag_cover.dart';

/// The historical class name does not change schema-one album identities.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, required this.session});
  final Session session;
  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final _search = TextEditingController();
  bool _byCount = false;
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
        title: Text(context.l10n.tagsDeleteTitle),
        content: Text(context.l10n.tagsDeleteBody(_catalog.albums[id] ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: Keys.albumDeleteConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.tagsDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && epoch == _privacyEpoch) {
      await updateLibrary(context, () => _catalog.deleteAlbum(id));
    }
  }

  Future<void> _setCover(String id, Set<String> available) async {
    final epoch = _privacyEpoch;
    final names = [
      for (final name in available)
        if (_catalog.details(name).albums.contains(id)) name,
    ]..sort((a, b) => b.compareTo(a));
    final pick = await chooseTagCover(
      context,
      widget.session,
      names.take(60).toList(),
    );
    if (pick == null || !mounted || epoch != _privacyEpoch) return;
    await updateLibrary(context, () => _catalog.setCover(id, pick));
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
        title: Text(context.l10n.tagsMergeTitle),
        content: Text(
          context.l10n.tagsMergeBody(
            _catalog.albums[source] ?? '',
            _catalog.albums[target] ?? '',
            combined,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: Keys.tagMergeConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.tagsMergeConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && epoch == _privacyEpoch) {
      await updateLibrary(context, () => _catalog.mergeTags(source, target));
    }
  }

  Widget _leading(String id, Set<String> available) {
    const icon = Icon(Icons.sell_outlined);
    final cover = _catalog.covers[id];
    if (cover == null || !available.contains(cover)) return icon;
    // The inner key makes a new cover replace the old thumbnail's state.
    return KeyedSubtree(
      key: Keys.tagCoverThumb(id),
      child: CaptureThumb(
        key: ValueKey(cover),
        session: widget.session,
        name: cover,
        fallback: icon,
      ),
    );
  }

  Future<void> _create(BuildContext context) => editLibraryName(
    context,
    title: context.l10n.tagsCreate,
    initial: _search.text.trim(),
    save: (name) async {
      await _catalog.createAlbum(name);
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    // A keyboard, including one under the name dialog, must not squeeze the
    // search field on a short landscape screen; the list pads itself instead.
    resizeToAvoidBottomInset: false,
    appBar: AppBar(
      title: Text(context.l10n.tagsTitle),
      actions: [
        const LockButton(),
        IconButton(
          key: Keys.momentsOpen,
          tooltip: context.l10n.tagsMoments,
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MomentsScreen(session: widget.session),
            ),
          ),
        ),
        IconButton(
          key: Keys.recentlyDeletedOpen,
          tooltip: context.l10n.recentlyDeletedTitle,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => RecentlyDeletedScreen(session: widget.session),
            ),
          ),
        ),
        IconButton(
          key: Keys.albumSort,
          tooltip: _byCount
              ? context.l10n.tagsSortName
              : context.l10n.tagsSortCount,
          icon: Icon(
            _byCount ? Icons.sort_by_alpha : Icons.format_list_numbered,
          ),
          onPressed: () => setState(() => _byCount = !_byCount),
        ),
        IconButton(
          key: Keys.albumCreate,
          tooltip: context.l10n.tagsCreate,
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
            decoration: InputDecoration(
              labelText: context.l10n.tagsFind,
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
                    child: Text(context.l10n.tagsCountFailed),
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
                  if (_byCount) {
                    // The list is already by name, and sort is stable.
                    entries.sort(
                      (a, b) =>
                          (counts[b.key] ?? 0).compareTo(counts[a.key] ?? 0),
                    );
                  }
                  String count(int value) =>
                      context.l10n.tagsCaptureCount(value);
                  return ListView.builder(
                    padding: EdgeInsets.only(
                      bottom:
                          MediaQuery.paddingOf(context).bottom +
                          MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    itemCount: entries.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Card(
                            child: ListTile(
                              key: Keys.libraryUntagged,
                              leading: const Icon(Icons.label_off_outlined),
                              title: Text(context.l10n.tagsUntagged),
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
                                searching
                                    ? context.l10n.tagsNoMatch
                                    : context.l10n.tagsNone,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                searching
                                    ? context.l10n.tagsNoMatchHint
                                    : context.l10n.tagsNoneHint,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                key: Keys.albumCreateFirst,
                                onPressed: () => _create(context),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  searching
                                      ? context.l10n.tagsCreateNamed(
                                          _search.text.trim(),
                                        )
                                      : context.l10n.tagsCreateFirst,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final entry = entries[index - 2];
                      return ListTile(
                        key: Keys.tagBrowse(entry.key),
                        leading: _leading(entry.key, names),
                        title: Text(entry.value),
                        subtitle: Text(count(counts[entry.key] ?? 0)),
                        onTap: () => _browse(tag: entry.key),
                        trailing: PopupMenuButton<String>(
                          key: Keys.albumMenu(entry.key),
                          tooltip: context.l10n.tagsOptions,
                          onSelected: (action) {
                            switch (action) {
                              case 'rename':
                                editLibraryName(
                                  context,
                                  title: context.l10n.tagsRenameTitle,
                                  initial: entry.value,
                                  save: (name) =>
                                      _catalog.renameAlbum(entry.key, name),
                                );
                              case 'cover':
                                _setCover(entry.key, names);
                              case 'uncover':
                                updateLibrary(
                                  context,
                                  () => _catalog.setCover(entry.key, null),
                                );
                              case 'merge':
                                _merge(entry.key);
                              case 'delete':
                                _delete(entry.key);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              key: Keys.albumRename,
                              child: Text(context.l10n.tagsRename),
                            ),
                            PopupMenuItem(
                              value: 'cover',
                              key: Keys.tagCoverSet,
                              child: Text(context.l10n.tagsSetCover),
                            ),
                            if (_catalog.covers.containsKey(entry.key))
                              PopupMenuItem(
                                value: 'uncover',
                                key: Keys.tagCoverClear,
                                child: Text(context.l10n.tagsClearCover),
                              ),
                            PopupMenuItem(
                              value: 'merge',
                              key: Keys.tagMerge,
                              enabled: _catalog.albums.length > 1,
                              child: Text(context.l10n.tagsMergeInto),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              key: Keys.albumDelete,
                              child: Text(context.l10n.tagsDelete),
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
