import 'dart:io';

import 'package:flutter/material.dart';

import '../gallery/item.dart';
import '../gallery/preview.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../session.dart';

/// A small preview of a capture, or [fallback] while it loads or is missing.
class CaptureThumb extends StatefulWidget {
  const CaptureThumb({
    super.key,
    required this.session,
    required this.name,
    required this.fallback,
    this.size = 48,
  });
  final Session session;
  final String name;
  final Widget fallback;
  final double size;
  @override
  State<CaptureThumb> createState() => _CaptureThumbState();
}

class _CaptureThumbState extends State<CaptureThumb> {
  late final VaultItem _item = VaultItem(
    File('${widget.session.vault.dir.path}/${widget.name}'),
  );
  late final Future<MediaPreview> _preview = widget.session.previews.get(_item);

  @override
  void dispose() {
    widget.session.previews.release(_item);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: FutureBuilder<MediaPreview>(
        future: _preview,
        builder: (context, snap) => snap.hasData
            ? RawImage(
                image: snap.data!.image,
                fit: BoxFit.cover,
                width: widget.size,
                height: widget.size,
              )
            : Center(child: widget.fallback),
      ),
    ),
  );
}

/// Lets the user pick one of [names] as the cover; null when cancelled.
Future<String?> chooseTagCover(
  BuildContext context,
  Session session,
  List<String> names,
) => showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.coverChooseTitle),
    content: SizedBox(
      width: double.maxFinite,
      child: names.isEmpty
          ? Text(context.l10n.coverEmpty)
          : GridView.count(
              key: Keys.tagCoverGrid,
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final name in names)
                  Semantics(
                    button: true,
                    label: context.l10n.coverUse,
                    child: InkWell(
                      key: Keys.tagCoverPick(name),
                      onTap: () => Navigator.pop(context, name),
                      child: CaptureThumb(
                        session: session,
                        name: name,
                        size: 96,
                        fallback: const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
    ],
  ),
);
