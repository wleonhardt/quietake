import 'package:flutter/material.dart';

import '../keys.dart';
import 'tag_sort.dart';
import 'private_catalog.dart';

Future<String?> chooseMergeTarget(
  BuildContext context,
  PrivateCatalog catalog,
  String source,
) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .85,
  ),
  builder: (_) => _MergeTarget(catalog: catalog, source: source),
);

class _MergeTarget extends StatefulWidget {
  const _MergeTarget({required this.catalog, required this.source});
  final PrivateCatalog catalog;
  final String source;
  @override
  State<_MergeTarget> createState() => _MergeTargetState();
}

class _MergeTargetState extends State<_MergeTarget> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: ListenableBuilder(
        listenable: widget.catalog,
        builder: (context, _) {
          final entries = sortedTags(
            widget.catalog.albums,
            _search.text,
            exclude: widget.source,
          );
          return ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Choose the tag to keep'),
                trailing: IconButton(
                  key: Keys.tagMergeClose,
                  tooltip: 'Cancel merge',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: Keys.tagMergeSearch,
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Find destination tag',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              if (entries.isEmpty)
                const ListTile(title: Text('No matching tags')),
              for (final entry in entries)
                ListTile(
                  key: Keys.tagMergeTarget(entry.key),
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(context, entry.key),
                ),
            ],
          );
        },
      ),
    ),
  );
}
