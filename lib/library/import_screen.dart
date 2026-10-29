import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../keys.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import 'import_media.dart';

bool _importInProgress = false;

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.session});
  final Session session;
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _results = <ImportResult>[];
  var _busy = false;
  var _cancelled = false;
  var _total = 0;
  String? _error;

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    _cancelled = true;
    if (_busy) {
      unawaited(
        importChannel.invokeMethod<void>('cancel').catchError((Object _) {}),
      );
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    if (_importInProgress) {
      setState(
        () => _error = 'Previous import is finishing. Try again shortly.',
      );
      return;
    }
    _importInProgress = true;
    setState(() {
      _busy = true;
      _cancelled = false;
      _error = null;
      _results.clear();
    });
    try {
      final raw = await importChannel.invokeListMethod<dynamic>('pick') ?? [];
      final inputs = raw.map((entry) {
        final value = entry as Map;
        return ImportInput(
          name: value['name'] as String,
          path: value['path'] as String?,
          error: value['error'] as String?,
        );
      }).toList();
      if (mounted) setState(() => _total = inputs.length);
      final root = await getTemporaryDirectory();
      await MediaImporter(
        widget.session.vault,
        Directory('${root.path}/quietake-import'),
      ).run(
        inputs,
        isCancelled: () => _cancelled,
        onResult: (result) {
          if (result.status == ImportStatus.imported) {
            widget.session.sync.sync();
          }
          if (mounted) setState(() => _results.add(result));
        },
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _results.isEmpty
              ? 'Could not open import. Check storage and try again.'
              : 'Import stopped early. Copies listed as imported are saved.',
        );
      }
    } finally {
      try {
        await importChannel.invokeMethod<void>('clear');
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Temporary cleanup failed. Restart Quietake before trying again.',
          );
        }
      }
      _importInProgress = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Import copies'),
      actions: const [LockButton()],
    ),
    body: FormBody(
      children: [
        const Text(
          'Copy photos and videos from Files into your Library. Originals stay unchanged, including location and other metadata. Nothing is deleted or shared.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: Keys.importChoose,
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Choose files'),
        ),
        const SizedBox(height: 12),
        const ExpansionTile(
          key: Keys.importDetails,
          tilePadding: EdgeInsets.zero,
          title: Text('Supported files and limits'),
          children: [
            Text(
              'JPEG, PNG or playable MP4. Up to 20 files and 512 MiB total; photos up to 32 MiB and 64 MP. TV playback depends on codecs. Imports use the date added. Selected copies may finish encrypting while Quietake is locked.',
            ),
          ],
        ),
        if (_busy) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: LinearProgressIndicator(
              key: Keys.importProgress,
              value: _total == 0 ? null : _results.length / _total,
            ),
          ),
          TextButton(
            key: Keys.importCancel,
            onPressed: _cancelled ? null : () => setState(_cancel),
            child: Text(
              _cancelled
                  ? 'Cancelling after current file…'
                  : 'Cancel remaining',
            ),
          ),
        ],
        if (_error != null) Text(_error!, key: Keys.importError),
        if (_results.isNotEmpty) ...[
          Text(
            [
              '${_results.where((r) => r.status == ImportStatus.imported).length} imported',
              '${_results.where((r) => r.status == ImportStatus.duplicate).length} duplicates skipped',
              if (_results.any((r) => r.status == ImportStatus.failed))
                '${_results.where((r) => r.status == ImportStatus.failed).length} failed',
            ].join(' · '),
            key: Keys.importSummary,
          ),
          for (final result in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (result.status) {
                  ImportStatus.imported => Icons.check_circle_outline,
                  ImportStatus.duplicate => Icons.copy_outlined,
                  ImportStatus.failed => Icons.error_outline,
                  ImportStatus.cancelled => Icons.cancel_outlined,
                },
                color: switch (result.status) {
                  ImportStatus.imported => Theme.of(
                    context,
                  ).colorScheme.primary,
                  ImportStatus.failed => Theme.of(context).colorScheme.error,
                  _ => Theme.of(context).colorScheme.onSurfaceVariant,
                },
              ),
              title: Text(
                result.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(result.message),
            ),
        ],
      ],
    ),
  );
}
