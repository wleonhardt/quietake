import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_controller.dart';
import '../privacy/privacy_scope.dart';
import '../vault/vault.dart';
import 'item.dart';
import 'redact_screen.dart';
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
  List<Rect> _regions = const [];
  String Function(AppLocalizations)? _error;
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

  bool get _canRedact =>
      widget.items.length == 1 && !widget.items.single.isVideo;

  Future<void> _redact() async {
    final item = widget.items.single;
    setState(() => _error = null);
    try {
      final bytes = await widget.vault.readAll(item.file);
      if (!mounted) return;
      final chosen = await Navigator.push<List<Rect>>(
        context,
        MaterialPageRoute(
          builder: (_) => RedactScreen(bytes: bytes, initial: _regions),
        ),
      );
      if (chosen != null && mounted) setState(() => _regions = chosen);
    } catch (_) {
      if (mounted) setState(() => _error = (l10n) => l10n.shareFailed);
    }
  }

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
        redactions: _regions.isEmpty
            ? const {}
            : {widget.items.single.name: _regions},
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
        () => _error = (_) => item == null
            ? error.message
            : '${title.isEmpty ? item.name : title}: ${error.message}',
      );
    } catch (_) {
      if (_active) {
        setState(() => _error = (l10n) => l10n.shareFailed);
      }
    } finally {
      if (_cancelled && mounted && ModalRoute.of(context)!.isCurrent) {
        Navigator.pop(context);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: Keys.shareDialog,
      scrollable: true,
      title: Text(
        widget.items.length == 1
            ? l10n.shareTitleOne
            : l10n.shareTitleMany(widget.items.length),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.shareWarning),
          if (_canRedact)
            OutlinedButton(
              key: Keys.shareRedact,
              onPressed: _busy ? null : _redact,
              child: Text(
                _regions.isEmpty
                    ? l10n.shareRedactButton
                    : l10n.shareRedactEdit(_regions.length),
              ),
            ),
          if (_regions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l10n.shareRedactNote),
            )
          else
            CheckboxListTile(
              key: Keys.shareStripLocation,
              contentPadding: EdgeInsets.zero,
              value: _stripLocation,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _stripLocation = value ?? true),
              title: Text(l10n.shareStripTitle),
              subtitle: Text(
                _stripLocation ? l10n.shareStripOn : l10n.shareStripOff,
              ),
            ),
          if (widget.items.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.shareLimits(
                  maxShareItems,
                  maxShareBatchBytes ~/ (1024 * 1024),
                ),
              ),
            ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            Text(
              l10n.shareProgress(_prepared, widget.items.length),
              key: Keys.shareProgress,
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!(l10n), key: Keys.shareError),
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
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: Keys.shareConfirm,
          onPressed: _busy ? null : _share,
          child: Text(l10n.shareChooseApp),
        ),
      ],
    );
  }
}
