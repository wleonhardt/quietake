import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../gallery/item.dart';
import '../vault/vault.dart';
import 'sync_service.dart';
import 'sync_settings.dart';
import 'webdav_client.dart';
import 'background_uploads.dart';

enum SyncState { idle, unconfigured, syncing, synced, pending }

/// One serialized sync queue for automatic saves and the gallery's manual action.
class SyncController extends ChangeNotifier {
  SyncController(
    this.vault, {
    Future<SyncSettings> Function()? loadSettings,
    BackgroundUploads? background,
  }) : _loadSettings = loadSettings ?? SyncSettings.load,
       _background = background ?? BackgroundUploads();

  final Vault vault;
  final Future<SyncSettings> Function() _loadSettings;
  final BackgroundUploads _background;
  Future<String> backgroundStatus() => _background.status();
  SyncState state = SyncState.idle;
  String? result;
  Future<void>? _running;
  Future<void>? _recovery;
  WebDavClient? _client;
  bool _again = false;
  bool _verifyAgain = false;
  bool _verifying = false;
  (String, String)? _target;
  BackupVerificationReport? lastVerification;
  bool verificationCurrent = false;
  String verificationResult = 'No full backup check yet.';
  bool get isVerifying => _verifying;
  bool get isVerificationQueued => _verifyAgain;
  bool _cancelled = false;
  bool _closed = false;
  bool _disconnecting = false;

  bool get isSyncing => state == SyncState.syncing;
  String get label => switch (state) {
    SyncState.idle => 'NAS backup not checked',
    SyncState.unconfigured => 'On this device · backup off',
    SyncState.syncing =>
      _verifying ? 'Checking NAS backup…' : 'Syncing with NAS…',
    SyncState.synced =>
      verificationCurrent
          ? 'NAS backup verified'
          : 'Synced with NAS · not verified',
    SyncState.pending => 'NAS update pending',
  };

  Future<void> delete(File file) async {
    if (_closed) throw StateError('Vault session closed');
    await vault.delete(file);
    try {
      await vault.catalog.forgetDeleted();
    } catch (_) {
      // Damaged organization must not block confirmed media removal. Gallery
      // retry and sync preserve the damaged bytes and retry cleanup after repair.
    }
    unawaited(sync());
  }

