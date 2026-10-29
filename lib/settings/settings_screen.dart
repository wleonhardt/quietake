import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../keys.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../privacy/privacy_controller.dart';
import '../lock/recovery_screen.dart';
import '../lock/change_passcode_screen.dart';
import '../session.dart';
import '../sync/sync_settings.dart';
import '../sync/backup_screen.dart';
import '../backup/portable_screen.dart';
import '../sync/nas_recovery_screen.dart';
import '../vault/master_key_store.dart';
import '../sync/webdav_client.dart';

import 'package:sodium/sodium_sumo.dart';

/// WebDAV share URL and credentials. Test connection lists the collection.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.initial,
    required this.session,
  });

  final SyncSettings initial;
  final Session session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _url = TextEditingController(text: widget.initial.url);
  late final _user = TextEditingController(text: widget.initial.username);
  late final _pass = TextEditingController(text: widget.initial.password);
  String? _result;
  String? _privacyResult;
  WebDavClient? _testing;
  bool _busy = false;
  late bool _background = widget.initial.backgroundUploads;
  late bool _mobileData = widget.initial.mobileData;
  String _backgroundStatus = 'Checking Android scheduler…';

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
            'scheduled' => 'Scheduled when network and battery allow.',
            'uploading' => 'Android is uploading encrypted copies.',
            'transferred' => 'Last background pass finished. Full backup verification is separate.',
            'reconcile' => 'Open the vault and sync to check this backup before background uploads resume.',
            'pending' => 'Background backup pending. Android will retry.',
            _ => 'Background backup is off or waiting for its first successful sync.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _backgroundStatus =
              'Scheduler unavailable. Foreground sync remains available.',
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
  static String _connectionError(Object error) => switch (error) {
    FormatException(:final message) => message,
    WebDavException(:final status) =>
      'Connection failed (HTTP $status). Check folder URL, username and password.',
    SocketException() ||
    HttpException() ||
    TimeoutException() => 'Could not reach NAS. Check the URL and Wi-Fi.',
    _ => 'Connection failed. Check the saved details and try again.',
  };

  Future<void> _test() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = 'Testing connection…';
    });
    try {
      final c = _testing = _current.client();
      await c.ensureCollection();
      final n = (await c.list()).length;
      if (mounted) setState(() => _result = 'Connected · $n files');
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
      setState(
        () => _result = 'Save connection changes before checking backup.',
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BackupScreen(session: widget.session),
      ),
    );
  }

  Future<void> _changePasscode() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangePasscodeScreen(store: widget.session.store),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _privacyResult = 'Passcode changed');
      widget.session.sync.sync();
    }
  }

  /// Re-check the passcode, then show the recovery key.
  Future<void> _showRecovery() async {
    final pass = TextEditingController();
    SecureKey? key;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm passcode'),
          content: TextField(
            key: Keys.recoveryPrompt,
            controller: pass,
            onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
            obscureText: true,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: Keys.recoveryPromptOk,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Show'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      key = await widget.session.store.unlockWithPasscode(pass.text);
      // Read the key once, before the route builder can outlive its disposal.
      final recovery = widget.session.store.exportRecovery(key);
      final fingerprint = widget.session.store.fingerprint(key);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecoveryScreen(
            recoveryKey: recovery,
            fingerprint: fingerprint,
            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } on WrongPasscodeException {
      if (mounted) setState(() => _result = 'Wrong passcode. Try again.');
    } catch (_) {
      if (mounted) {
        setState(() => _result = 'Could not read the recovery key. Try again.');
      }
    } finally {
      key?.dispose();
      pass.dispose();
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final settings = _current;
    try {
      if (!settings.isConfigured) {
        throw const FormatException(
          'Enter a folder URL, username and password',
        );
      }
      settings.client().close();
      await widget.session.sync.saveSettings(settings);
      if (mounted) Navigator.of(context).pop(settings);
    } on FormatException catch (e) {
      if (mounted) setState(() => _result = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _result = 'Could not save connection details. Try again.',
        );
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
              ? 'Disconnect NAS backup?'
              : 'Clear saved NAS details?',
        ),
        scrollable: true,
        content: const Text(
          'Stops automatic backup and removes saved connection details. '
          'Captures stay on your phone and NAS. Pending NAS deletions will not '
          'finish until you reconnect that backup.',
        ),
        actions: [
          TextButton(
            key: Keys.disconnectCancel,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Keys.disconnectConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.initial.isConfigured ? 'Disconnect' : 'Clear details',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.sync.disconnect();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _result = 'Could not disconnect NAS backup. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _heading(Key key, String title) => Semantics(
    key: key,
    header: true,
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: .8,
      ),
    ),
  );

  /// One task per card; hierarchy comes from the card, not from dividers.
  Widget _card(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final privacy = PrivacyScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [LockButton()],
      ),
      body: FormBody(
        children: [
          _heading(Keys.settingsPrivacySection, 'Privacy & access'),
          const SizedBox(height: 12),
          _card([
            if (privacy != null) ...[
              // Rebuilt from the saved value, so a failed save shows the old one.
              ListenableBuilder(
                listenable: privacy,
                builder: (context, _) => KeyedSubtree(
                  key: ValueKey(privacy.minutes),
                  child: DropdownButtonFormField<int>(
                    key: Keys.idleTimeout,
                    isExpanded: true,
                    isDense: false,
                    itemHeight: null,
                    initialValue: privacy.minutes,
                    decoration: const InputDecoration(
                      labelText: 'Lock after inactivity',
                    ),
                    items: [
                      for (final minutes in PrivacyController.choices)
                        DropdownMenuItem(
                          value: minutes,
                          child: Text(
                            minutes == 0
                                ? 'Off'
                                : '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) async {
                            if (value == null) return;
                            try {
                              await privacy.setMinutes(value);
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => _privacyResult = 'Could not save privacy settings. Try again.',
                                );
                              }
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Recording and video playback delay idle locking. Lock now saves '
                'an active recording and pauses playback. Casting continues while locked.',
              ),
              const SizedBox(height: 12),
              Text(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? 'App-switcher previews are hidden. iOS screenshots cannot be blocked.'
                    : 'Screenshots, screen recording and app-switcher previews are protected on Android.',
              ),
              const SizedBox(height: 24),
            ],
            OutlinedButton.icon(
              key: Keys.settingsChangePasscode,
              onPressed: _busy ? null : _changePasscode,
              icon: const Icon(Icons.password),
              label: const Text('Change passcode'),
            ),
            if (_privacyResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_privacyResult!, key: Keys.settingsAccessResult),
                ),
              ),
          ]),
          const SizedBox(height: 32),
          _heading(Keys.settingsBackupSection, 'Backup'),
          const SizedBox(height: 12),
          _card([
            const Text(
              'Optional backup of encrypted media to your own WebDAV share.',
            ),
            const SizedBox(height: 20),
            TextField(
              key: Keys.settingsUrl,
              controller: _url,
              onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'WebDAV folder URL',
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
              decoration: const InputDecoration(labelText: 'Username'),
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
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            if (Platform.isAndroid) ...[
              SwitchListTile(
                key: Keys.backgroundUploads,
                title: const Text('Back up while app is closed'),
                subtitle: const Text(
                  'Android schedules encrypted uploads when network and battery allow. Save and complete one foreground sync first. Force-stop pauses work until you reopen Quietake.',
                ),
                value: _background,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _background = value),
              ),
              if (_background)
                SwitchListTile(
                  key: Keys.backgroundMobileData,
                  title: const Text('Allow mobile data'),
                  subtitle: const Text(
                    'Off uses unmetered networks only. Large videos can consume substantial data.',
                  ),
                  value: _mobileData,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _mobileData = value),
                ),
              Text(_backgroundStatus, key: Keys.backgroundStatus),
              const SizedBox(height: 16),
            ],
            // Full-width like every other settings button (2026-10-28 polish);
            // the outcome sits right under the buttons that caused it.
            FilledButton(
              key: Keys.settingsSave,
              onPressed: _busy ? null : _save,
              child: const Text('Save backup settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: Keys.settingsTest,
              onPressed: _busy ? null : _test,
              child: const Text('Test connection'),
            ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_result!, key: Keys.settingsResult),
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: Keys.backupOpen,
              label: const Text('Check saved backup'),
              onPressed: _busy || !widget.initial.isConfigured
                  ? null
                  : _openBackupCheck,
              icon: const Icon(Icons.verified_outlined),
            ),
            TextButton.icon(
              key: Keys.settingsDisconnect,
              onPressed: _busy ? null : _disconnect,
              icon: const Icon(Icons.cloud_off_outlined),
              label: Text(
                widget.initial.isConfigured
                    ? 'Disconnect NAS backup'
                    : 'Clear saved NAS details',
              ),
            ),
          ]),
          const SizedBox(height: 32),
          _heading(Keys.settingsRecoverySection, 'Recovery & export'),
          const SizedBox(height: 12),
          _card([
            OutlinedButton.icon(
              key: Keys.settingsRecovery,
              icon: const Icon(Icons.key),
              label: const Text('Show recovery key'),
              onPressed: _showRecovery,
            ),
            const SizedBox(height: 12),
            ListTile(
              key: Keys.nasRecoveryOpen,
              leading: const Icon(Icons.password),
              title: const Text('NAS backup passphrase'),
              subtitle: const Text(
                'Enable, change or disable recovery without your recovery key',
              ),
              onTap: _busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => NasRecoveryScreen(
                          store: widget.session.store,
                          session: widget.session,
                        ),
                      ),
                    ),
            ),
            ListTile(
              key: Keys.portableExportOpen,
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Portable encrypted backup'),
              subtitle: const Text(
                'Save a ZIP to Files using your recovery key',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PortableScreen(
                    store: widget.session.store,
                    session: widget.session,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
