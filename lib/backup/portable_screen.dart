import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

import '../crypto/vault_crypto.dart';
import '../keys.dart';
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
  String _result = '';

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

  void _status(String value) {
    if (mounted) setState(() => _result = value);
  }

  Future<void> _pick() async {
    if (_busy || _portableBusy) return;
    _portableBusy = true;
    setState(() {
      _busy = true;
      _result = 'Choose an encrypted ZIP in Files.';
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
            ? 'Selection cancelled.'
            : 'Backup selected. Enter its recovery key and a new passcode.',
      );
    } catch (_) {
      _status('Could not copy backup. Check storage and try again.');
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

  Future<void> _run() async {
    if (_busy) return;
    if (_portableBusy) {
      _status('Previous backup is finishing. Try again shortly.');
      return;
    }
    if (_restoring &&
        (_selected == null ||
            _pass.text.length < MasterKeyStore.minPasscodeLength ||
            _pass.text != _confirm.text)) {
      _status(
        'Choose a backup and confirm a passcode of at least six characters.',
      );
      return;
    }
    _portableBusy = true;
    setState(() {
      _busy = true;
      _cancelled = false;
      _preparing = true;
      _result = 'Preparing encrypted backup…';
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
            _status('Checking encrypted files: $done of $total…');
          },
        );
        _fraction = null;
        await transaction.commit(
          staged,
          key,
          _pass.text,
          isCancelled: () => _cancelled,
          onProgress: (phase) => _status('$phase…'),
          onCommitting: () => _committing = true,
        );
        _status(
          'Vault restored. Use your new passcode once to enable biometric unlock.',
        );
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
            _status('Preparing encrypted files: $done of $total…');
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
              ? 'Encrypted backup saved. Keep its recovery key separately.'
              : 'Save cancelled. Vault originals kept.',
        );
      }
    } on WrongPasscodeException {
      _status('Wrong passcode. Try again.');
    } on BadRecoveryKeyException {
      _status('Enter the recovery key saved for this backup.');
    } catch (_) {
      _status(
        _cancelled ? 'Cancelled. Vault originals kept.' : 'Could not restore or save backup. Check its key, file, available storage and empty-vault requirement.',
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_committing,
    child: Scaffold(
      key: Keys.portableScreen,
      appBar: AppBar(
        title: Text(
          _restoring ? 'Restore encrypted backup' : 'Portable backup',
        ),
        actions: const [LockButton()],
      ),
      body: FormBody(
        children: [
          Text(
            _restoring
                ? 'Restore only into a fresh empty vault. Your recovery key opens the ZIP and encrypted captures. Existing libraries cannot be merged.'
                : 'Save an encrypted ZIP of captures and organization. Your existing recovery key opens it; keep that key separately. No credentials or keyfiles are included.',
          ),
          const SizedBox(height: 20),
          if (_restoring)
            OutlinedButton.icon(
              key: Keys.portablePick,
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose backup ZIP'),
            ),
          if (_restoring) const SizedBox(height: 16),
          if (_restoring)
            TextField(
              key: Keys.portableRecovery,
              controller: _recovery,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Recovery key'),
            ),
          if (_restoring) const SizedBox(height: 16),
          TextField(
            key: Keys.portablePasscode,
            controller: _pass,
            enabled: !_busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _restoring ? 'New passcode' : 'Current passcode',
            ),
          ),
          if (_restoring) const SizedBox(height: 16),
          if (_restoring)
            TextField(
              key: Keys.portableConfirm,
              controller: _confirm,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Confirm new passcode',
              ),
            ),
          const SizedBox(height: 20),
          if (_busy)
            LinearProgressIndicator(
              key: Keys.portableProgress,
              value: _fraction,
            ),
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_result, key: Keys.portableResult),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: Keys.portableStart,
            onPressed: _busy ? null : _run,
            child: Text(
              _restoring ? 'Restore empty vault' : 'Create encrypted ZIP',
            ),
          ),
          const SizedBox(height: 12),
          const ExpansionTile(
            key: Keys.portableDetails,
            tilePadding: EdgeInsets.zero,
            title: Text('Backup limits and storage'),
            children: [
              Text(
                'Up to 10,000 captures and 2 GiB per ZIP. Preparation needs private temporary storage. Vault originals stay unchanged. No credentials or keyfiles are included.',
              ),
            ],
          ),
          if (_busy)
            OutlinedButton(
              key: Keys.portableCancel,
              onPressed: _committing ? null : _cancel,
              child: const Text('Cancel preparation'),
            ),
        ],
      ),
    ),
  );
}
