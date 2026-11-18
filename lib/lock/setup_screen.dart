import 'package:flutter/material.dart';
import 'package:sodium/sodium_sumo.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_policy_screen.dart';
import '../form_body.dart';
import '../brand.dart';
import '../vault/master_key_store.dart';
import 'recovery_key_field.dart';
import 'recovery_screen.dart';
import '../backup/portable_screen.dart';
import '../sync/nas_recovery_screen.dart';
import '../sync/sync_settings.dart';

/// The steps of first run (decision 046).
enum _Step { welcome, create, restoreChoice, restoreKey }

/// First run: a welcome choice, then either a passcode and the recovery key,
/// or a page that lists the ways to restore. With [restoringOnly] it is the
/// recovery key form alone, for a forgotten passcode.
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
  late var _step = widget.restoringOnly ? _Step.restoreKey : _Step.welcome;
  bool get _restoring => _step == _Step.restoreKey;
  bool _busy = false;
  bool _showPasscode = false;
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
      setState(
        () =>
            _error = (l10n) =>
                l10n.passcodeTooShort(MasterKeyStore.minPasscodeLength),
      );
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
      final String words;
      try {
        words = await widget.store.exportRecoveryWords(key);
      } catch (_) {
        key.dispose();
        rethrow;
      }
      if (!mounted) {
        key.dispose();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => RecoveryScreen(
            confirm: true,
            recoveryWords: words,
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
      if (mounted) {
        setState(
          () =>
              _error = (l10n) => recoveryWordsMessage(l10n, e) ?? e.toString(),
        );
      }
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
              style: recoveryKeyStyle(20),
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

  void _back() => setState(() {
    _error = null;
    _step = _step == _Step.restoreKey ? _Step.restoreChoice : _Step.welcome;
  });

  void _open(Widget Function(VoidCallback done) screen) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (ctx) => screen(() {
        Navigator.of(ctx).pop();
        widget.onRestored!();
      }),
    ),
  );

  List<Widget> _welcome(AppLocalizations l10n) => [
    BrandHeader(message: l10n.setupTagline),
    Text(l10n.setupWelcomeBody),
    const SizedBox(height: 24),
    FilledButton(
      key: Keys.setupCreateOpen,
      onPressed: () => setState(() => _step = _Step.create),
      child: Text(l10n.setupCreateOpen),
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      key: Keys.setupRestoreOpen,
      onPressed: () => setState(() => _step = _Step.restoreChoice),
      child: Text(l10n.setupRestoreOpen),
    ),
    TextButton(
      key: Keys.setupPrivacyPolicy,
      onPressed: () => showPrivacyPolicy(context),
      child: Text(l10n.privacyPolicy),
    ),
  ];

  /// The ways back into an existing vault, each with what it needs.
  List<Widget> _restoreChoice(AppLocalizations l10n) => [
    Text(l10n.setupRestoreIntro),
    const SizedBox(height: 8),
    ListTile(
      key: Keys.setupToggleRestore,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.key_outlined),
      title: Text(l10n.setupHaveKey),
      subtitle: Text(l10n.setupRestoreKeyBody),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => setState(() => _step = _Step.restoreKey),
    ),
    if (widget.onRestored != null) ...[
      ListTile(
        key: Keys.portableRestoreOpen,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.folder_zip_outlined),
        title: Text(l10n.setupRestoreZip),
        subtitle: Text(l10n.setupRestoreZipBody),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(
          (done) => PortableScreen(store: widget.store, onRestored: done),
        ),
      ),
      ListTile(
        key: Keys.nasRestoreOpen,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.dns_outlined),
        title: Text(l10n.setupRestoreNas),
        subtitle: Text(l10n.setupRestoreNasBody),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(
          (done) => NasRecoveryScreen(store: widget.store, onRestored: done),
        ),
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Inside Setup, Back goes one step up; the first step and the
    // forgotten-passcode form leave the screen as before.
    final inner = !widget.restoringOnly && _step != _Step.welcome;
    return PopScope(
      canPop: !inner,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: inner
              ? BackButton(key: Keys.setupBack, onPressed: _busy ? null : _back)
              : null,
          title: Text(switch (_step) {
            _Step.welcome => l10n.setupWelcomeTitle,
            _Step.create => l10n.setupCreateTitle,
            _ => l10n.setupRestoreTitle,
          }),
        ),
        body: FormBody(
          children: switch (_step) {
            _Step.welcome => _welcome(l10n),
            _Step.restoreChoice => _restoreChoice(l10n),
            _ => _form(l10n),
          },
        ),
      ),
    );
  }

  List<Widget> _form(AppLocalizations l10n) => [
    BrandHeader(
      message: _restoring ? l10n.setupRestoreMessage : l10n.setupTagline,
    ),
    if (_restoring)
      RecoveryKeyField(fieldKey: Keys.setupRecoveryKey, controller: _recovery),
    if (_restoring) const SizedBox(height: 16),
    TextField(
      key: Keys.setupPasscode,
      controller: _pass,
      obscureText: !_showPasscode,
      enabled: !_busy,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: _restoring ? l10n.newPasscodeLabel : l10n.passcodeLabel,
        helperText: l10n.setupPasscodeHelper(MasterKeyStore.minPasscodeLength),
        // One switch for both fields.
        suffixIcon: IconButton(
          key: Keys.setupShowPasscode,
          tooltip: _showPasscode ? l10n.passcodeHide : l10n.passcodeShow,
          icon: Icon(
            _showPasscode
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _showPasscode = !_showPasscode),
        ),
      ),
    ),
    const SizedBox(height: 16),
    TextField(
      key: Keys.setupConfirm,
      controller: _confirm,
      obscureText: !_showPasscode,
      enabled: !_busy,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: l10n.confirmPasscodeLabel,
        // With the fields and above the button, so it stays in view
        // while the keyboard is up.
        error: _error == null
            ? null
            : Semantics(
                liveRegion: true,
                child: Text(
                  _error!(l10n),
                  key: Keys.setupError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
      ),
    ),
    const SizedBox(height: 24),
    FilledButton(
      key: Keys.setupSubmit,
      onPressed: _busy ? null : _submit,
      child: Text(
        _busy
            ? l10n.formWorking
            : _restoring
            ? l10n.restore
            : l10n.setupCreateVault,
      ),
    ),
  ];
}
