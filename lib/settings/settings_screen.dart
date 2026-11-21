import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_policy_screen.dart';
import '../licenses.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../privacy/privacy_controller.dart';
import '../lock/recovery_key_field.dart';
import '../lock/recovery_screen.dart';
import '../lock/change_passcode_screen.dart';
import '../session.dart';
import '../sync/sync_settings.dart';
import 'backup_settings_screen.dart';
import '../backup/portable_screen.dart';
import '../sync/nas_recovery_screen.dart';
import '../vault/master_key_store.dart';
import '../app_version.dart';
import '../camera/burst_setting.dart';
import '../camera/video_setting.dart';
import '../library/recently_deleted_screen.dart';
import '../vault/trash_setting.dart';
import '../vault/vault.dart';
import 'launcher_appearance.dart';

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
  String Function(AppLocalizations)? _recoveryResult;
  String Function(AppLocalizations)? _privacyResult;
  bool _keepDeleted = true;
  int _burstSize = BurstSetting.standard;
  int _videoHeight = VideoSetting.standard;
  bool? _plainIcon;
  bool? _biometric;

  @override
  void initState() {
    super.initState();
    LauncherAppearance.neutral().then((on) {
      if (mounted) setState(() => _plainIcon = on);
    });
    widget.session.store.hasCachedKey.then(
      (on) {
        if (mounted) setState(() => _biometric = on);
      },
      onError: (_) {}, // An unreadable keystore leaves the switch out.
    );
    VideoSetting.load().then((height) {
      if (mounted) setState(() => _videoHeight = height);
    });
    BurstSetting.load().then((size) {
      if (mounted) setState(() => _burstSize = size);
    });
    TrashSetting.load().then((keep) {
      if (mounted) setState(() => _keepDeleted = keep);
    });
    _loadRecoveryChecked();
  }

  DateTime? _recoveryChecked;
  static const _recoveryCheckDue = Duration(days: 90);

  Future<void> _loadRecoveryChecked() async {
    DateTime? at;
    try {
      at = await widget.session.store.loadRecoveryChecked();
    } catch (_) {
      // The reminder is optional; unreadable storage shows "never checked".
    }
    if (mounted) setState(() => _recoveryChecked = at);
  }

  String _recoveryCheckStatus(AppLocalizations l10n) {
    final at = _recoveryChecked;
    if (at == null) return l10n.recoveryCheckNever;
    final date = DateFormat.yMMMd(l10n.localeName).format(at.toLocal());
    return DateTime.now().difference(at) > _recoveryCheckDue
        ? l10n.recoveryCheckDue(date)
        : l10n.recoveryCheckLast(date);
  }

  Future<void> _changePasscode() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangePasscodeScreen(store: widget.session.store),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _privacyResult = (l10n) => l10n.settingsPasscodeChanged);
      widget.session.sync.sync();
    }
  }

  /// Biometric unlock is a choice (decision 043). Turning it on asks for the
  /// passcode; turning it off removes the keystore copy of the key.
  Future<void> _setBiometric(bool on) async {
    PrivacyScope.maybeOf(context)?.activity();
    SecureKey? key;
    try {
      if (on) {
        final passcode = await showDialog<String>(
          context: context,
          builder: (ctx) => _PasscodePrompt(
            onActivity: () => PrivacyScope.maybeOf(context)?.activity(),
            action: ctx.l10n.settingsBiometricTurnOn,
          ),
        );
        if (passcode == null || !mounted) return;
        key = await widget.session.store.unlockWithPasscode(passcode);
        await widget.session.store.enableBiometricUnlock(key);
      } else {
        await widget.session.store.clearCache();
      }
      if (mounted) {
        setState(() {
          _biometric = on;
          _privacyResult = null;
        });
      }
    } on PasscodeLockedException catch (e) {
      if (mounted) {
        setState(
          () => _privacyResult = (l10n) => passcodeLockedMessage(l10n, e),
        );
      }
    } on WrongPasscodeException {
      if (mounted) {
        setState(() => _privacyResult = (l10n) => l10n.settingsWrongPasscode);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _privacyResult = (l10n) => l10n.settingsBiometricFailed);
      }
    } finally {
      key?.dispose();
    }
  }

  /// Re-check the passcode, then show the recovery key.
  Future<void> _showRecovery() async {
    SecureKey? key;
    try {
      final passcode = await showDialog<String>(
        context: context,
        builder: (ctx) => _PasscodePrompt(
          onActivity: () => PrivacyScope.maybeOf(context)?.activity(),
        ),
      );
      if (passcode == null || !mounted) return;
      setState(() => _recoveryResult = null);
      key = await widget.session.store.unlockWithPasscode(passcode);
      // Read the key once, before the route builder can outlive its disposal.
      final recovery = widget.session.store.exportRecovery(key);
      final words = await widget.session.store.exportRecoveryWords(key);
      final fingerprint = widget.session.store.fingerprint(key);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecoveryScreen(
            recoveryWords: words,
            recoveryKey: recovery,
            fingerprint: fingerprint,
            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } on PasscodeLockedException catch (e) {
      if (mounted) {
        setState(
          () => _recoveryResult = (l10n) => passcodeLockedMessage(l10n, e),
        );
      }
    } on WrongPasscodeException {
      if (mounted) {
        setState(() => _recoveryResult = (l10n) => l10n.settingsWrongPasscode);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _recoveryResult = (l10n) => l10n.settingsRecoveryReadFailed,
        );
      }
    } finally {
      key?.dispose();
    }
  }

  /// The server form has its own screen (decision 047). When it saved or
  /// disconnected, Settings closes too, as it did when the form was here.
  Future<void> _openBackup() async {
    PrivacyScope.maybeOf(context)?.activity();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => BackupSettingsScreen(
          initial: widget.initial,
          session: widget.session,
        ),
      ),
    );
    if (changed == true && mounted) Navigator.of(context).pop();
  }

  /// Count and encrypted size of the vault files on this phone.
  late final Future<String> _storage = _storageSummary(
    context.l10n,
    Localizations.maybeLocaleOf(context)?.toString() ?? 'en',
  );

  Future<String> _storageSummary(AppLocalizations l10n, String locale) async {
    final files = await widget.session.vault.list();
    final held = (await widget.session.vault.trashedAt()).length;
    final extra = held == 0
        ? ''
        : ' ${l10n.settingsStorageTrashed(held, Vault.trashKeep.inDays)}';
    if (files.isEmpty) return '${l10n.settingsStorageNone}$extra';
    var bytes = 0;
    for (final file in files) {
      try {
        bytes += await file.length();
      } on FileSystemException {
        // A file that vanished while counting adds nothing.
      }
    }
    String one(double value) => NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(value);
    final size = bytes < 1024
        ? l10n.settingsSizeBytes(bytes)
        : bytes < 1024 * 1024
        ? l10n.settingsSizeKb(one(bytes / 1024))
        : l10n.settingsSizeMb(one(bytes / (1024 * 1024)));
    return '${l10n.settingsStorageSummary(files.length, size)}$extra';
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: const [LockButton()],
      ),
      body: FormBody(
        children: [
          _heading(Keys.settingsPrivacySection, l10n.settingsPrivacySection),
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
                    decoration: InputDecoration(
                      labelText: l10n.settingsIdleLabel,
                    ),
                    items: [
                      for (final minutes in PrivacyController.choices)
                        DropdownMenuItem(
                          value: minutes,
                          child: Text(
                            minutes == 0
                                ? l10n.settingsIdleOff
                                : l10n.settingsIdleMinutes(minutes),
                          ),
                        ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      try {
                        await privacy.setMinutes(value);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () =>
                                _privacyResult = (l10n) =>
                                    l10n.settingsPrivacySaveFailed,
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.settingsIdleNote),
              const SizedBox(height: 12),
              Text(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? l10n.settingsScreenshotsIos
                    : l10n.settingsScreenshotsAndroid,
              ),
              const SizedBox(height: 24),
            ],
            OutlinedButton.icon(
              key: Keys.settingsChangePasscode,
              onPressed: _changePasscode,
              icon: const Icon(Icons.password),
              label: Text(l10n.changePasscodeTitle),
            ),
            if (_biometric != null)
              SwitchListTile(
                key: Keys.settingsBiometric,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsBiometric),
                subtitle: Text(l10n.settingsBiometricBody),
                value: _biometric!,
                onChanged: _setBiometric,
              ),
            if (_plainIcon != null)
              SwitchListTile(
                key: Keys.settingsPlainIcon,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsPlainIcon),
                subtitle: Text(
                  Platform.isIOS
                      ? l10n.settingsPlainIconBodyIos
                      : l10n.settingsPlainIconBody,
                ),
                value: _plainIcon!,
                onChanged: (value) async {
                  PrivacyScope.maybeOf(context)?.activity();
                  final ok = await LauncherAppearance.setNeutral(value);
                  if (!mounted) return;
                  setState(() {
                    if (ok) {
                      _plainIcon = value;
                    } else {
                      _privacyResult = (l10n) => l10n.settingsPlainIconFailed;
                    }
                  });
                },
              ),
            if (_privacyResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _privacyResult!(l10n),
                    key: Keys.settingsAccessResult,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 32),
          _heading(Keys.settingsBackupSection, l10n.settingsBackupSection),
          const SizedBox(height: 12),
          _card([
            ListTile(
              key: Keys.settingsBackupOpen,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined),
              title: Text(l10n.settingsBackupServer),
              subtitle: Text(
                widget.initial.isConfigured
                    ? Uri.tryParse(widget.initial.url)?.host ?? ''
                    : l10n.settingsBackupNotSet,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openBackup,
            ),
          ]),
          const SizedBox(height: 32),
          _heading(Keys.settingsRecoverySection, l10n.settingsRecoverySection),
          const SizedBox(height: 12),
          _card([
            OutlinedButton.icon(
              key: Keys.settingsRecovery,
              icon: const Icon(Icons.key),
              label: Text(l10n.settingsShowRecovery),
              onPressed: _showRecovery,
            ),
            if (_recoveryResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _recoveryResult!(l10n),
                    key: Keys.settingsRecoveryResult,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: Keys.settingsRecoveryCheck,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.settingsCheckRecovery),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _RecoveryCheckDialog(
                  session: widget.session,
                  onActivity: () => PrivacyScope.maybeOf(context)?.activity(),
                ),
              ).then((_) => _loadRecoveryChecked()),
            ),
            const SizedBox(height: 4),
            Text(
              _recoveryCheckStatus(l10n),
              key: Keys.recoveryCheckStatus,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ListTile(
              key: Keys.nasRecoveryOpen,
              leading: const Icon(Icons.password),
              title: Text(l10n.settingsNasPassTitle),
              subtitle: Text(l10n.settingsNasPassBody),
              onTap: () => Navigator.push(
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
              title: Text(l10n.settingsPortableTitle),
              subtitle: Text(l10n.settingsPortableBody),
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
          const SizedBox(height: 24),
          _heading(Keys.settingsCameraSection, l10n.settingsCameraSection),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: Keys.settingsBurstSize,
            isExpanded: true,
            initialValue: _burstSize,
            decoration: InputDecoration(
              labelText: l10n.settingsBurstLabel,
              helperText: l10n.settingsBurstHelp,
            ),
            items: [
              for (final size in BurstSetting.choices)
                DropdownMenuItem(
                  value: size,
                  child: Text(l10n.settingsBurstChoice(size)),
                ),
            ],
            onChanged: (size) async {
              if (size == null) return;
              setState(() => _burstSize = size);
              await BurstSetting.save(size);
            },
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            // Rebuilt once the saved choice has been read.
            key: ValueKey(_videoHeight),
            child: DropdownButtonFormField<int>(
              key: Keys.settingsVideoQuality,
              isExpanded: true,
              initialValue: _videoHeight,
              decoration: InputDecoration(
                labelText: l10n.settingsVideoLabel,
                helperText: l10n.settingsVideoHelp,
              ),
              items: [
                for (final height in VideoSetting.choices)
                  DropdownMenuItem(
                    value: height,
                    child: Text(VideoSetting.label(height)),
                  ),
              ],
              onChanged: (height) async {
                if (height == null) return;
                setState(() => _videoHeight = height);
                await VideoSetting.save(height);
              },
            ),
          ),
          const SizedBox(height: 24),
          _heading(Keys.settingsStorageSection, l10n.settingsStorageSection),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _storage,
            builder: (context, snapshot) => snapshot.hasData
                ? Text(snapshot.data!, key: Keys.settingsStorage)
                : Text(
                    snapshot.hasError
                        ? l10n.settingsStorageUnreadable
                        : l10n.settingsStorageCounting,
                    key: Keys.settingsStorage,
                  ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Keys.settingsRecentlyDeleted,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      RecentlyDeletedScreen(session: widget.session),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.recentlyDeletedTitle),
            ),
          ),
          SwitchListTile(
            key: Keys.settingsKeepDeleted,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsKeepDeleted),
            subtitle: Text(l10n.settingsKeepDeletedBody),
            value: _keepDeleted,
            onChanged: (value) async {
              setState(() => _keepDeleted = value);
              await TrashSetting.save(value);
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: Keys.settingsPrivacyPolicy,
            onPressed: () => showPrivacyPolicy(context),
            icon: const Icon(Icons.privacy_tip_outlined),
            label: Text(l10n.privacyPolicy),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: Keys.settingsLicenses,
            onPressed: () => showAppLicenses(context),
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.settingsLicenses),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.settingsVersion('$appVersion ($appBuild)'),
            key: Keys.settingsVersion,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Owns its controller, so it is disposed only after the dialog has left the tree.
class _PasscodePrompt extends StatefulWidget {
  const _PasscodePrompt({required this.onActivity, this.action});
  final VoidCallback onActivity;

  /// The confirm button's label; "Show" for the recovery key.
  final String? action;
  @override
  State<_PasscodePrompt> createState() => _PasscodePromptState();
}

class _PasscodePromptState extends State<_PasscodePrompt>
    with WidgetsBindingObserver {
  final _pass = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// The content stays alive behind the lock screen, so a typed passcode must not.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _pass.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.confirmPasscodeLabel),
    content: TextField(
      key: Keys.recoveryPrompt,
      controller: _pass,
      onChanged: (_) => widget.onActivity(),
      obscureText: true,
      autofocus: true,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: Keys.recoveryPromptOk,
        onPressed: () => Navigator.pop(context, _pass.text),
        child: Text(widget.action ?? context.l10n.settingsShow),
      ),
    ],
  );
}

