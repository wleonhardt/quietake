import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import 'library_query.dart';

typedef LibraryView = ({MediaKind kind, bool favorites, LibrarySort sort});

Future<LibraryView?> chooseLibraryView(
  BuildContext context,
  LibraryView initial, {
  int Function(LibraryView view)? count,
}) {
  var value = initial;
  return showModalBottomSheet<LibraryView>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.viewTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in MediaKind.values)
                    ChoiceChip(
                      key: switch (kind) {
                        MediaKind.all => Keys.libraryAll,
                        MediaKind.photo => Keys.libraryPhotos,
                        MediaKind.video => Keys.libraryVideos,
                      },
                      label: Text(switch (kind) {
                        MediaKind.all => context.l10n.viewAll,
                        MediaKind.photo => context.l10n.viewPhotos,
                        MediaKind.video => context.l10n.viewVideos,
                      }),
                      selected: value.kind == kind,
                      onSelected: (_) => update(
                        () => value = (
                          kind: kind,
                          favorites: value.favorites,
                          sort: value.sort,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                key: Keys.libraryFavorites,
                title: Text(context.l10n.viewFavoritesOnly),
                value: value.favorites,
                onChanged: (checked) => update(
                  () => value = (
                    kind: value.kind,
                    favorites: checked!,
                    sort: value.sort,
                  ),
                ),
              ),
              PopupMenuButton<LibrarySort>(
                key: Keys.librarySort,
                initialValue: value.sort,
                onSelected: (sort) => update(
                  () => value = (
                    kind: value.kind,
                    favorites: value.favorites,
                    sort: sort,
                  ),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: LibrarySort.newest,
                    child: Text(context.l10n.viewNewest),
                  ),
                  PopupMenuItem(
                    key: Keys.librarySortOldest,
                    value: LibrarySort.oldest,
                    child: Text(context.l10n.viewOldest),
                  ),
                  PopupMenuItem(
                    value: LibrarySort.name,
                    child: Text(context.l10n.viewName),
                  ),
                ],
                child: ListTile(
                  leading: const Icon(Icons.sort),
                  title: Text(context.l10n.viewSort),
                  subtitle: Text(switch (value.sort) {
                    LibrarySort.newest => context.l10n.viewNewest,
                    LibrarySort.oldest => context.l10n.viewOldest,
                    LibrarySort.name => context.l10n.viewName,
                  }),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: Keys.libraryViewApply,
                onPressed: () => Navigator.pop(context, value),
                // The pending view's live count, so the choice is informed.
                child: Text(switch (count?.call(value)) {
                  null => context.l10n.viewApply,
                  final n => context.l10n.viewShowCount(n),
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      key: Keys.libraryViewReset,
                      onPressed: () => update(
                        () => value = (
                          kind: MediaKind.all,
                          favorites: false,
                          sort: LibrarySort.newest,
                        ),
                      ),
                      child: Text(context.l10n.viewReset),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
