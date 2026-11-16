import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import 'name_dialog.dart';
import 'tag_sort.dart';
import 'private_catalog.dart';

/// Null cancels. An empty camera selection means no tags for future captures.
Future<Set<String>?> chooseTags(
  BuildContext context,
  PrivateCatalog catalog, {
  Set<String> selected = const {},
  Set<String>? captures,
  bool remove = false,
  VoidCallback? onManage,
}) => showModalBottomSheet<Set<String>>(
  context: context,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .85,
  ),
  builder: (_) => _TagPicker(
    catalog: catalog,
    selected: {...selected},
    captures: captures == null ? null : {...captures},
    remove: remove,
    onManage: onManage,
  ),
);

class _TagPicker extends StatefulWidget {
  const _TagPicker({
    required this.catalog,
    required this.selected,
    required this.captures,
    required this.remove,
    required this.onManage,
  });
  final PrivateCatalog catalog;
  final Set<String> selected;
  final Set<String>? captures;
  final bool remove;
  final VoidCallback? onManage;
  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  final _search = TextEditingController();
  late final _selected = {...widget.selected};
  bool get _camera => widget.captures == null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.catalog,
          builder: (context, _) {
            final entries = sortedTags(widget.catalog.albums, _search.text);
            final stale = _selected.any(
              (id) => !widget.catalog.albums.containsKey(id),
            );
            final typed = _search.text.trim();
            final exact = widget.catalog.albums.values.any(
              (name) => name.toLowerCase() == typed.toLowerCase(),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: Text(
                          _camera
                              ? l10n.pickerCameraTitle
                              : widget.remove
                              ? l10n.pickerRemoveTitle
                              : l10n.pickerAddTitle,
                        ),
                        subtitle: Text(
                          _camera
                              ? l10n.pickerCameraNote
                              : l10n.pickerSelectionNote(
                                  widget.captures!.length,
                                ),
                        ),
                        trailing: IconButton(
                          key: _camera
                              ? Keys.captureAlbumClose
                              : Keys.tagPickerClose,
                          tooltip: l10n.pickerCancel,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          key: Keys.tagPickerSearch,
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l10n.tagsFind,
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      if (_camera)
                        ListTile(
                          key: Keys.captureAlbumNone,
                          title: Text(l10n.pickerNoTags),
                          trailing: _selected.isEmpty
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => setState(_selected.clear),
                        ),
                      for (final entry in entries)
                        CheckboxListTile(
                          key: _camera
                              ? Keys.captureAlbumChoose(entry.key)
                              : Keys.albumChoose(entry.key),
                          title: Tooltip(
                            message: entry.value,
                            excludeFromSemantics: true,
                            child: Text(
                              entry.value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          subtitle: _camera
                              ? null
                              : Text(
                                  l10n.pickerAlreadyTagged(
                                    widget.captures!
                                        .where(
                                          (name) => widget.catalog
                                              .details(name)
                                              .albums
                                              .contains(entry.key),
                                        )
                                        .length,
                                    widget.captures!.length,
                                  ),
                                ),
                          value: _selected.contains(entry.key),
                          onChanged: (selected) => setState(() {
                            selected!
                                ? _selected.add(entry.key)
                                : _selected.remove(entry.key);
                          }),
                        ),
                      if (entries.isEmpty)
                        ListTile(title: Text(l10n.tagsNoMatch)),
                      if (!widget.remove)
                        ListTile(
                          key: _camera
                              ? Keys.captureAlbumCreate
                              : Keys.tagPickerCreate,
                          leading: const Icon(Icons.add),
                          // Offer the typed name directly instead of a duplicate error.
                          title: Text(
                            typed.isNotEmpty && !exact
                                ? l10n.tagsCreateNamed(typed)
                                : l10n.tagsCreate,
                          ),
                          onTap: () => editLibraryName(
                            context,
                            title: l10n.tagsCreate,
                            initial: _search.text,
                            save: (name) async {
                              final id = await widget.catalog.createAlbum(name);
                              if (mounted) {
                                setState(() {
                                  _selected.add(id);
                                  _search.clear();
                                });
                              }
                            },
                          ),
                        ),
                      if (_camera)
                        ListTile(
                          key: Keys.captureAlbumManage,
                          leading: const Icon(Icons.sell_outlined),
                          title: Text(l10n.pickerManage),
                          onTap: widget.onManage,
                        ),
                      if (stale)
                        ListTile(
                          title: Text(l10n.pickerStale),
                          trailing: TextButton(
                            onPressed: () => setState(
                              () => _selected.removeWhere(
                                (id) => !widget.catalog.albums.containsKey(id),
                              ),
                            ),
                            child: Text(l10n.pickerReview),
                          ),
                        ),
                    ],
                  ),
                ),
                // Pinned below the list, so Apply never scrolls away.
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    key: Keys.tagPickerApply,
                    onPressed: stale || (!_camera && _selected.isEmpty)
                        ? null
                        : () => Navigator.pop(context, {..._selected}),
                    child: Text(
                      _camera
                          ? l10n.pickerUse(_selected.length)
                          : widget.remove
                          ? l10n.pickerRemoveCount(_selected.length)
                          : l10n.pickerAddCount(_selected.length),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
