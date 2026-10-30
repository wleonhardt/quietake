import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../cast/device_picker.dart';
import '../brand.dart';
import '../keys.dart';
import '../library/albums_screen.dart';
import '../library/import_screen.dart';
import '../library/library_query.dart';
import '../library/name_dialog.dart';
import '../library/tag_picker.dart';
import '../library/view_sheet.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_settings.dart';
import '../sync/sync_controller.dart';
import 'item.dart';
import 'preview.dart';
import 'share_dialog.dart';
import 'viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    required this.session,
    this.searchMode = false,
    this.initialTags = const {},
    this.initialUntagged = false,
  });
  final Session session;
  final bool searchMode;
  final Set<String> initialTags;
  final bool initialUntagged;
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<VaultItem>> _items = _load();
  final _search = TextEditingController();
  final _selected = <String>{};
  var _selecting = false;
  late bool _composing =
      widget.searchMode &&
      widget.initialTags.isEmpty &&
      !widget.initialUntagged;
  late Set<String> _tags = {...widget.initialTags};
  late bool _untagged = widget.initialUntagged;
  bool _matchAny = false;
  var _kind = MediaKind.all;
  var _favorites = false;
  var _sort = LibrarySort.newest;
  bool _catalogUnavailable = false;
  (
    List<VaultItem>,
    String,
    MediaKind,
    bool,
    LibrarySort,
    Set<String>,
    bool,
    bool,
  )?
  _queryInputs;
  List<VaultItem> _queryItems = const [];

  void _scope(VoidCallback change) => setState(() {
    change();
    _selected.clear();
    _selecting = false;
  });

  void _onCatalog() {
    if (!mounted) return;
    setState(() {
      // Loads replace metadata too, without increasing the catalog edit revision.
      _queryInputs = null;
      final existing = widget.session.vault.catalog.albums;
      if (!_tags.every(existing.containsKey)) {
        _tags = _tags.where(existing.containsKey).toSet();
        _selected.clear();
        _selecting = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.session.sync.addListener(_onSync);
    widget.session.vault.catalog.addListener(_onCatalog);
  }

  late bool _wasSyncing = widget.session.sync.isSyncing;

  /// Only a finished transfer can change the library; other notifications
  /// (cancel, disconnect, progress) must not rescan it.
  void _onSync() {
    if (!mounted) return;
    final syncing = widget.session.sync.isSyncing;
    if (_wasSyncing && !syncing) {
      setState(() {
        _items = _load();
      });
    }
    _wasSyncing = syncing;
  }

  @override
  void dispose() {
    widget.session.sync.removeListener(_onSync);
    widget.session.vault.catalog.removeListener(_onCatalog);
    _search.dispose();
    super.dispose();
  }

  Future<List<VaultItem>> _load() async {
    try {
      await widget.session.vault.catalog.load();
      await widget.session.vault.catalog.forgetDeleted();
      if (mounted && _catalogUnavailable) {
        setState(() => _catalogUnavailable = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _catalogUnavailable = true;
          _kind = MediaKind.all;
          _favorites = false;
          _tags = {};
          _untagged = false;
          _search.clear();
          _selected.clear();
          _selecting = false;
        });
      }
    }
    final all = (await widget.session.vault.list()).map(VaultItem.new).toList();
    _all = all;
    return all;
  }

  /// Last loaded library, so the view sheet can show how many captures a
  /// pending view would list.
  List<VaultItem> _all = const [];

  int _countFor(LibraryView view) {
    final catalog = widget.session.vault.catalog;
    return LibraryQuery(
      text: _search.text,
      kind: view.kind,
      favorites: view.favorites,
      sort: view.sort,
      tags: _tags,
      matchAnyTag: _matchAny,
      untagged: _untagged,
    ).apply(_all, catalog.items, catalog.albums).length;
  }

  Future<void> _chooseTags({bool remove = false}) async {
    final catalog = widget.session.vault.catalog;
    final selected = {..._selected};
    final tags = await chooseTags(
      context,
      catalog,
      captures: selected,
      remove: remove,
    );
    if (!mounted || tags == null || tags.isEmpty) return;
    await updateLibrary(
      context,
      () => catalog.organize(selected, tagIds: tags, remove: remove),
    );
  }

  Future<void> _openSearch({
    Set<String> tags = const {},
    bool untagged = false,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _scope(() {});
    if (widget.searchMode) {
      setState(() => _composing = true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GalleryScreen(
          session: widget.session,
          searchMode: true,
          initialTags: tags,
          initialUntagged: untagged,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _items = _load();
      });
    }
  }

  Future<void> _view() async {
    final view = await chooseLibraryView(context, (
      kind: _kind,
      favorites: _favorites,
      sort: _sort,
    ), count: _countFor);
    if (!mounted || view == null) return;
    _scope(() {
      _kind = view.kind;
      _favorites = view.favorites;
      _sort = view.sort;
    });
  }

  Future<void> _actions() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Library actions'),
              trailing: IconButton(
                key: Keys.libraryActionsClose,
                tooltip: 'Close Library actions',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ),
            ListTile(
              key: Keys.librarySelect,
              leading: const Icon(Icons.checklist),
              title: const Text('Select captures'),
              onTap: () {
                Navigator.pop(sheetContext);
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  _selecting = true;
                  _composing = false;
                });
              },
            ),
            ListTile(
              key: Keys.libraryAlbums,
              leading: const Icon(Icons.sell_outlined),
              title: const Text('Tags'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AlbumsScreen(session: widget.session),
                  ),
                );
              },
            ),
            ListTile(
              key: Keys.libraryUntagged,
              leading: const Icon(Icons.label_off_outlined),
              title: const Text('Untagged'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (widget.searchMode) {
                  _scope(() {
                    _tags = {};
                    _search.clear();
                    _untagged = true;
                    _composing = false;
                  });
                } else {
                  _openSearch(untagged: true);
                }
              },
            ),
            ListenableBuilder(
              listenable: widget.session.sync,
              builder: (_, _) => Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                children: _secondaryActions(sheetContext),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );

  Widget _tools({required bool compact}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: !widget.searchMode || !_composing
                  ? TextButton.icon(
                      key: Keys.libraryOpenSearch,
                      onPressed: _catalogUnavailable ? null : _openSearch,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHigh,
                      ),
                      icon: const Icon(Icons.search),
                      label: Text(
                        widget.searchMode
                            ? 'Edit search'
                            : 'Search names and tags',
                      ),
                    )
                  : TextField(
                      key: Keys.librarySearch,
                      controller: _search,
                      autofocus: true,
                      onChanged: (_) => _scope(() {}),
                      onSubmitted: (_) => _scope(() {
                        _composing = false;
                        FocusManager.instance.primaryFocus?.unfocus();
                      }),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search names and tags',
                        isDense: true,
                      ),
                    ),
            ),
            CastButton(key: Keys.galleryCast, cast: widget.session.cast),
          ],
        ),
        if (widget.searchMode &&
            (_tags.isNotEmpty ||
                _untagged ||
                (!_composing && _search.text.isNotEmpty)))
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final id in _tags)
                InputChip(
                  key: Keys.libraryRemoveTag(id),
                  label: Text(
                    widget.session.vault.catalog.albums[id] ?? 'Removed tag',
                  ),
                  onDeleted: () => _scope(() => _tags = {..._tags}..remove(id)),
                ),
              if (_untagged)
                InputChip(
                  label: const Text('Untagged'),
                  onDeleted: () => _scope(() => _untagged = false),
                ),
              if (!_composing && _search.text.isNotEmpty)
                InputChip(
                  label: Text(_search.text),
                  onDeleted: () => _scope(_search.clear),
                ),
            ],
          ),
        if (!compact)
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.searchMode
                      ? (_matchAny
                            ? 'All Library · Match any tag'
                            : 'All Library · Match all tags')
                      : switch (_sort) {
                          LibrarySort.newest => 'Newest captures',
                          LibrarySort.oldest => 'Oldest captures',
                          LibrarySort.name => 'Name order',
                        },
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                key: Keys.libraryView,
                onPressed: _view,
                child: const Text('View'),
              ),
              if (widget.searchMode)
                PopupMenuButton<bool>(
                  key: Keys.librarySearchOptions,
                  tooltip: 'Tag matching',
                  icon: const Icon(Icons.tune),
                  onSelected: (any) => _scope(() => _matchAny = any),
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      key: Keys.libraryMatchAll,
                      value: false,
                      checked: !_matchAny,
                      child: const Text('Match all tags'),
                    ),
                    CheckedPopupMenuItem(
                      key: Keys.libraryMatchAny,
                      value: true,
                      checked: _matchAny,
                      child: const Text('Match any tag'),
                    ),
                  ],
                ),
              IconButton(
                key: Keys.libraryTools,
                tooltip: 'Library actions',
                icon: const Icon(Icons.more_horiz),
                onPressed: _actions,
              ),
            ],
          ),
        if (_favorites || _kind != MediaKind.all || _sort != LibrarySort.newest)
          TextButton.icon(
            key: Keys.libraryResetScope,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: Text(
              [
                if (_kind != MediaKind.all)
                  _kind == MediaKind.photo ? 'Photos' : 'Videos',
                if (_favorites) 'Favorites',
                if (_sort != LibrarySort.newest)
                  _sort == LibrarySort.oldest ? 'Oldest first' : 'Name order',
                'Reset view',
              ].join(' · '),
            ),
            onPressed: () => _scope(() {
              _kind = MediaKind.all;
              _favorites = false;
              _sort = LibrarySort.newest;
            }),
          ),
      ],
    ),
  );

  Widget _searchChoices(int count) {
    final entries =
        widget.session.vault.catalog.albums.entries
            .where(
              (entry) =>
                  !_tags.contains(entry.key) &&
                  entry.value.toLowerCase().contains(
                    _search.text.trim().toLowerCase(),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return FilledButton(
            key: Keys.libraryShowSearch,
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _scope(() => _composing = false);
            },
            child: Text('Show $count ${count == 1 ? 'capture' : 'captures'}'),
          );
        }
        if (index == 1) {
          return const ListTile(
            title: Text('Add a tag'),
            subtitle: Text(
              'Choose existing tags, or search names with the text above.',
            ),
          );
        }
        final entry = entries[index - 2];
        return ListTile(
          key: Keys.libraryTag(entry.key),
          leading: const Icon(Icons.sell_outlined),
          title: Text(entry.value),
          trailing: const Icon(Icons.add),
          onTap: () => _scope(() {
            _tags = {..._tags, entry.key};
            _untagged = false;
            _search.clear();
          }),
        );
      },
    );
  }

  Widget _selectionBar(List<VaultItem> visible) {
    final catalog = widget.session.vault.catalog;
    final allFavorite =
        _selected.isNotEmpty &&
        _selected.every((name) => catalog.details(name).favorite);
    final enabled = _selected.isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: Keys.libraryCancelSelection,
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: () => _scope(() {}),
                ),
                Expanded(
                  child: Text(
                    '${_selected.length} selected',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  key: Keys.librarySelectAll,
                  tooltip: 'Select all results',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(
                    () => _selected.addAll(visible.map((i) => i.name)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Builder(
                  builder: (buttonContext) => TextButton.icon(
                    key: Keys.libraryShare,
                    label: const Text('Share copies'),
                    icon: const Icon(Icons.ios_share),
                    onPressed: !enabled
                        ? null
                        : () {
                            final box =
                                buttonContext.findRenderObject()! as RenderBox;
                            showShareCopies(
                              context,
                              widget.session.vault,
                              visible
                                  .where(
                                    (item) => _selected.contains(item.name),
                                  )
                                  .toList(),
                              origin: box.localToGlobal(Offset.zero) & box.size,
                            );
                          },
                  ),
                ),
                TextButton.icon(
                  key: Keys.libraryFavorite,
                  label: Text(allFavorite ? 'Unfavorite' : 'Favorite'),
                  icon: Icon(
                    allFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                  onPressed: !enabled
                      ? null
                      : () => updateLibrary(
                          context,
                          () => catalog.organize({
                            ..._selected,
                          }, favorite: !allFavorite),
                        ),
                ),
                TextButton.icon(
                  key: Keys.libraryAddAlbum,
                  label: const Text('Add tags'),
                  icon: const Icon(Icons.playlist_add),
                  onPressed: !enabled ? null : _chooseTags,
                ),
                TextButton.icon(
                  key: Keys.libraryRemoveAlbum,
                  label: const Text('Remove tags'),
                  icon: const Icon(Icons.playlist_remove),
                  onPressed: !enabled ? null : () => _chooseTags(remove: true),
                ),
                if (_selected.length == 1)
                  TextButton.icon(
                    key: Keys.libraryRename,
                    label: const Text('Name capture'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      final name = _selected.single;
                      editLibraryName(
                        context,
                        title: 'Name capture',
                        initial: catalog.details(name).title,
                        save: (title) => catalog.renameItem(name, title),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final initial = await SyncSettings.load();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<SyncSettings>(
        builder: (_) =>
            SettingsScreen(initial: initial, session: widget.session),
      ),
    );
  }

  bool get _compactHeader => MediaQuery.sizeOf(context).width < 480;

  Future<void> _importFiles() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ImportScreen(session: widget.session),
      ),
    );
    if (mounted) {
      setState(() {
        _items = _load();
      });
    }
  }

  Widget _emptyState({
    required Key messageKey,
    required String title,
    required String message,
    required List<Widget> actions,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            key: messageKey,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: actions,
          ),
        ],
      ),
    ),
  );

  List<Widget> _secondaryActions(BuildContext sheetContext) => [
    IconButton(
      key: Keys.libraryImport,
      tooltip: 'Import copies from Files',
      icon: const Icon(Icons.add_photo_alternate_outlined),
      onPressed: () {
        Navigator.pop(sheetContext);
        _importFiles();
      },
    ),
    IconButton(
      key: Keys.gallerySync,
      tooltip: widget.session.sync.isSyncing
          ? 'Cancel sync'
          : widget.session.sync.state == SyncState.unconfigured
          ? 'Set up backup'
          : 'Sync with NAS',
      icon: Icon(widget.session.sync.isSyncing ? Icons.close : Icons.sync),
      onPressed: widget.session.sync.isSyncing
          ? widget.session.sync.cancel
          : widget.session.sync.state == SyncState.unconfigured
          ? () {
              Navigator.pop(sheetContext);
              _openSettings();
            }
          : widget.session.sync.sync,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: widget.searchMode
          ? IconButton(
              key: Keys.libraryCloseSearch,
              tooltip: 'Close search',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Text(widget.searchMode ? 'Search' : 'Library'),
      titleSpacing: _compactHeader ? 8 : null,
      actions: [
        const LockButton(),
        // Narrow bars keep Select in the actions sheet so the title stays whole.
        if (!_selecting && !widget.searchMode && !_compactHeader)
          IconButton(
            key: Keys.librarySelectMode,
            tooltip: 'Select captures',
            icon: const Icon(Icons.checklist),
            onPressed: _catalogUnavailable
                ? null
                : () => setState(() {
                    _selecting = true;
                    _composing = false;
                  }),
          ),
        IconButton(
          key: Keys.gallerySettings,
          tooltip: 'Settings',
          icon: const Icon(Icons.settings),
          onPressed: _openSettings,
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.min(
                constraints.maxHeight,
                math.max(kMinInteractiveDimension, constraints.maxHeight * .65),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  IgnorePointer(
                    ignoring: _catalogUnavailable,
                    child: _tools(
                      compact: MediaQuery.viewInsetsOf(context).bottom > 0,
                    ),
                  ),
                  if (_catalogUnavailable)
                    TextButton.icon(
                      key: Keys.libraryRetry,
                      onPressed: () => setState(() {
                        _items = _load();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Organization unavailable. Originals are safe. Retry',
                      ),
                    ),
                  if (widget.session.sync.result != null &&
                      widget.session.sync.state != SyncState.unconfigured &&
                      MediaQuery.viewInsetsOf(context).bottom == 0)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        widget.session.sync.result!,
                        key: Keys.gallerySyncResult,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _items,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _items = _load();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Could not open vault. Retry'),
                    ),
                  );
                }
                final all = snap.data;
                if (all == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (all.isEmpty && !widget.searchMode) {
                  return _emptyState(
                    messageKey: Keys.galleryEmpty,
                    title: 'Your library starts here',
                    message: 'Take a photo or import copies from Files.',
                    actions: [
                      FilledButton.icon(
                        key: Keys.galleryEmptyCamera,
                        onPressed: Navigator.canPop(context)
                            ? () => Navigator.pop(context)
                            : null,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Open camera'),
                      ),
                      OutlinedButton.icon(
                        key: Keys.galleryEmptyImport,
                        onPressed: _importFiles,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Import copies'),
                      ),
                    ],
                  );
                }
                final catalog = widget.session.vault.catalog;
                final inputs = (
                  all,
                  _search.text,
                  _kind,
                  _favorites,
                  _sort,
                  _tags,
                  _matchAny,
                  _untagged,
                );
                if (_queryInputs != inputs) {
                  _queryItems = LibraryQuery(
                    text: _search.text,
                    kind: _kind,
                    favorites: _favorites,
                    tags: _tags,
                    matchAnyTag: _matchAny,
                    untagged: _untagged,
                    sort: _sort,
                  ).apply(all, catalog.items, catalog.albums);
                  _queryInputs = inputs;
                  final names = _queryItems.map((i) => i.name).toSet();
                  if (!_selected.every(names.contains)) {
                    // Selection is state; trim it after this frame, not in build.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _selected.retainAll(names));
                      }
                    });
                  }
                }
                final items = _queryItems;
                if (widget.searchMode && _composing) {
                  return _searchChoices(items.length);
                }
                return LayoutBuilder(
                  builder: (context, contentConstraints) => Column(
                    children: [
                      Expanded(
                        child: items.isEmpty
                            ? _emptyState(
                                messageKey: Keys.libraryNoResults,
                                title: 'No captures match',
                                message: 'Clear your search and filters to see all captures.',
                                actions: [
                                  FilledButton(
                                    key: Keys.libraryClearFilters,
                                    onPressed: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      _scope(() {
                                        _search.clear();
                                        _kind = MediaKind.all;
                                        _favorites = false;
                                        _tags = {};
                                        _untagged = false;
                                      });
                                    },
                                    child: const Text(
                                      'Clear search and filters',
                                    ),
                                  ),
                                ],
                              )
                            : GridView.builder(
                                key: Keys.galleryGrid,
                                padding: const EdgeInsets.all(4),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 180,
                                      mainAxisSpacing: 4,
                                      crossAxisSpacing: 4,
                                    ),
                                itemCount: items.length,
                                itemBuilder: (context, i) => _Tile(
                                  key: Keys.galleryTile(i),
                                  item: items[i],
                                  position: i + 1,
                                  total: items.length,
                                  cache: widget.session.previews,
                                  title: catalog.details(items[i].name).title,
                                  favorite: catalog
                                      .details(items[i].name)
                                      .favorite,
                                  selected: _selected.contains(items[i].name),
                                  selecting: _selecting,
                                  onLongPress: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    setState(() {
                                      _selecting = true;
                                      _composing = false;
                                      _selected.add(items[i].name);
                                    });
                                  },
                                  onTap: () async {
                                    if (_selecting) {
                                      setState(() {
                                        if (!_selected.add(items[i].name)) {
                                          _selected.remove(items[i].name);
                                        }
                                      });
                                      return;
                                    }
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    await Navigator.of(context).push<bool>(
                                      MaterialPageRoute<bool>(
                                        builder: (_) => ViewerScreen(
                                          session: widget.session,
                                          items: items,
                                          initialIndex: i,
                                        ),
                                      ),
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _items = _load();
                                      });
                                    }
                                  },
                                ),
                              ),
                      ),
                      if (_selecting)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: contentConstraints.maxHeight * .5,
                          ),
                          child: SingleChildScrollView(
                            child: _selectionBar(items),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tile extends StatefulWidget {
  const _Tile({
    super.key,
    required this.item,
    required this.position,
    required this.total,
    required this.cache,
    required this.onTap,
    required this.onLongPress,
    required this.title,
    required this.favorite,
    required this.selected,
    required this.selecting,
  });
  final VaultItem item;
  final int position;
  final int total;
  final PreviewCache cache;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String title;
  final bool favorite;
  final bool selected;
  final bool selecting;
  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  late Future<MediaPreview> _preview = widget.cache.get(widget.item);
  @override
  void didUpdateWidget(covariant _Tile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.name != widget.item.name) {
      oldWidget.cache.release(oldWidget.item);
      _preview = widget.cache.get(widget.item);
    }
  }

  @override
  void dispose() {
    widget.cache.release(widget.item);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MediaPreview>(
    key: ValueKey(widget.item.name),
    future: _preview,
    builder: _buildTile,
  );

  Widget _buildTile(BuildContext context, AsyncSnapshot<MediaPreview> snap) {
    final item = widget.item;
    final onTap = widget.onTap;
    final date = item.capturedAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final duration = snap.data?.duration;
    final status = snap.hasError
        ? ', Preview unavailable'
        : duration == null
        ? ''
        : ', duration ${mediaTime(duration)}';
    final label =
        '${item.isVideo ? 'Video' : 'Photo'}${date == null ? '' : ', ${localizations.formatFullDate(date)}, ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}'}';
    return Semantics(
      label:
          '${widget.selecting ? 'Select' : 'Open'} $label${widget.title.isEmpty ? '' : ', ${widget.title}'}${widget.favorite ? ', favorite' : ''}, ${widget.position} of ${widget.total}$status',
      selected: widget.selecting ? widget.selected : null,
      button: true,
      onTap: onTap,
      onLongPress: widget.onLongPress,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: widget.onLongPress,
        excludeFromSemantics: false,
        child: ExcludeSemantics(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _previewImage(snap),
                if (widget.selecting && widget.selected)
                  // A light scrim plus a primary check reads on bright photos.
                  const ColoredBox(color: Color(0x40ffffff)),
                if (widget.favorite || widget.selecting)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: widget.selecting && widget.selected
                        ? DecoratedBox(
                            decoration: const BoxDecoration(
                              color: onMediaCanvas,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : Icon(
                            widget.selecting
                                ? Icons.radio_button_unchecked
                                : Icons.favorite,
                            color: onMediaCanvas,
                            shadows: const [Shadow(blurRadius: 4)],
                          ),
                  ),
                if (widget.title.isNotEmpty || duration != null)
                  Positioned(
                    bottom: 4,
                    left: widget.title.isEmpty ? null : 4,
                    right: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: mediaScrimStrong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.title.isNotEmpty)
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: onMediaCanvas,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (duration != null) ...[
                              if (widget.title.isNotEmpty)
                                const SizedBox(width: 4),
                              Text(
                                mediaTime(duration),
                                key: Keys.galleryVideoDuration,
                                style: const TextStyle(
                                  color: onMediaCanvas,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewImage(AsyncSnapshot<MediaPreview> snap) {
    if (snap.hasError) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          semanticLabel: 'Preview unavailable',
        ),
      );
    }
    final preview = snap.data;
    if (preview == null) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return RawImage(
      key: Keys.galleryPreview,
      image: preview.image,
      fit: BoxFit.cover,
    );
  }
}
