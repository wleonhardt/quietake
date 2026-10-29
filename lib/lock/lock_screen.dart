import 'package:flutter/material.dart';
import 'package:sodium/sodium_sumo.dart';

import '../auth/authenticator.dart';
import '../keys.dart';
import '../form_body.dart';
import '../brand.dart';
import '../vault/master_key_store.dart';
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
  });

  /// Shown until the next attempt, e.g. why the previous unlock did not open.
  final String? message;
  final bool autoPrompt;
  final bool Function(SecureKey)? acceptsRecoveryKey;
  final MasterKeyStore store;
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.message;
    WidgetsBinding.instance.addObserver(this);
    _probe();
  }

  @override
  void didUpdateWidget(covariant LockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      _useBiometric();
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
    setState(() {
      _prompting = true;
      _error = null;
    });
    try {
      final ok = await widget.auth.authenticate('Unlock Quietake');
      if (!mounted || attempt != _attempt) return;
      if (!ok) {
        final why = widget.auth.lastError;
        if (why != null) setState(() => _error = why);
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
            _error = 'Biometric unlock is unavailable. Use your passcode.';
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
        setState(() => _error = e.toString());
      }
    } catch (_) {
      if (mounted && attempt == _attempt) {
        setState(
          () =>
              _error = 'Could not unlock. Try again or use your recovery key.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FormBody(
        centered: true,
        children: [
          const BrandHeader(message: 'Unlock your private vault.'),
          TextField(
            key: Keys.lockPasscode,
            controller: _pass,
            obscureText: true,
            autofocus: !_biometric,
            onSubmitted: (_) => _usePasscode(),
            decoration: const InputDecoration(labelText: 'Passcode'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: Keys.lockUnlock,
            onPressed: _busy || _prompting ? null : _usePasscode,
            child: const Text('Unlock'),
          ),
          if (_biometric)
            TextButton.icon(
              key: Keys.lockBiometric,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Use biometrics'),
              onPressed: _busy || _prompting ? null : _useBiometric,
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
            child: const Text('Forgot passcode?'),
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: Keys.lockError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
