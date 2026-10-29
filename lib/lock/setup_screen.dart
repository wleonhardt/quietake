import 'package:flutter/material.dart';
import 'package:sodium/sodium_sumo.dart';

import '../keys.dart';
import '../form_body.dart';
import '../brand.dart';
import '../vault/master_key_store.dart';
import 'recovery_screen.dart';
import '../backup/portable_screen.dart';
import '../sync/nas_recovery_screen.dart';

/// First run: choose a passcode, then save the recovery key. Also the way in
/// on a new phone with an existing recovery key.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.store,
    required this.onUnlocked,
    this.restoringOnly = false,
    this.acceptsRecoveryKey,
    this.onRestored,
  });

  final bool restoringOnly;
  final VoidCallback? onRestored;
  final bool Function(SecureKey)? acceptsRecoveryKey;
  final MasterKeyStore store;
  final void Function(SecureKey key) onUnlocked;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _recovery = TextEditingController();
  late bool _restoring = widget.restoringOnly;
  bool _busy = false;
  int _attempt = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) ++_attempt;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_attempt;
    _pass.dispose();
    _confirm.dispose();
    _recovery.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_pass.text.length < MasterKeyStore.minPasscodeLength) {
      setState(() => _error = MasterKeyStore.passcodeTooShort);
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _error = 'Passcodes do not match');
      return;
    }
    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_restoring) {
        final key = await widget.store.restoreFromRecovery(
          _recovery.text,
          _pass.text,
          acceptsKey: widget.acceptsRecoveryKey,
          confirmFingerprint: _confirmFingerprint,
        );
        if (!mounted || attempt != _attempt) {
          key.dispose();
          return;
        }
        widget.onUnlocked(key);
        return;
      }
      // Nothing is persisted until the recovery key is confirmed as saved
      // (decision 038), so an interrupted setup restarts cleanly.
      final key = await widget.store.prepareKey();
      var saved = false;
      if (!mounted) {
        key.dispose();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => RecoveryScreen(
            recoveryKey: widget.store.exportRecovery(key),
            fingerprint: widget.store.fingerprint(key),
            onDone: () {
              saved = true;
              // Pop first: the app replaces its home on unlock, and a route
              // left on the navigator would stay on top of it.
              Navigator.of(ctx).pop();
            },
          ),
        ),
      );
      if (!saved || !mounted) {
        key.dispose();
        return;
      }
      try {
        await widget.store.commitPasscode(key, _pass.text);
      } catch (_) {
        key.dispose();
        rethrow;
      }
      if (!mounted) {
        key.dispose();
        return;
      }
      widget.onUnlocked(key);
    } on BadRecoveryKeyException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _restoring
              ? 'Could not restore the vault. Check storage and try again.'
              : 'Could not create the vault. Check storage and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// An empty vault cannot prove a typed key; the user compares fingerprints.
  Future<bool> _confirmFingerprint(String fingerprint) async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm recovery key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This phone has no captures yet, so the key cannot be checked '
              'against them. Compare this fingerprint with the one saved '
              'next to your recovery key.',
            ),
            const SizedBox(height: 16),
            Text(
              fingerprint,
              key: Keys.setupFingerprint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 20),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: Keys.setupFingerprintReject,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not mine'),
          ),
          FilledButton(
            key: Keys.setupFingerprintConfirm,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Matches'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_restoring ? 'Restore vault' : 'Set a passcode'),
      ),
      body: FormBody(
        children: [
          BrandHeader(
            message: _restoring
                ? 'Unlock your encrypted files with your saved recovery key.'
                : 'Your camera. Your captures. Your control.',
          ),
          if (_restoring)
            TextField(
              key: Keys.setupRecoveryKey,
              obscureText: true,
              enableSuggestions: false,
              controller: _recovery,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Recovery key'),
            ),
          if (_restoring) const SizedBox(height: 16),
          TextField(
            key: Keys.setupPasscode,
            controller: _pass,
            obscureText: true,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _restoring ? 'New passcode' : 'Passcode',
              helperText:
                  'At least ${MasterKeyStore.minPasscodeLength} characters',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: Keys.setupConfirm,
            controller: _confirm,
            obscureText: true,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Confirm passcode'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: Keys.setupSubmit,
            onPressed: _busy ? null : _submit,
            child: Text(_restoring ? 'Restore' : 'Create vault'),
          ),
          if (!widget.restoringOnly)
            TextButton(
              key: Keys.setupToggleRestore,
              onPressed: _busy
                  ? null
                  : () => setState(() => _restoring = !_restoring),
              child: Text(
                _restoring
                    ? 'Start a new vault instead'
                    : 'I have a recovery key',
              ),
            ),
          if (!widget.restoringOnly && widget.onRestored != null)
            TextButton(
              key: Keys.portableRestoreOpen,
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (ctx) => PortableScreen(
                          store: widget.store,
                          onRestored: () {
                            Navigator.of(ctx).pop();
                            widget.onRestored!();
                          },
                        ),
                      ),
                    ),
              child: const Text('Restore an encrypted ZIP'),
            ),
          if (!widget.restoringOnly && widget.onRestored != null)
            TextButton(
              key: Keys.nasRestoreOpen,
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (ctx) => NasRecoveryScreen(
                          store: widget.store,
                          onRestored: () {
                            Navigator.of(ctx).pop();
                            widget.onRestored!();
                          },
                        ),
                      ),
                    ),
              child: const Text('Restore from NAS with backup passphrase'),
            ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: Keys.setupError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
