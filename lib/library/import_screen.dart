import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../crypto/share_bundle.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import 'folder_import.dart';
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
  var _handled = 0;
  PickedFolder? _folder;
  FolderImportSummary? _folderSummary;
  String Function(AppLocalizations)? _error;

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
      unawaited(_folder?.cancel().catchError((Object _) {}));
    }
  }

  Future<void> _pick({bool share = false}) async {
    if (_busy) return;
    if (_importInProgress) {
      setState(() => _error = (l10n) => l10n.importBusyPrevious);
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
      final raw =
          await importChannel.invokeListMethod<dynamic>(
            share ? 'pickShare' : 'pick',
          ) ??
          [];
      var inputs = raw.map((entry) {
        final value = entry as Map;
        return ImportInput(
          name: value['name'] as String,
          path: value['path'] as String?,
          error: value['error'] as String?,
        );
      }).toList();
      final root = await getTemporaryDirectory();
      if (share) inputs = await _openShare(inputs, root);
      if (mounted) setState(() => _total = inputs.length);
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
              ? (l10n) => l10n.importOpenFailed
              : (l10n) => l10n.importStoppedEarly,
        );
      }
    } finally {
      try {
        await importChannel.invokeMethod<void>('clear');
      } catch (_) {
        if (mounted) {
          setState(() => _error = (l10n) => l10n.importCleanupFailed);
        }
      }
      _importInProgress = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Decrypts one picked share bundle into the private import folder and
  /// returns its photos and videos. Returns nothing when the person backs out
  /// or the bundle cannot be opened; the reason then shows on screen.
  Future<List<ImportInput>> _openShare(
    List<ImportInput> inputs,
    Directory root,
  ) async {
    if (inputs.isEmpty || inputs.first.error != null) return inputs;
    final passphrase = await _askPassphrase();
    if (passphrase == null) return [];
    final dest = Directory('${root.path}/quietake-import/opened');
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    dest.createSync(recursive: true);
    try {
      final names = await ShareBundle(widget.session.vault.crypto.sodium)
          .extract(File(inputs.first.path!), passphrase, dest);
      return [
        for (final name in names)
          ImportInput(name: name, path: '${dest.path}/$name'),
      ];
    } on ShareBundleException {
      if (mounted) setState(() => _error = (l10n) => l10n.importShareFailed);
      return [];
    }
  }

  Future<String?> _askPassphrase() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.importSharePassphraseTitle),
        content: TextField(
          key: Keys.importSharePassphrase,
          controller: controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.l10n.importSharePassphraseLabel,
          ),
        ),
        actions: [
          TextButton(
            key: Keys.importShareCancel,
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: Keys.importShareOpen,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.importShareOpenButton),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  /// Copies the supported files of one folder in chunks. The summary stays on
  /// screen; running it again on the same folder resumes where it stopped.
  Future<void> _pickFolder() async {
    if (_busy) return;
    if (_importInProgress) {
      setState(() => _error = (l10n) => l10n.importBusyPrevious);
      return;
    }
    _importInProgress = true;
    setState(() {
      _busy = true;
      _cancelled = false;
      _error = null;
      _results.clear();
      _folderSummary = null;
      _total = 0;
      _handled = 0;
    });
    try {
      final folder = await PickedFolder.pick();
      if (folder == null) return;
      _folder = folder;
      final root = await getTemporaryDirectory();
      final summary =
          await FolderImport(
            widget.session.vault,
            Directory('${root.path}/quietake-import'),
          ).run(
            folder,
            isCancelled: () => _cancelled,
            onProgress: (handled, total) {
              widget.session.sync.sync();
              if (mounted) {
                setState(() {
                  _handled = handled;
                  _total = total;
                });
              }
            },
          );
      if (mounted) setState(() => _folderSummary = summary);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = (_) => error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = (l10n) => l10n.importFolderStopped);
      }
    } finally {
      try {
        await _folder?.release();
        await importChannel.invokeMethod<void>('clear');
      } catch (_) {
        if (mounted) {
          setState(() => _error = (l10n) => l10n.importCleanupFailed);
        }
      }
      _folder = null;
      _importInProgress = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  String _folderText(AppLocalizations l10n, FolderImportSummary s) {
    final unfinished = s.failed + s.cancelled;
    final summary = [
      l10n.importImported(s.imported),
      if (s.duplicates > 0) l10n.importDuplicates(s.duplicates),
      if (s.alreadyDone > 0) l10n.importAlreadyDone(s.alreadyDone),
      if (s.failed > 0) l10n.importFailedCount(s.failed),
      if (s.cancelled > 0) l10n.importNotStarted(s.cancelled),
    ].join(' · ');
    return unfinished > 0
        ? l10n.importSummaryContinue(summary)
        : l10n.importSummaryEnd(summary);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.galleryImportCopies),
        actions: const [LockButton()],
      ),
      body: FormBody(
        children: [
          Text(l10n.importIntro),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: Keys.importChoose,
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(l10n.importChooseFiles),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: Keys.importFolder,
            onPressed: _busy ? null : _pickFolder,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(l10n.importChooseFolder),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: Keys.importShare,
            onPressed: _busy ? null : () => _pick(share: true),
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(l10n.importOpenShare),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            key: Keys.importDetails,
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.importSupportedTitle),
            children: [Text(l10n.importSupportedBody)],
          ),
          if (_busy) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: LinearProgressIndicator(
                key: Keys.importProgress,
                value: _total == 0
                    ? null
                    : (_folder != null ? _handled : _results.length) / _total,
              ),
            ),
            TextButton(
              key: Keys.importCancel,
              onPressed: _cancelled ? null : () => setState(_cancel),
              child: Text(
                _cancelled ? l10n.importCancelling : l10n.importCancelRemaining,
              ),
            ),
          ],
          if (_busy && _folder != null && _total > 0)
            Text(
              l10n.importFolderCount(_handled, _total),
              key: Keys.importFolderCount,
            ),
          if (_error != null) Text(_error!(l10n), key: Keys.importError),
          if (_folderSummary != null)
            Text(
              _folderText(l10n, _folderSummary!),
              key: Keys.importFolderSummary,
            ),
          if (_results.isNotEmpty) ...[
            Text(
              [
                l10n.importImported(
                  _results
                      .where((r) => r.status == ImportStatus.imported)
                      .length,
                ),
                l10n.importDuplicates(
                  _results
                      .where((r) => r.status == ImportStatus.duplicate)
                      .length,
                ),
                if (_results.any((r) => r.status == ImportStatus.failed))
                  l10n.importFailedCount(
                    _results
                        .where((r) => r.status == ImportStatus.failed)
                        .length,
                  ),
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
}
