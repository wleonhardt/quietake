import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

import '../crypto/vault_crypto.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import '../vault/master_key_store.dart';
import '../vault/vault.dart';
import 'portable_backup.dart';
import 'restore_transaction.dart';

const portableChannel = MethodChannel('quietake/backup');
bool _portableBusy = false;

class PortableScreen extends StatefulWidget {
  const PortableScreen({
    super.key,
    required this.store,
    this.session,
    this.onRestored,
  });
  final MasterKeyStore store;
  final Session? session;
  final VoidCallback? onRestored;
  @override
  State<PortableScreen> createState() => _PortableScreenState();
}

class _PortableScreenState extends State<PortableScreen>
    with WidgetsBindingObserver {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _recovery = TextEditingController();
  bool get _restoring => widget.session == null;
  bool _busy = false;
  double? _fraction;
  bool _cancelled = false;
  bool _preparing = false;
  bool _committing = false;
  String? _selected;
  // Kept as a selector so the text follows the language at build time.
  String Function(AppLocalizations)? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    if (!_busy && !_portableBusy) {
      unawaited(
        portableChannel.invokeMethod<void>('clear').catchError((Object _) {}),
      );
    }
    _pass.dispose();
    _confirm.dispose();
    _recovery.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final privacy = PrivacyScope.maybeOf(context);
    if (!_restoring && _preparing && privacy?.enabled == false) _cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _preparing && !_committing) {
      _cancel();
    }
  }

  void _cancel() {
    if (_committing) return;
    _cancelled = true;
    if (_busy) {
      unawaited(
        portableChannel.invokeMethod<void>('cancel').catchError((Object _) {}),
      );
    }
  }

  void _status(String Function(AppLocalizations) value) {
    if (mounted) setState(() => _result = value);
  }

  Future<void> _pick() async {
    if (_busy || _portableBusy) return;
    _portableBusy = true;
    setState(() {
      _busy = true;
      _result = (l10n) => l10n.portablePicking;
    });
    try {
      if (_selected != null) {
        // Each pick copies a new file; drop the previous private copy first.
        _selected = null;
        await portableChannel.invokeMethod<void>('clear');
      }
      _selected = await portableChannel.invokeMethod<String>('pick');
      _status(
        _selected == null
            ? (l10n) => l10n.portablePickCancelled
            : (l10n) => l10n.portablePicked,
      );
    } catch (_) {
      _status((l10n) => l10n.portableCopyFailed);
    } finally {
      _portableBusy = false;
      if (mounted) {
        setState(() => _busy = false);
      } else {
        try {
          await portableChannel.invokeMethod<void>('clear');
        } catch (_) {}
      }
    }
  }

  /// [dryRun] checks the selected ZIP with the recovery key and restores nothing.
  Future<void> _run({bool dryRun = false}) async {
    if (_busy) return;
    if (_portableBusy) {
      _status((l10n) => l10n.portableStillFinishing);
      return;
    }
    if (dryRun && (_selected == null || _recovery.text.trim().isEmpty)) {
      _status((l10n) => l10n.portableNeedKey);
      return;
    }
    if (_restoring &&
        !dryRun &&
        (_selected == null ||
            _pass.text.length < MasterKeyStore.minPasscodeLength ||
            _pass.text != _confirm.text)) {
      _status((l10n) => l10n.portableNeedPasscode);
      return;
    }
    _portableBusy = true;
    setState(() {
      _busy = true;
      _cancelled = false;
      _preparing = true;
      _result = (l10n) => l10n.portablePreparing;
    });
    SecureKey? key;
    Directory? staged;
    Vault? temporary;
    try {
      if (_restoring) {
        final transaction = RestoreTransaction(widget.store);
        await transaction.requireFresh();
        key = widget.store.importRecovery(_recovery.text);
        temporary = Vault(
          VaultCrypto(widget.store.sodium),
          key.copy(),
          Directory('${widget.store.dir.path}/vault'),
        );
        final root = Directory(
          '${(await getTemporaryDirectory()).path}/quietake-backup',
        );
        final source = File(_selected!);
        if (!(await source.resolveSymbolicLinks()).startsWith(
          '${await root.resolveSymbolicLinks()}/',
        )) {
          throw const FormatException('Expected private backup copy');
        }
        staged = await PortableBackup(temporary, key).stage(
          source,
          widget.store.dir,
          isCancelled: () => _cancelled,
          onProgress: (done, total) {
            _fraction = total == 0 ? null : done / total;
            _status((l10n) => l10n.portableChecking(done, total));
          },
        );
        _fraction = null;
        if (dryRun) {
          _status((l10n) => l10n.portableChecked);
          return;
        }
        await transaction.commit(
          staged,
          key,
          _pass.text,
          isCancelled: () => _cancelled,
          onProgress: (phase) => _status((_) => '$phase…'),
          onCommitting: () => _committing = true,
        );
        _status((l10n) => l10n.portableRestored);
        if (mounted) widget.onRestored?.call();
      } else {
        key = await widget.store.unlockWithPasscode(_pass.text);
        if (_cancelled) throw StateError('Backup cancelled');
        final root = await Directory(
          '${(await getTemporaryDirectory()).path}/quietake-backup',
        ).create(recursive: true);
        final output = File('${root.path}/Quietake-backup.zip');
        await PortableBackup(widget.session!.vault, key).export(
          output,
          isCancelled: () => _cancelled,
          onProgress: (done, total) {
            _fraction = total == 0 ? null : done / total;
            _status((l10n) => l10n.portableExporting(done, total));
          },
        );
        if (_cancelled) throw StateError('Backup cancelled');
        _preparing = false;
        final saved =
            await portableChannel.invokeMethod<bool>('save', {
              'path': output.path,
            }) ??
            false;
        _status(
          saved
              ? (l10n) => l10n.portableSaved
              : (l10n) => l10n.portableSaveCancelled,
        );
      }
    } on PasscodeLockedException catch (e) {
      _status((_) => e.toString());
    } on WrongPasscodeException {
      _status((l10n) => l10n.settingsWrongPasscode);
    } on BadRecoveryKeyException {
      _status((l10n) => l10n.portableBadKey);
    } catch (_) {
      _status(
        _cancelled
            ? (l10n) => l10n.portableCancelled
            : (l10n) => l10n.portableFailed,
      );
    } finally {
      key?.dispose();
      temporary?.dispose();
      if (staged != null && await staged.exists()) {
        await staged.delete(recursive: true);
      }
      try {
        await portableChannel.invokeMethod<void>('clear');
      } catch (_) {}
      _selected = null;
      _portableBusy = false;
      _preparing = false;
      _committing = false;
      _fraction = null;
      if (mounted) {
        _pass.clear();
        _confirm.clear();
        _recovery.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_committing,
      child: Scaffold(
        key: Keys.portableScreen,
        appBar: AppBar(
          title: Text(
            _restoring ? l10n.portableTitleRestore : l10n.portableTitleExport,
          ),
          actions: const [LockButton()],
        ),
        body: FormBody(
          children: [
            Text(
              _restoring ? l10n.portableIntroRestore : l10n.portableIntroExport,
            ),
            const SizedBox(height: 20),
            if (_restoring)
              OutlinedButton.icon(
                key: Keys.portablePick,
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.portableChoose),
              ),
            if (_restoring) const SizedBox(height: 16),
            if (_restoring)
              TextField(
                key: Keys.portableRecovery,
                controller: _recovery,
                onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
                enabled: !_busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(labelText: l10n.recoveryKeyLabel),
              ),
            if (_restoring) const SizedBox(height: 16),
            TextField(
              key: Keys.portablePasscode,
              controller: _pass,
              onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _restoring
                    ? l10n.newPasscodeLabel
                    : l10n.currentPasscodeLabel,
              ),
            ),
            if (_restoring) const SizedBox(height: 16),
            if (_restoring)
              TextField(
                key: Keys.portableConfirm,
                controller: _confirm,
                onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
                enabled: !_busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.confirmNewPasscodeLabel,
                ),
              ),
            const SizedBox(height: 20),
            if (_busy)
              LinearProgressIndicator(
                key: Keys.portableProgress,
                value: _fraction,
              ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_result!(l10n), key: Keys.portableResult),
              ),
              const SizedBox(height: 12),
            ],
            if (_restoring) ...[
              OutlinedButton(
                key: Keys.portableCheck,
                onPressed: _busy ? null : () => _run(dryRun: true),
                child: Text(l10n.portableCheckOnly),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: Keys.portableStart,
              onPressed: _busy ? null : _run,
              child: Text(
                _restoring
                    ? l10n.portableRestoreButton
                    : l10n.portableCreateButton,
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              key: Keys.portableDetails,
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.portableLimitsTitle),
              children: [Text(l10n.portableLimitsBody)],
            ),
            if (_busy)
              OutlinedButton(
                key: Keys.portableCancel,
                onPressed: _committing ? null : _cancel,
                child: Text(l10n.portableCancelPrep),
              ),
          ],
        ),
      ),
    );
  }
}
