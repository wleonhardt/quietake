import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

import 'auth/authenticator.dart';
import 'backup/restore_startup_gate.dart';
import 'brand.dart';
import 'camera/capture_screen.dart';
import 'cast/cast_backend.dart';
import 'cast/google_cast_backend.dart';
import 'gallery/share_media.dart';
import 'lock/lock_screen.dart';
import 'lock/setup_screen.dart';
import 'session.dart';
import 'privacy/privacy_controller.dart';
import 'privacy/privacy_scope.dart';
import 'privacy/screen_privacy.dart';
import 'vault/master_key_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearShareFiles();
  final sodium = await SodiumSumoInit.init();
  final store = MasterKeyStore(
    sodium,
    await getApplicationDocumentsDirectory(),
  );
  runApp(
    RestoreStartupGate(
      store: store,
      child: QuietakeApp(
        store: store,
        auth: LocalAuthenticator(),
        castBackend: GoogleCastBackend(),
      ),
    ),
  );
}

class QuietakeApp extends StatefulWidget {
  const QuietakeApp({
    super.key,
    required this.store,
    required this.auth,
    required this.castBackend,
    this.session,
    this.idleTimeout,
  });

  final MasterKeyStore store;
  final Authenticator auth;
  final CastBackend castBackend;

  /// Already-unlocked session, used by tests that skip the lock screen.
  final Session? session;

  /// Shortens real-time idle checks in integration tests only.
  @visibleForTesting
  final Duration? idleTimeout;

  @override
  State<QuietakeApp> createState() => _QuietakeAppState();
}

class _QuietakeAppState extends State<QuietakeApp> with WidgetsBindingObserver {
  Session? _session;
  String? _startError;
  bool _locked = false;
  bool? _hasKeyfile;
  SecureKey? _openingKey;
  late final _privacy = PrivacyController(
    onLock: () => _enterLock(autoPrompt: false),
    timeoutOverride: widget.idleTimeout,
  );
  late final _screenPrivacy = ScreenPrivacy(
    _captureChanged,
    onBackground: _backgroundLock,
  );
  bool _captured = false;
  bool _autoPrompt = true;
  int _lockEpoch = 0;
  bool _foreground = true;
  var _lockNavigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = widget.session;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    HardwareKeyboard.instance.addHandler(_keyActivity);
    _screenPrivacy.start();
    _privacy.load().catchError((Object _) {
      /* Keep the safe default if storage is unavailable. */
    });
    widget.store.hasKeyfile
        // Unknown storage state must never offer setup over an existing vault.
        .catchError((Object _) => true)
        .then((v) {
          if (mounted) {
            setState(() => _hasKeyfile = v);
            if (_captured && v) _enterLock(autoPrompt: false);
            _updateIdle();
          }
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_keyActivity);
    _screenPrivacy.dispose();
    _privacy.dispose();
    if (widget.session == null) _session?.close();
    super.dispose();
  }

  bool _keyActivity(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) _privacy.activity();
    return false;
  }

  void _captureChanged(bool captured) {
    if (!mounted) return;
    _captured = captured;
    if (captured && _hasKeyfile == true) _enterLock(autoPrompt: false);
    _updateIdle();
  }

  void _updateIdle() => _privacy.setEnabled(
    _foreground &&
        !_captured &&
        !_locked &&
        _session != null &&
        _hasKeyfile == true,
  );

  Future<void> _enterLock({required bool autoPrompt}) async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _privacy.setEnabled(false);
    // Decision 040: no plaintext keeps streaming or sitting decoded in memory
    // behind the lock screen.
    final stopped = _session?.lock();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    setState(() {
      if (!_locked || !autoPrompt) {
        _lockEpoch++;
        _lockNavigator = GlobalKey<NavigatorState>();
      }
      if (!_locked || !autoPrompt) _autoPrompt = autoPrompt;
      _locked = true;
    });
    await stopped;
  }

  Future<void> _backgroundLock() async {
    final exists = _hasKeyfile == true || await widget.store.hasKeyfile;
    if (exists && mounted) {
      _hasKeyfile = true;
      await _enterLock(autoPrompt: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused) _backgroundLock();
    _updateIdle();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!_locked) return false;
    await _lockNavigator.currentState?.maybePop();
    return true;
  }

  void _unlock(SecureKey key, int epoch) {
    if (_captured || epoch != _lockEpoch) {
      key.dispose();
      return;
    }
    if (_session == null && _hasKeyfile == true && _openingKey == null) {
      _start(key);
    } else {
      if (!identical(key, _openingKey)) key.dispose();
      setState(() => _locked = false);
      _session?.sync.sync();
    }
    _updateIdle();
  }

  Future<void> _start(SecureKey key) async {
    if (_openingKey != null) {
      if (!identical(key, _openingKey)) key.dispose();
      return;
    }
    _openingKey = key;
    setState(() {
      _locked = false;
      _startError = null;
    });
    try {
      final s = await Session.start(widget.store, key, widget.castBackend);
      if (!mounted) {
        await s.close();
        return;
      }
      setState(() {
        _session = s;
        _hasKeyfile = true;
        if (_captured) {
          _locked = true;
          _autoPrompt = false;
        }
      });
      _updateIdle();
      s.sync.sync();
    } catch (_) {
      // Session.start disposed the key. Stay on the lock screen with a reason.
      if (mounted) {
        setState(() => _startError = 'Could not open the vault. Try again.');
      }
    } finally {
      _openingKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    final epoch = _lockEpoch;
    final s = _session;
    if (_hasKeyfile == null) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (s == null && !_hasKeyfile!) {
      home = SetupScreen(
        store: widget.store,
        onUnlocked: _start,
        onRestored: () {
          if (!mounted) return;
          setState(() {
            _hasKeyfile = true;
            _locked = _captured || !_foreground;
            _autoPrompt = false;
          });
        },
      );
    } else if (s == null) {
      home = LockScreen(
        store: widget.store,
        auth: widget.auth,
        message: _startError,
        onUnlocked: (key) => _unlock(key, epoch),
      );
    } else {
      home = CaptureScreen(session: s, active: !_locked);
    }
    return MaterialApp(
      title: 'Quietake',
      theme: quietakeTheme(brightness: Brightness.light),
      darkTheme: quietakeTheme(),
      highContrastTheme: quietakeTheme(
        brightness: Brightness.light,
        highContrast: true,
      ),
      highContrastDarkTheme: quietakeTheme(highContrast: true),
      home: home,
      builder: (context, navigator) => PrivacyScope(
        controller: _privacy,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _privacy.activity(),
          onPointerMove: (_) => _privacy.activity(),
          onPointerSignal: (_) => _privacy.activity(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: _locked,
                child: TickerMode(enabled: !_locked, child: navigator!),
              ),
              if (_locked)
                HeroControllerScope.none(
                  child: Navigator(
                    key: _lockNavigator,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => LockScreen(
                        store: widget.store,
                        auth: widget.auth,
                        acceptsRecoveryKey: s?.vault.matchesKey,
                        onUnlocked: (key) => _unlock(key, epoch),
                        autoPrompt: _autoPrompt,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
