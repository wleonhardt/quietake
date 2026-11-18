import 'package:flutter/material.dart';
import 'package:sodium/sodium_sumo.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_policy_screen.dart';
import '../form_body.dart';
import '../brand.dart';
import '../vault/master_key_store.dart';
import 'recovery_screen.dart';
import '../backup/portable_screen.dart';
import '../sync/nas_recovery_screen.dart';
import '../sync/sync_settings.dart';

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
  String Function(AppLocalizations)? _error;

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
      setState(() => _error = (_) => MasterKeyStore.passcodeTooShort);
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _error = (l10n) => l10n.passcodesDoNotMatch);
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
        // A new vault has no backup server. Details saved by an earlier
        // install can outlive an iOS reinstall (decision 033).
        await SyncSettings.clear();
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
      if (mounted) setState(() => _error = (_) => e.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _restoring
              ? (l10n) => l10n.setupRestoreFailed
              : (l10n) => l10n.setupCreateFailed,
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
        title: Text(ctx.l10n.setupConfirmKeyTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.setupConfirmKeyBody),
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
            child: Text(ctx.l10n.setupNotMine),
          ),
          FilledButton(
            key: Keys.setupFingerprintConfirm,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.setupMatches),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _restoring ? l10n.setupRestoreTitle : l10n.setupCreateTitle,
        ),
      ),
      body: FormBody(
        children: [
          BrandHeader(
            message: _restoring ? l10n.setupRestoreMessage : l10n.setupTagline,
          ),
          if (_restoring)
            TextField(
              key: Keys.setupRecoveryKey,
              obscureText: true,
              enableSuggestions: false,
              controller: _recovery,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.recoveryKeyLabel),
            ),
          if (_restoring) const SizedBox(height: 16),
          TextField(
            key: Keys.setupPasscode,
            controller: _pass,
            obscureText: true,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _restoring
                  ? l10n.newPasscodeLabel
                  : l10n.passcodeLabel,
              helperText: l10n.setupPasscodeHelper(
                MasterKeyStore.minPasscodeLength,
              ),
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
            decoration: InputDecoration(labelText: l10n.confirmPasscodeLabel),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: Keys.setupSubmit,
            onPressed: _busy ? null : _submit,
            child: Text(_restoring ? l10n.restore : l10n.setupCreateVault),
          ),
          if (!widget.restoringOnly)
            TextButton(
              key: Keys.setupToggleRestore,
              onPressed: _busy
                  ? null
                  : () => setState(() => _restoring = !_restoring),
              child: Text(_restoring ? l10n.setupStartNew : l10n.setupHaveKey),
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
              child: Text(l10n.setupRestoreZip),
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
              child: Text(l10n.setupRestoreNas),
            ),
          TextButton(
            key: Keys.setupPrivacyPolicy,
            onPressed: _busy ? null : () => showPrivacyPolicy(context),
            child: Text(l10n.privacyPolicy),
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!(l10n),
                key: Keys.setupError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