  Future<void> sync() {
    if (_closed || _disconnecting) return _running ?? Future.value();
    verificationCurrent = false;
    if (lastVerification != null) {
      verificationResult =
          'New sync since last check. Check again for the current snapshot.';
    }
    _again = true;
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> verify() {
    if (_closed || _disconnecting || _verifying || _verifyAgain) {
      return _running ?? Future.value();
    }
    _verifyAgain = true;
    verificationCurrent = false;
    verificationResult = 'Backup check queued…';
    final running = _running ??= _drain().whenComplete(() => _running = null);
    notifyListeners();
    return running;
  }

  Future<void> _drain() async {
    while ((_again || _verifyAgain) && !_closed) {
      final checking = !_again && _verifyAgain;
      if (checking) {
        _verifyAgain = false;
      } else {
        _again = false;
      }
      _verifying = checking;
      _cancelled = false;
      state = SyncState.syncing;
      result = checking ? 'Checking NAS backup…' : 'Syncing with NAS…';
      if (checking) {
        verificationResult = 'Reading and authenticating encrypted NAS copies…';
      }
      notifyListeners();
      try {
        final settings = await _loadSettings();
        if (_closed) break;
        if (_cancelled) continue;
        final target = (settings.url, settings.username);
        if (_target != target) {
          lastVerification = null;
          verificationCurrent = false;
          if (!checking) {
            verificationResult = 'No full check for this saved backup.';
          }
        }
        _target = target;
        if (!settings.isConfigured) {
          state = SyncState.unconfigured;
          result = 'NAS sync not configured. Open Settings to connect.';
          if (checking) {
            verificationResult = 'Connect a saved NAS backup before checking.';
          }
        } else {
          if (!checking && settings.backgroundUploads) {
            await _background.request();
          }
          await _background.foreground<void>(() async {
            if (_cancelled || _closed) return;
            final client = _client = settings.client();
            final service = SyncService(
              vault,
              client,
              isCancelled: () => _cancelled || _closed,
            );
            if (checking) {
              final report = await service.verify(
                onProgress: (checked, total) {
                  if (!_closed) {
                    verificationResult =
                        'Checked $checked of $total encrypted captures…';
                    notifyListeners();
                  }
                },
              );
              if (_cancelled || _closed) {
                throw StateError('Backup operation cancelled');
              }
              lastVerification = report;
              verificationCurrent = !_again && !_verifyAgain && !_cancelled;
              verificationResult = verificationCurrent
                  ? 'Verified ${report.media} ${report.media == 1 ? 'capture' : 'captures'}${report.catalog ? ' and organization' : ''}. Keep your recovery key separately.'
                  : 'Another sync was requested during check. Check again after sync.';
              result = verificationResult;
            } else {
              final report = await service.sync();
              if (_cancelled || _closed) {
                throw StateError('Backup operation cancelled');
              }
              result = report.toString();
            }
            state = _again || _verifyAgain
                ? SyncState.syncing
                : SyncState.synced;
            try {
              await _background.configure(
                settings,
                vault,
                service.authenticatedCatalogHash,
                service.confirmedMedia,
              );
            } on PlatformException {
              // The pass finished; native scheduling is repaired on the next
              // authenticated open and must not report the backup as pending.
            }
          });
        }
      } catch (error) {
        state = SyncState.pending;
        verificationCurrent = false;
        if (checking) {
          verificationResult = _cancelled
              ? 'Check cancelled. Originals kept.'
              : _verificationError(error);
          result = verificationResult;
        } else {
          result = _cancelled
              ? 'Sync cancelled. NAS changes may still be pending.'
              : error is BackupConflictException
              ? 'NAS conflict for ${_itemName(error.name)}. Both copies kept; automatic replacement stopped.'
              : 'NAS update pending. Retry sync.';
        }
      } finally {
        _verifying = false;
        _client?.close();
        _client = null;
        if (!_closed) notifyListeners();
      }
    }
  }

  /// Titles when set; otherwise the capture time, never the vault filename.
  String _itemName(String name) {
    final title = vault.catalog.details(name).title;
    if (title.isNotEmpty) return title;
    final at = VaultItem(File('${vault.dir.path}/$name')).capturedAt?.toLocal();
    if (at == null) return 'a capture';
    String two(int v) => v.toString().padLeft(2, '0');
    return 'the capture from ${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }

  String _verificationError(Object error) {
    if (error is BackupCheckException) return error.message;
    if (error is BackupConflictException) {
      return 'Phone and NAS differ for ${_itemName(error.name)}. Both copies kept.';
    }
    if (error is WebDavException) {
      return 'Could not check NAS (HTTP ${error.status}). Check saved connection.';
    }
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return 'Could not reach NAS. Check connection and retry.';
    }
    return 'Could not verify backup. Some copies may be damaged or use another vault key. Originals kept.';
  }

  Future<void> disconnect() async {
    if (_closed) return;
    if (_disconnecting) throw StateError('Backup is busy');
    _disconnecting = true;
    cancel();
    try {
      await _running;
      await _background.reset();
      await SyncSettings.clear();
      state = SyncState.unconfigured;
      result = 'NAS backup disconnected. Captures kept on phone and NAS.';
      lastVerification = null;
      verificationCurrent = false;
      verificationResult = 'NAS backup disconnected.';
      _target = null;
    } finally {
      _disconnecting = false;
      if (!_closed) notifyListeners();
    }
  }

  /// Invalidate old native credentials before publishing changed settings.
  Future<void> saveSettings(SyncSettings settings) async {
    if (_closed || _disconnecting) throw StateError('Backup is busy');
    _disconnecting = true;
    cancel();
    try {
      await _running;
      await _background.reset();
      await settings.save();
    } finally {
      _disconnecting = false;
    }
    unawaited(sync());
  }

  /// Recovery mutations share the native gate and outlive routes safely.
  Future<T> recoveryOperation<T>(
    Future<T> Function(WebDavClient client) action,
  ) async {
    if (_closed || _disconnecting) throw StateError('Backup is busy');
    _disconnecting = true;
    cancel();
    try {
      await _running;
      if (_closed) throw StateError('Vault session closed');
      _cancelled = false;
      final operation = _background.foreground<T>(() async {
        if (_closed || _cancelled) throw StateError('Recovery cancelled');
        final settings = await _loadSettings();
        if (!settings.isConfigured) {
          throw const FormatException('Save a NAS connection first');
        }
        final client = _client = settings.client();
        try {
          return await action(client);
        } finally {
          client.close();
          _client = null;
        }
      });
      _recovery = operation.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      return await operation;
    } finally {
      _recovery = null;
      _disconnecting = false;
      // Captures/edits during this exclusive operation must not lose their retry.
      if (!_closed) unawaited(sync());
    }
  }

  bool get recoveryCancelled => _closed || _cancelled;

  void cancelVerification() {
    if (!_verifying && !_verifyAgain) return;
    _verifyAgain = false;
    verificationCurrent = false;
    verificationResult = 'Check cancelled. Originals kept.';
    if (_verifying) {
      _cancelled = true;
      state = _again ? SyncState.syncing : SyncState.pending;
      result = verificationResult;
      _client?.close();
    }
    if (!_closed) notifyListeners();
  }

  void cancel() {
    if (_running == null) return;
    _cancelled = true;
    _again = false;
    if (_verifying || _verifyAgain) {
      verificationResult = 'Check cancelled. Originals kept.';
    }
    _verifyAgain = false;
    verificationCurrent = false;
    state = SyncState.pending;
    result = 'Sync cancelled. NAS changes may still be pending.';
    _client?.close();
    if (!_closed) notifyListeners();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _again = false;
    _verifyAgain = false;
    _client?.close();
    await _running;
    await _recovery;
    dispose();
  }
}
