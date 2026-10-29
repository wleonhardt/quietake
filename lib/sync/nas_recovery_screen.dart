import 'package:flutter/material.dart';

import '../keys.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../privacy/privacy_controller.dart';
import '../session.dart';
import '../vault/backup_passphrase.dart';
import '../vault/master_key_store.dart';
import 'background_uploads.dart';
import 'nas_recovery.dart';
import 'sync_settings.dart';
import 'webdav_client.dart';

class NasRecoveryScreen extends StatefulWidget {
  const NasRecoveryScreen({
    super.key,
    required this.store,
    this.session,
    this.onRestored,
  });
  final MasterKeyStore store;
  final Session? session;
  final VoidCallback? onRestored;
  @override
  State<NasRecoveryScreen> createState() => _NasRecoveryScreenState();
}

class _NasRecoveryScreenState extends State<NasRecoveryScreen>
    with WidgetsBindingObserver {
  final _url = TextEditingController(),
      _user = TextEditingController(),
      _password = TextEditingController();
  final _pin = TextEditingController(), _pinConfirm = TextEditingController();
  final _phrase = TextEditingController(),
      _phraseConfirm = TextEditingController();
  bool _busy = false, _cancelled = false, _committing = false, _visible = false;
  String _result = '';
  int _phraseEpoch = 0, _operationEpoch = 0;
  bool _confirming = false;
  PrivacyController? _privacy;
  WebDavClient? _client;
  bool get _restoring => widget.session == null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _cancel() {
    if (!_busy || _committing) return;
    _cancelled = true;
    _client?.close();
    widget.session?.sync.cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final privacy = PrivacyScope.maybeOf(context);
    if (privacy != _privacy) {
      _privacy?.removeListener(_privacyChanged);
      _privacy = privacy;
      _privacy?.addListener(_privacyChanged);
    }
    _privacyChanged();
  }

  void _invalidateOperation() {
    ++_operationEpoch;
    _cancel();
    _pin.clear();
    _pinConfirm.clear();
    _visible = false;
  }

  void _privacyChanged() {
    if (!_restoring && _privacy?.enabled == false) _invalidateOperation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _invalidateOperation();
      ++_phraseEpoch;
      _pin.clear();
      _pinConfirm.clear();
      if (_restoring) {
        _phrase.clear();
        _password.clear();
      }
      // The root lock protects drafts while a user saves generated words in a
      // password manager. Never reveal a late generation after backgrounding.
      if (mounted) setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _privacy?.removeListener(_privacyChanged);
    ++_operationEpoch;
    _cancel();
    for (final field in [
      _url,
      _user,
      _password,
      _pin,
      _pinConfirm,
      _phrase,
      _phraseConfirm,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void _status(String value) {
    if (mounted) setState(() => _result = value);
  }

  Future<void> _generate() async {
    final epoch = ++_phraseEpoch;
    try {
      final value = await BackupPassphrase.generate(widget.store.sodium);
      if (mounted && !_busy && epoch == _phraseEpoch) {
        setState(() {
          _phrase.text = value;
          _phraseConfirm.clear();
          _visible = true;
        });
      }
    } catch (_) {
      _status('Could not generate a passphrase. Try again.');
    }
  }

  Future<bool> _confirm(bool disable) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(
            disable
                ? 'Disable passphrase recovery?'
                : 'Save backup passphrase?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                disable
                    ? 'Removes the current recovery file from the saved NAS folder. Captures stay. Old server snapshots may still accept an earlier passphrase. Keep your independent recovery key.'
                    : 'Creates or replaces recovery in the saved NAS folder. Save the new passphrase separately. Old server snapshots may still accept an earlier passphrase; this does not rotate your vault key.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: disable
                        ? Keys.nasDisableConfirm
                        : Keys.nasChangeConfirm,
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      disable ? 'Disable recovery' : 'Save passphrase',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ) ??
      false;

  Future<void> _run({bool disable = false}) async {
    if (_busy || _confirming || !_restoring && _privacy?.enabled == false) {
      return;
    }
    final epoch = _operationEpoch;
    FocusManager.instance.primaryFocus?.unfocus();
    final pin = _pin.text, phrase = _phrase.text;
    final settings = SyncSettings(
      url: _url.text.trim(),
      username: _user.text.trim(),
      password: _password.text,
    );
    if (!disable) {
      try {
        BackupPassphrase.validate(phrase);
      } on FormatException catch (e) {
        _status(e.message);
        return;
      }
      if (phrase == pin) {
        _status('Use a separate backup passphrase, not your local passcode.');
        return;
      }
      if (_restoring) {
        if (pin.length < MasterKeyStore.minPasscodeLength ||
            pin != _pinConfirm.text) {
          _status(
            'Choose and confirm a new passcode of at least six characters.',
          );
          return;
        }
        if (!settings.isConfigured) {
          _status('Enter your saved NAS folder, username and password.');
          return;
        }
        try {
          settings.client().close(); // The URL rule lives in the client.
        } on FormatException catch (e) {
          _status(e.message);
          return;
        }
      } else if (phrase != _phraseConfirm.text) {
        _status('Backup passphrases do not match.');
        return;
      }
    }
    if (!_restoring) {
      _confirming = true;
      try {
        if (!await _confirm(disable)) return;
      } finally {
        _confirming = false;
      }
    }
    if (!mounted || epoch != _operationEpoch) return;
    setState(() {
      _busy = true;
      _cancelled = false;
      _visible = false;
      _result = _restoring
          ? 'Checking encrypted NAS backup…'
          : 'Checking saved NAS recovery…';
    });
    try {
      if (_restoring) {
        _client = settings.client();
        await BackgroundUploads().reset();
        await NasRecovery(
          widget.store,
          _client!,
          isCancelled: () => _cancelled,
        ).restore(
          phrase,
          pin,
          onProgress: (phase) => _status('$phase…'),
          onCommitting: () => _committing = true,
        );
        // Recovery is already committed. A protected connection-save failure must
        // not strand Setup or overwrite the newly restored key on the next attempt,
        // but the user has to hear that backup is not connected.
        try {
          await settings.save();
        } catch (_) {
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Vault restored'),
                content: const Text(
                  'The NAS connection could not be saved. Your captures are '
                  'restored; add the connection again in Settings to resume '
                  'backups.',
                ),
                actions: [
                  FilledButton(
                    key: Keys.nasRestoreUnsavedOk,
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
          }
        }
        if (mounted) widget.onRestored!();
      } else {
        final session = widget.session!;
        await session.sync.recoveryOperation(
          (client) => NasRecovery(
            widget.store,
            client,
            isCancelled: () => _cancelled || session.sync.recoveryCancelled,
          ).change(session.vault, pin, disable ? null : phrase),
        );
        _status(
          disable ? 'Passphrase recovery disabled. Captures kept.' : 'Backup passphrase saved. Keep it and your recovery key separately.',
        );
      }
    } on WrongPasscodeException {
      _status('Wrong current passcode. Try again.');
    } catch (_) {
      _status(
        _cancelled
            ? 'Cancelled. Originals kept.'
            : _restoring
            ? 'Could not restore. Check the NAS connection, backup passphrase and empty-vault requirement. Originals kept.'
            : 'Could not change recovery. Check saved NAS backup, supported recovery file and server compatibility. Sync first, then retry. Originals kept.',
      );
    } finally {
      _client?.close();
      _client = null;
      _committing = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _pin.clear();
          _pinConfirm.clear();
          _phrase.clear();
          _phraseConfirm.clear();
          _password.clear();
          _visible = false;
        });
      }
    }
  }

  Widget _field(
    Key key,
    TextEditingController controller,
    String label, {
    bool secret = true,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: key,
      controller: controller,
      enabled: !_busy,
      obscureText: secret,
      keyboardType: keyboardType,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_committing,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_restoring ? 'Restore from NAS' : 'Backup passphrase'),
        actions: const [LockButton()],
      ),
      body: FormBody(
        children: [
          Text(
            _restoring
                ? 'Use the separate backup passphrase previously enabled on your NAS. The short phone passcode cannot recover this backup. Restore authenticates all files into an empty vault; no merge. Your NAS stays read-only.'
                : 'Protect NAS recovery with a separate strong passphrase. Anyone with the encrypted file can try guesses offline. Prefer six random words; length alone does not prove strength. Complete a saved NAS sync first. The NAS must support safe file locking; otherwise nothing is written.',
          ),
          const SizedBox(height: 16),
          if (_restoring) ...[
            _field(
              Keys.nasUrl,
              _url,
              'HTTPS WebDAV folder URL',
              secret: false,
              keyboardType: TextInputType.url,
            ),
            _field(Keys.nasUser, _user, 'NAS username', secret: false),
            _field(Keys.nasPassword, _password, 'NAS password'),
          ],
          _field(
            Keys.nasPin,
            _pin,
            _restoring ? 'New local passcode' : 'Current local passcode',
          ),
          if (_restoring)
            _field(
              Keys.nasPinConfirm,
              _pinConfirm,
              'Confirm new local passcode',
            ),
          _field(
            Keys.nasPhrase,
            _phrase,
            'Backup passphrase',
            secret: !_visible,
          ),
          if (!_restoring) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Keys.nasGenerate,
                    onPressed: _busy ? null : _generate,
                    child: const Text('Generate six words'),
                  ),
                ),
                IconButton(
                  key: Keys.nasVisibility,
                  tooltip: _visible ? 'Hide passphrase' : 'Show passphrase',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ],
            ),
            _field(
              Keys.nasPhraseConfirm,
              _phraseConfirm,
              'Confirm backup passphrase',
            ),
            const Text('Words: Electronic Frontier Foundation · CC BY 4.0'),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await BackupPassphrase.words();
                      if (context.mounted) {
                        showLicensePage(context: context);
                      }
                    },
              child: const Text('Word-list licenses'),
            ),
          ],
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          Semantics(
            liveRegion: true,
            child: Text(_result, key: Keys.nasResult),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: _restoring ? Keys.nasStartRestore : Keys.nasSave,
            onPressed: _busy ? null : () => _run(),
            child: Text(
              _restoring
                  ? 'Restore empty vault'
                  : 'Enable or change passphrase',
            ),
          ),
          if (!_restoring)
            OutlinedButton(
              key: Keys.nasDisable,
              onPressed: _busy ? null : () => _run(disable: true),
              child: const Text('Disable passphrase recovery'),
            ),
          if (_busy)
            TextButton(
              key: Keys.nasCancel,
              onPressed: _committing ? null : _cancel,
              child: const Text('Cancel'),
            ),
          const SizedBox(height: 12),
          Text(
            _restoring
                ? 'Up to 10,000 captures. Private temporary space is needed. Unlock with your new passcode afterward. Background upload stays off.'
                : 'This changes recovery protection only. It never changes your phone passcode or re-encrypts captures. Removing current recovery does not revoke old server snapshots.',
          ),
        ],
      ),
    ),
  );
}
