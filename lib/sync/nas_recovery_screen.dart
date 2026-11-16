import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../licenses.dart';
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
  // Kept as a selector so the text follows the language at build time.
  String Function(AppLocalizations)? _result;
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

  void _status(String Function(AppLocalizations) value) {
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
      _status((l10n) => l10n.nasGenerateFailed);
    }
  }

  Future<bool> _confirm(bool disable) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(
            disable
                ? ctx.l10n.nasConfirmDisableTitle
                : ctx.l10n.nasConfirmSaveTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                disable
                    ? ctx.l10n.nasConfirmDisableBody
                    : ctx.l10n.nasConfirmSaveBody,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(ctx.l10n.cancel),
                  ),
                  FilledButton(
                    key: disable
                        ? Keys.nasDisableConfirm
                        : Keys.nasChangeConfirm,
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      disable
                          ? ctx.l10n.nasDisableAction
                          : ctx.l10n.nasSaveAction,
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
        _status((_) => e.message);
        return;
      }
      if (phrase == pin) {
        _status((l10n) => l10n.nasSeparatePhrase);
        return;
      }
      if (_restoring) {
        if (pin.length < MasterKeyStore.minPasscodeLength ||
            pin != _pinConfirm.text) {
          _status((l10n) => l10n.nasNeedPasscode);
          return;
        }
        if (!settings.isConfigured) {
          _status((l10n) => l10n.nasNeedDetails);
          return;
        }
        try {
          settings.client().close(); // The URL rule lives in the client.
        } on FormatException catch (e) {
          _status((_) => e.message);
          return;
        }
      } else if (phrase != _phraseConfirm.text) {
        _status((l10n) => l10n.nasMismatch);
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
          ? (l10n) => l10n.nasCheckingRestore
          : (l10n) => l10n.nasCheckingSaved;
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
          onProgress: (phase) => _status((_) => '$phase…'),
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
                title: Text(ctx.l10n.nasRestoredTitle),
                content: Text(ctx.l10n.nasRestoredUnsaved),
                actions: [
                  FilledButton(
                    key: Keys.nasRestoreUnsavedOk,
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(ctx.l10n.nasContinue),
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
          disable
              ? (l10n) => l10n.nasDisabledDone
              : (l10n) => l10n.nasSavedDone,
        );
      }
    } on PasscodeLockedException catch (e) {
      _status((_) => e.toString());
    } on WrongPasscodeException {
      _status((l10n) => l10n.nasWrongCurrent);
    } catch (_) {
      _status(
        _cancelled
            ? (l10n) => l10n.nasCancelled
            : _restoring
            ? (l10n) => l10n.nasRestoreFailed
            : (l10n) => l10n.nasChangeFailed,
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
      onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
      enabled: !_busy,
      obscureText: secret,
      keyboardType: keyboardType,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_committing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_restoring ? l10n.nasTitleRestore : l10n.nasTitleManage),
          actions: const [LockButton()],
        ),
        body: FormBody(
          children: [
            Text(_restoring ? l10n.nasIntroRestore : l10n.nasIntroManage),
            const SizedBox(height: 16),
            if (_restoring) ...[
              _field(
                Keys.nasUrl,
                _url,
                l10n.nasUrlLabel,
                secret: false,
                keyboardType: TextInputType.url,
              ),
              _field(Keys.nasUser, _user, l10n.nasUserLabel, secret: false),
              _field(Keys.nasPassword, _password, l10n.nasPasswordLabel),
            ],
            _field(
              Keys.nasPin,
              _pin,
              _restoring ? l10n.nasPinNew : l10n.nasPinCurrent,
            ),
            if (_restoring)
              _field(Keys.nasPinConfirm, _pinConfirm, l10n.nasPinConfirm),
            _field(
              Keys.nasPhrase,
              _phrase,
              l10n.nasPhraseLabel,
              secret: !_visible,
            ),
            if (!_restoring) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Keys.nasGenerate,
                      onPressed: _busy ? null : _generate,
                      child: Text(l10n.nasGenerate),
                    ),
                  ),
                  IconButton(
                    key: Keys.nasVisibility,
                    tooltip: _visible ? l10n.nasHide : l10n.nasShow,
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
                l10n.nasPhraseConfirm,
              ),
              Text(l10n.nasWordsCredit),
              TextButton(
                onPressed: _busy ? null : () => showAppLicenses(context),
                child: Text(l10n.nasWordLicenses),
              ),
            ],
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            Semantics(
              liveRegion: true,
              child: Text(_result?.call(l10n) ?? '', key: Keys.nasResult),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: _restoring ? Keys.nasStartRestore : Keys.nasSave,
              onPressed: _busy ? null : () => _run(),
              child: Text(
                _restoring ? l10n.portableRestoreButton : l10n.nasEnableButton,
              ),
            ),
            if (!_restoring)
              OutlinedButton(
                key: Keys.nasDisable,
                onPressed: _busy ? null : () => _run(disable: true),
                child: Text(l10n.nasDisableButton),
              ),
            if (_busy)
              TextButton(
                key: Keys.nasCancel,
                onPressed: _committing ? null : _cancel,
                child: Text(l10n.cancel),
              ),
            const SizedBox(height: 12),
            Text(_restoring ? l10n.nasFootRestore : l10n.nasFootManage),
          ],
        ),
      ),
    );
  }
}
