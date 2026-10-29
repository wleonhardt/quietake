import 'package:flutter/material.dart';

import '../keys.dart';
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
              Text('View', style: Theme.of(context).textTheme.titleLarge),
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
                        MediaKind.all => 'All',
                        MediaKind.photo => 'Photos',
                        MediaKind.video => 'Videos',
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
                title: const Text('Favorites only'),
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
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: LibrarySort.newest,
                    child: Text('Newest first'),
                  ),
                  PopupMenuItem(
                    key: Keys.librarySortOldest,
                    value: LibrarySort.oldest,
                    child: Text('Oldest first'),
                  ),
                  PopupMenuItem(value: LibrarySort.name, child: Text('Name')),
                ],
                child: ListTile(
                  leading: const Icon(Icons.sort),
                  title: const Text('Sort'),
                  subtitle: Text(switch (value.sort) {
                    LibrarySort.newest => 'Newest first',
                    LibrarySort.oldest => 'Oldest first',
                    LibrarySort.name => 'Name',
                  }),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: Keys.libraryViewApply,
                onPressed: () => Navigator.pop(context, value),
                // The pending view's live count, so the choice is informed.
                child: Text(switch (count?.call(value)) {
                  null => 'Apply view',
                  1 => 'Show 1 capture',
                  final n => 'Show $n captures',
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
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
                      child: const Text('Reset'),
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
