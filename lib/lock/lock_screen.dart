import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sodium/sodium_sumo.dart';

import '../auth/authenticator.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../form_body.dart';
import '../brand.dart';
import '../camera/locked_camera_screen.dart';
import '../camera/locked_capture_store.dart';
import '../crypto/pending_crypto.dart';
import '../vault/master_key_store.dart';
import '../vault/pending_key_store.dart';
import '../vault/vault.dart';
import 'setup_screen.dart';

/// Passcode or biometric unlock. Produces the master key; the caller decides
/// whether that starts a session or just lifts the gate.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.store,
    required this.auth,
    required this.onUnlocked,
    this.autoPrompt = true,
    this.acceptsRecoveryKey,
    this.message,
    this.vaultDir = Vault.defaultDir,
  });

  /// Shown until the next attempt, e.g. why the previous unlock did not open.
  final String? message;
  final bool autoPrompt;
  final bool Function(SecureKey)? acceptsRecoveryKey;
  final MasterKeyStore store;

  /// Where sealed captures wait while locked; replaced in tests.
  final Future<Directory> Function() vaultDir;
  final Authenticator auth;
  final void Function(SecureKey key) onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final _pass = TextEditingController();
  bool _busy = false;
  bool _biometric = false;
  bool _prompting = false;
  bool _resumePrompt = false;
  int _attempt = 0;
  Uint8List? _publicKey;
  String Function(AppLocalizations)? _error;

  static String Function(AppLocalizations)? _text(String? message) =>
      message == null ? null : (_) => message;

  @override
  void initState() {
    super.initState();
    _error = _text(widget.message);
    WidgetsBinding.instance.addObserver(this);
    _probe();
    _loadPublicKey();
  }

  /// The locked camera needs the vault public key; a vault that has none yet
  /// (never unlocked since this feature) offers no camera.
  Future<void> _loadPublicKey() async {
    final key = await PendingKeyStore(
      widget.store.sodium,
      widget.store.dir,
    ).publicKey();
    if (mounted && key != null) setState(() => _publicKey = key);
  }

  Future<void> _openCamera() async {
    final key = _publicKey;
    if (key == null) return;
    try {
      final dir = await widget.vaultDir();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LockedCameraScreen(
            store: LockedCaptureStore(PendingCrypto(widget.store.sodium), dir),
            publicKey: key,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = (l) => l.camUnavailable);
    }
  }

  @override
  void didUpdateWidget(covariant LockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The app reports a failed vault open through the same, still-mounted screen.
    if (widget.message != oldWidget.message) _error = _text(widget.message);
    if (oldWidget.autoPrompt && !widget.autoPrompt) {
      _attempt++;
      _resumePrompt = false;
      if (_prompting) widget.auth.cancel();
      _prompting = false;
    }
  }

  /// Leaving mid-prompt: dismiss it, or the plugin refuses the next one.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _resumePrompt = widget.autoPrompt || _prompting;
      _attempt++;
      if (_prompting) widget.auth.cancel();
      setState(() => _prompting = false);
    } else if (state == AppLifecycleState.resumed &&
        _resumePrompt &&
        _biometric) {
      // Pause/resume can arrive without a frame between them. Let the root
      // gate update visibility before an old home lock attempts authentication.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _resumePrompt &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _useBiometric();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (!visible && _prompting) {
      _attempt++;
      _prompting = false;
      widget.auth.cancel();
    } else if (visible && _resumePrompt && _biometric) {
      _useBiometric();
    }
  }

  Future<void> _probe() async {
    bool ok;
    try {
      ok = await widget.auth.available && await widget.store.hasCachedKey;
    } catch (_) {
      ok = false; // An unreadable keystore leaves the passcode path.
    }
    if (mounted) setState(() => _biometric = ok);
    if (ok && mounted && widget.autoPrompt) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        await _useBiometric();
      } else {
        _resumePrompt = true;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attempt++;
    if (_prompting) widget.auth.cancel();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _useBiometric() async {
    if (_prompting || _busy) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _resumePrompt = true;
      return;
    }
    _resumePrompt = false;
    final attempt = ++_attempt;
    final reason = context.l10n.lockUnlockReason;
    setState(() {
      _prompting = true;
      _error = null;
    });
    try {
      final ok = await widget.auth.authenticate(reason);
      if (!mounted || attempt != _attempt) return;
      if (!ok) {
        final why = widget.auth.lastError;
        if (why != null) setState(() => _error = _text(why));
        return;
      }
      SecureKey? key;
      try {
        key = await widget.store.cachedKey();
      } catch (_) {
        key = null;
      }
      if (key == null) {
        // The cache went away since the probe; biometrics cannot unlock now.
        if (mounted && attempt == _attempt) {
          setState(() {
            _biometric = false;
            _error = (l10n) => l10n.lockBiometricUnavailable;
          });
        }
      } else if (mounted && attempt == _attempt) {
        widget.onUnlocked(key);
      } else {
        key.dispose();
      }
    } finally {
      if (mounted && attempt == _attempt) setState(() => _prompting = false);
    }
  }

  Future<void> _usePasscode() async {
    if (_busy || _prompting) return;
    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await widget.store.unlockWithPasscode(_pass.text);
      if (mounted && attempt == _attempt) {
        widget.onUnlocked(key);
      } else {
        key.dispose();
      }
    } on WrongPasscodeException catch (e) {
      if (mounted && attempt == _attempt) {
        setState(() => _error = (_) => e.toString());
      }
    } catch (_) {
      if (mounted && attempt == _attempt) {
        setState(() => _error = (l10n) => l10n.lockFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: FormBody(
        centered: true,
        children: [
          BrandHeader(message: l10n.lockMessage),
          TextField(
            key: Keys.lockPasscode,
            controller: _pass,
            obscureText: true,
            autofocus: !_biometric,
            onSubmitted: (_) => _usePasscode(),
            decoration: InputDecoration(labelText: l10n.passcodeLabel),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: Keys.lockUnlock,
            onPressed: _busy || _prompting ? null : _usePasscode,
            child: Text(l10n.lockUnlock),
          ),
          if (_biometric)
            TextButton.icon(
              key: Keys.lockBiometric,
              icon: const Icon(Icons.fingerprint),
              label: Text(l10n.lockUseBiometrics),
              onPressed: _busy || _prompting ? null : _useBiometric,
            ),
          if (_publicKey != null)
            TextButton.icon(
              key: Keys.lockCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.lockCamera),
              onPressed: _busy || _prompting ? null : _openCamera,
            ),
          TextButton(
            key: Keys.lockRecovery,
            onPressed: _busy || _prompting
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (ctx) => SetupScreen(
                        store: widget.store,
                        restoringOnly: true,
                        acceptsRecoveryKey: widget.acceptsRecoveryKey,
                        onUnlocked: (key) {
                          Navigator.of(ctx).pop();
                          widget.onUnlocked(key);
                        },
                      ),
                    ),
                  ),
            child: Text(l10n.lockForgot),
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!(l10n),
                key: Keys.lockError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
