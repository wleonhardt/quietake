import 'package:flutter/material.dart';

import '../keys.dart';
import '../privacy/privacy_controller.dart';
import '../privacy/privacy_scope.dart';
import '../vault/vault.dart';
import 'item.dart';
import 'share_media.dart';

Future<void> showShareCopies(
  BuildContext context,
  Vault vault,
  List<VaultItem> selected, {
  required Rect origin,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ShareDialog(
    vault: vault,
    items: List.unmodifiable(selected),
    origin: origin,
  ),
);

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({
    required this.vault,
    required this.items,
    required this.origin,
  });
  final Vault vault;
  final List<VaultItem> items;
  final Rect origin;
  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  bool _busy = false;
  bool _cancelled = false;
  int _prepared = 0;
  bool _stripLocation = true;
  String? _error;
  PrivacyController? _privacy;

  void _onPrivacy() {
    if (!_privacy!.enabled) _cancelled = true;
  }

  @override
  void dispose() {
    _cancelled = true;
    _privacy?.removeListener(_onPrivacy);
    super.dispose();
  }

  bool get _active =>
      mounted &&
      !_cancelled &&
      TickerMode.valuesOf(context).enabled &&
      ModalRoute.of(context)!.isCurrent &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final privacy = PrivacyScope.maybeOf(context);
    if (privacy?.enabled == true && _privacy == null) {
      _privacy = privacy!..addListener(_onPrivacy);
    }
    try {
      await shareMediaCopies(
        widget.vault,
        widget.items,
        origin: widget.origin,
        stripLocation: _stripLocation,
        isActive: () => _active,
        onProgress: (prepared, _) {
          if (mounted) setState(() => _prepared = prepared);
        },
      );
      if (mounted && ModalRoute.of(context)!.isCurrent) Navigator.pop(context);
    } on SharePreparationException catch (error) {
      if (!_active) return;
      final item = error.item;
      final title = item == null
          ? ''
          : widget.vault.catalog.details(item.name).title;
      setState(
        () => _error = item == null
            ? error.message
            : '${title.isEmpty ? item.name : title}: ${error.message}',
      );
    } catch (_) {
      if (_active) {
        setState(
          () => _error = 'Could not share. Another share may still be finishing. Try again.',
        );
      }
    } finally {
      if (_cancelled && mounted && ModalRoute.of(context)!.isCurrent) {
        Navigator.pop(context);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: Keys.shareDialog,
    scrollable: true,
    title: Text(
      widget.items.length == 1
          ? 'Share a copy?'
          : 'Share ${widget.items.length} copies?',
    ),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'The app you choose receives unencrypted copies and may keep them.',
        ),
        CheckboxListTile(
          key: Keys.shareStripLocation,
          contentPadding: EdgeInsets.zero,
          value: _stripLocation,
          onChanged: _busy
              ? null
              : (value) => setState(() => _stripLocation = value ?? true),
          title: const Text('Remove GPS from JPEG photo copies'),
          subtitle: Text(
            _stripLocation
                ? 'JPEG EXIF GPS is removed. Other metadata and PNG/video copies stay unchanged.'
                : 'Copies keep all original metadata, including location if present.',
          ),
        ),
        if (widget.items.length > 1)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Up to $maxShareItems captures and ${maxShareBatchBytes ~/ (1024 * 1024)} MiB per batch.',
            ),
          ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          Text(
            'Preparing $_prepared of ${widget.items.length}',
            key: Keys.shareProgress,
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, key: Keys.shareError),
          ),
      ],
    ),
    actions: [
      TextButton(
        key: Keys.shareCancel,
        onPressed: () {
          _cancelled = true;
          Navigator.pop(context);
        },
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: Keys.shareConfirm,
        onPressed: _busy ? null : _share,
        child: const Text('Choose app'),
      ),
    ],
  );
}