/// Compares a typed recovery key with the live vault key. Owns its controller so
/// the typed text is cleared when the dialog leaves the tree.
class _RecoveryCheckDialog extends StatefulWidget {
  const _RecoveryCheckDialog({required this.session, required this.onActivity});
  final Session session;
  final VoidCallback onActivity;
  @override
  State<_RecoveryCheckDialog> createState() => _RecoveryCheckDialogState();
}

class _RecoveryCheckDialogState extends State<_RecoveryCheckDialog>
    with WidgetsBindingObserver {
  final _typed = TextEditingController();
  String Function(AppLocalizations)? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// The content stays alive behind the lock screen, so a typed key must not.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _typed.clear();
      setState(() => _result = null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typed.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    SecureKey? key;
    try {
      final text = await widget.session.store.recoveryText(_typed.text);
      if (!mounted) return;
      key = widget.session.store.importRecovery(text);
      final match = widget.session.vault.matchesKey(key);
      _result = match
          ? (l10n) => l10n.recoveryCheckMatch
          : (l10n) => l10n.recoveryCheckMismatch;
      if (match) {
        unawaited(
          widget.session.store.saveRecoveryChecked().catchError((_) {}),
        );
      }
    } on BadRecoveryKeyException catch (e) {
      _result = (l10n) =>
          recoveryWordsMessage(l10n, e) ?? l10n.recoveryCheckInvalid;
    } finally {
      key?.dispose();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.recoveryCheckTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recoveryCheckIntro),
          const SizedBox(height: 16),
          RecoveryKeyField(
            fieldKey: Keys.recoveryCheckField,
            controller: _typed,
            onChanged: (_) => widget.onActivity(),
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(_result!(l10n), key: Keys.recoveryCheckResult),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.recoveryCheckClose),
        ),
        FilledButton(
          key: Keys.recoveryCheckOk,
          onPressed: _check,
          child: Text(l10n.recoveryCheckAction),
        ),
      ],
    );
  }
}
