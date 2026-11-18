import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../form_body.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import '../sync/backup_screen.dart';
import '../sync/sync_settings.dart';
import '../sync/webdav_client.dart';

/// The backup server: its address and credentials, background uploads, and
/// the checks that need a saved server (decision 047). Pops with true when
/// the saved settings changed.
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({
    super.key,
    required this.initial,
    required this.session,
  });

  final SyncSettings initial;
  final Session session;

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  late final _url = TextEditingController(text: widget.initial.url);
  late final _user = TextEditingController(text: widget.initial.username);
  late final _pass = TextEditingController(text: widget.initial.password);
  // Outcome text is kept as a selector so it follows the language at build time.
  String Function(AppLocalizations)? _result;
  WebDavClient? _testing;
  bool _busy = false;
  late bool _background = widget.initial.backgroundUploads;
  late bool _mobileData = widget.initial.mobileData;
  String Function(AppLocalizations) _backgroundStatus = (l10n) =>
      l10n.settingsBgChecking;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) _loadBackgroundStatus();
  }

  Future<void> _loadBackgroundStatus() async {
    try {
      final state = await widget.session.sync.backgroundStatus();
      if (mounted) {
        setState(
          () => _backgroundStatus = switch (state) {
            'scheduled' => (l10n) => l10n.settingsBgScheduled,
            'uploading' => (l10n) => l10n.settingsBgUploading,
            'transferred' => (l10n) => l10n.settingsBgTransferred,
            'reconcile' => (l10n) => l10n.settingsBgReconcile,
            'pending' => (l10n) => l10n.settingsBgPending,
            _ => (l10n) => l10n.settingsBgOff,
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _backgroundStatus = (l10n) => l10n.settingsBgUnavailable,
        );
      }
    }
  }

  SyncSettings get _current => SyncSettings(
    url: _url.text.trim(),
    username: _user.text.trim(),
    password: _pass.text,
    backgroundUploads: _background,
    mobileData: _mobileData,
  );

  @override
  void dispose() {
    _testing?.close();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// Fixed categories; raw exception text can carry the request URL.
  static String Function(AppLocalizations) _connectionError(Object error) =>
      switch (error) {
        FormatException(:final message) => (_) => message,
        WebDavException(:final status) => (l10n) => l10n.settingsErrHttp(
          status,
        ),
        SocketException() ||
        HttpException() ||
        TimeoutException() => (l10n) => l10n.settingsErrReach,
        _ => (l10n) => l10n.settingsErrGeneric,
      };

  Future<void> _test() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = (l10n) => l10n.settingsTesting;
    });
    try {
      final c = _testing = _current.client();
      await c.ensureCollection();
      final n = (await c.list()).length;
      if (mounted) {
        setState(() => _result = (l10n) => l10n.settingsConnected(n));
      }
    } catch (e) {
      if (mounted) setState(() => _result = _connectionError(e));
    } finally {
      _testing?.close();
      _testing = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBackupCheck() async {
    final current = _current;
    if (current.url != widget.initial.url ||
        current.username != widget.initial.username ||
        current.password != widget.initial.password) {
      setState(() => _result = (l10n) => l10n.settingsSaveFirst);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BackupScreen(session: widget.session),
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final settings = _current;
    try {
      if (!settings.isConfigured) {
        setState(() => _result = (l10n) => l10n.settingsEnterDetails);
        return;
      }
      settings.client().close();
      await widget.session.sync.saveSettings(settings);
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException catch (e) {
      if (mounted) setState(() => _result = (_) => e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _result = (l10n) => l10n.settingsSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Decision 026: counts first, asks, then renames; nothing moves on a dry run.
  Future<void> _renameRemote() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final sync = widget.session.sync;
      final preview = await sync.renameRemote(dryRun: true);
      if (!mounted) return;
      if (preview.candidates == 0) {
        setState(() => _result = (l10n) => l10n.settingsRenameRemoteNone);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.settingsRenameRemoteTitle),
          scrollable: true,
          content: Text(
            context.l10n.settingsRenameRemoteBody(preview.candidates),
          ),
          actions: [
            TextButton(
              key: Keys.renameRemoteCancel,
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: Keys.renameRemoteConfirm,
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.settingsRenameRemoteAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final done = await sync.renameRemote();
      if (mounted) {
        setState(
          () => _result = (l10n) => l10n.settingsRenameRemoteDone(done.renamed),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _result = (l10n) => l10n.settingsRenameRemoteFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.initial.isConfigured
              ? context.l10n.settingsDisconnectTitle
              : context.l10n.settingsClearTitle,
        ),
        scrollable: true,
        content: Text(context.l10n.settingsDisconnectBody),
        actions: [
          TextButton(
            key: Keys.disconnectCancel,
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: Keys.disconnectConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.initial.isConfigured
                  ? context.l10n.settingsDisconnectAction
                  : context.l10n.settingsClearAction,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.sync.disconnect();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _result = (l10n) => l10n.settingsDisconnectFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsBackupSection),
        actions: const [LockButton()],
      ),
      body: FormBody(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.settingsBackupIntro),
                  const SizedBox(height: 20),
                  TextField(
                    key: Keys.settingsUrl,
                    controller: _url,
                    onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.settingsUrlLabel,
                      hintText: 'https://nas.example.com/vault/',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: Keys.settingsUser,
                    controller: _user,
                    onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
                    enabled: !_busy,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.settingsUsername,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: Keys.settingsPass,
                    controller: _pass,
                    onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
                    enabled: !_busy,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.settingsPassword,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (Platform.isAndroid) ...[
                    SwitchListTile(
                      key: Keys.backgroundUploads,
                      title: Text(l10n.settingsBackgroundTitle),
                      subtitle: Text(l10n.settingsBackgroundBody),
                      value: _background,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _background = value),
                    ),
                    if (_background)
                      SwitchListTile(
                        key: Keys.backgroundMobileData,
                        title: Text(l10n.settingsMobileTitle),
                        subtitle: Text(l10n.settingsMobileBody),
                        value: _mobileData,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _mobileData = value),
                      ),
                    Text(_backgroundStatus(l10n), key: Keys.backgroundStatus),
                    const SizedBox(height: 16),
                  ],
                  // Full-width like every other settings button (2026-10-28 polish);
                  // the outcome sits right under the buttons that caused it.
                  FilledButton(
                    key: Keys.settingsSave,
                    onPressed: _busy ? null : _save,
                    child: Text(l10n.settingsSave),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: Keys.settingsTest,
                    onPressed: _busy ? null : _test,
                    child: Text(l10n.settingsTest),
                  ),
                  if (_result != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_result!(l10n), key: Keys.settingsResult),
                      ),
                    ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: Keys.backupOpen,
                    label: Text(l10n.backupCheckSaved),
                    onPressed: _busy || !widget.initial.isConfigured
                        ? null
                        : _openBackupCheck,
                    icon: const Icon(Icons.verified_outlined),
                  ),
                  OutlinedButton.icon(
                    key: Keys.settingsRenameRemote,
                    label: Text(l10n.settingsRenameRemote),
                    onPressed: _busy || !widget.initial.isConfigured
                        ? null
                        : _renameRemote,
                    icon: const Icon(Icons.drive_file_rename_outline),
                  ),
                  TextButton.icon(
                    key: Keys.settingsDisconnect,
                    onPressed: _busy ? null : _disconnect,
                    icon: const Icon(Icons.cloud_off_outlined),
                    label: Text(
                      widget.initial.isConfigured
                          ? l10n.settingsDisconnectButton
                          : l10n.settingsClearButton,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
