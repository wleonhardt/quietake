import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'burst_setting.dart';
import '../cast/cast_controller.dart';
import '../cast/device_picker.dart';
import '../gallery/gallery_screen.dart';
import '../gallery/item.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../brand.dart';
import '../privacy/privacy_controller.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import '../sync/sync_controller.dart';
import 'ingest_video.dart';
import 'capture_store.dart';
import 'recording_progress.dart';
import 'video_setting.dart';
import '../library/tag_picker.dart';
import '../library/albums_screen.dart';

/// Camera-first screen: shutter encrypts straight into the vault. With a
/// TV connected, the phone is held in landscape and every capture is shown
/// on the TV as soon as it is encrypted.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.session, this.active = true});

  final Session session;
  final bool active;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  // CameraX shares native preview state across controllers. A replacement
  // screen must wait for the previous screen's asynchronous shutdown.
  AppLocalizations get _l10n => context.l10n;

  /// How long a stop waits for the first recorded data. CameraX reached
  /// streaming 2.5 s after Start on the Galaxy S25 when the session was
  /// rebuilt just before recording; a stop before that finalizes with no data.
  static const _firstDataWait = Duration(seconds: 4);
  static Future<void>? _lastShutdown;
  late final Future<void>? _previousShutdown;
  final _shutdown = Completer<void>();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.back;
  bool _recording = false;
  bool _grid = false;

  /// Photo flash; off at every launch because the app is meant to be quiet.
  FlashMode _flashMode = FlashMode.off;

  /// Zoom of the open camera and its range; all 1 when it cannot zoom.
  double _zoom = 1, _minZoom = 1, _maxZoom = 1;
  double _zoomAtPinchStart = 1;
  int _delay = 0;
  int? _countdown;
  Timer? _countdownTimer;
  Offset? _focusRing;
  Timer? _focusRingTimer;

  /// The camera whose focus and exposure the user locked, if any.
  CameraController? _lockedController;
  Set<String> _tagIds = {};
  Set<String> _recordingTagIds = {};
  bool _choosingAlbum = false;
  PrivacyController? _privacy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final privacy = PrivacyScope.maybeOf(context);
    if (!identical(privacy, _privacy)) {
      _privacy?.hold(this, false);
      _privacy = privacy;
      _privacy?.hold(this, _recording);
    }
  }

  bool _landscape = false;
  bool _flash = false;
  String? _status;
  Timer? _statusTimer;
  bool _busy = false;
  bool _galleryRequested = false;
  bool _foreground = true;
  int _cameraEpoch = 0;
  Future<void>? _initializing;
  Future<void>? _operation;
  Future<void>? _orienting;
  Future<void>? _releasing;

  /// Set once the recording is live: the platform has written its first data.
  DateTime? _recordStarted;
  Completer<void>? _firstData;
  StreamSubscription<void>? _recordedData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _previousShutdown = _lastShutdown;
    _lastShutdown = _shutdown.future;
    WidgetsBinding.instance.addObserver(this);
    widget.session.cast.addListener(_onCast);
    widget.session.vault.catalog.addListener(_onCatalog);
    widget.session.takeLockedPublished().then(_noticeLockedPublished);
    BurstSetting.load().then((size) {
      if (mounted) setState(() => _burstSize = size);
    });
    _init();
  }

  /// Tells the owner that photos taken on the lock screen camera are now in
  /// the library. It runs only after unlock, so nothing is revealed while locked.
  void _noticeLockedPublished(int count) {
    if (count <= 0 || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: Keys.lockedPublishedNotice,
        content: Text(_l10n.lockedCapturesPublished(count)),
      ),
    );
  }

  void _onCatalog() {
    if (!mounted) return;
    setState(() {
      _tagIds = _tagIds
          .where(widget.session.vault.catalog.albums.containsKey)
          .toSet();
    });
  }

  Future<void> _chooseAlbum() async {
    if (_choosingAlbum ||
        _recording ||
        _busy ||
        !_foreground ||
        !widget.active) {
      return;
    }
    setState(() => _choosingAlbum = true);
    final epoch = _cameraEpoch;
    try {
      final catalog = widget.session.vault.catalog;
      await catalog.load();
      if (!mounted || !_foreground || !widget.active || epoch != _cameraEpoch) {
        return;
      }
      final ids = await chooseTags(
        context,
        catalog,
        selected: _tagIds,
        onManage: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AlbumsScreen(session: widget.session),
          ),
        ),
      );
      if (!mounted ||
          !_foreground ||
          !widget.active ||
          epoch != _cameraEpoch ||
          ids == null) {
        return;
      }
      setState(() => _tagIds = ids.where(catalog.albums.containsKey).toSet());
    } on Exception {
      if (mounted && _foreground && widget.active && epoch == _cameraEpoch) {
        setState(() => _status = _l10n.camTagsOpenFailed);
      }
    } finally {
      _choosingAlbum = false;
      if (mounted) setState(() {});
    }
  }

  /// Landscape follows the cast session: on while casting, free otherwise.
  Future<void> _onCast() {
    final casting = widget.session.cast.isCasting;
    if (casting == _landscape) {
      if (mounted) setState(() {});
      return Future.value();
    }
    _landscape = casting;
    final previous = _orienting;
    final capture = _operation;
    return _orienting = () async {
      await previous;
      if (!mounted || casting != _landscape) return;
      try {
        await SystemChrome.setPreferredOrientations(
          casting
              ? [
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]
              : [],
        );
        await capture;
        if (!mounted || !_foreground || !widget.active || _releasing != null) {
          return;
        }
        final controller = _controller;
        if (controller != null && controller.value.isInitialized) {
          casting
              ? await controller.lockCaptureOrientation(
                  DeviceOrientation.landscapeLeft,
                )
              : await controller.unlockCaptureOrientation();
        }
      } on Exception {
        if (mounted) {
          setState(() => _status = _l10n.camOrientationFailed);
        }
      }
      if (mounted) setState(() {});
    }();
  }

  Future<void> _init({bool enableAudio = false, bool recover = true}) {
    if (_controller != null || !_foreground || !widget.active) {
      return Future.value();
    }
    return _initializing ??=
        _openCamera(enableAudio: enableAudio, recover: recover).whenComplete(
          () {
            _initializing = null;
            if (mounted) setState(() {});
          },
        );
  }

  /// [recover] is skipped when the camera reopens only to switch audio on; the
  /// authenticated open and every unlock still retry pending captures.
  Future<void> _openCamera({
    required bool enableAudio,
    required bool recover,
  }) async {
    final epoch = ++_cameraEpoch;
    CameraController? controller;
    try {
      await _previousShutdown;
      if (!mounted || !_foreground || !widget.active || epoch != _cameraEpoch) {
        return;
      }
      if (recover) {
        // Storage trouble here must not read as a camera permission problem.
        try {
          final recovery = await CaptureStore(widget.session.vault).recover(
            cameraCache: Platform.isAndroid
                ? await getTemporaryDirectory()
                : null,
            prepare: videoPreparer(widget.session.vault),
          );
          if (recovery.pending > 0) {
            _status = _l10n.camPendingSave;
          } else if (recovery.recovered > 0) {
            _status = [
              _l10n.camRecovered(recovery.recovered),
              if (recovery.unnormalized > 0) _l10n.camRecoveredVideoNote,
            ].join(' ');
            unawaited(widget.session.sync.sync());
          }
        } catch (_) {
          _status = _l10n.camPendingCheckFailed;
        }
        if (!mounted ||
            !_foreground ||
            !widget.active ||
            epoch != _cameraEpoch) {
          return;
        }
      }
      final cameras = await availableCameras();
      if (!mounted || !_foreground || !widget.active || epoch != _cameraEpoch) {
        return;
      }
      if (cameras.isEmpty) {
        setState(() => _status = _l10n.camNone);
        return;
      }
      _cameras = cameras;
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      // Photos use the full sensor; a recording camera uses the chosen video
      // quality, which also binds its stills (decision 034).
      final preset = enableAudio
          ? VideoSetting.preset(await VideoSetting.load())
          : ResolutionPreset.max;
      if (!mounted || !_foreground || !widget.active || epoch != _cameraEpoch) {
        return;
      }
      controller = CameraController(
        selected,
        preset,
        enableAudio: enableAudio,
      );
      await controller.initialize();
      var minZoom = 1.0, maxZoom = 1.0;
      try {
        minZoom = await controller.getMinZoomLevel();
        maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {
        // This camera cannot zoom; the pinch does nothing.
      }
      // The plugin's own start value differs by platform. A recording camera
      // never fires the photo flash.
      var flashMode = enableAudio ? FlashMode.off : _flashMode;
      try {
        await controller.setFlashMode(flashMode);
      } catch (_) {
        flashMode = FlashMode.off; // No flash on this camera.
      }
      if (!mounted || !_foreground || !widget.active || epoch != _cameraEpoch) {
        await controller.dispose();
        return;
      }
      if (widget.session.cast.isCasting) {
        await controller.lockCaptureOrientation(
          DeviceOrientation.landscapeLeft,
        );
      }
      if (!mounted || !_foreground || !widget.active || epoch != _cameraEpoch) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _lens = selected.lensDirection;
        if (!enableAudio) _flashMode = flashMode;
        // A newly opened camera starts without zoom.
        _minZoom = minZoom;
        _maxZoom = maxZoom < minZoom ? minZoom : maxZoom;
        _zoom = 1.0.clamp(_minZoom, _maxZoom);
        if (_status == _l10n.camUnavailable || _status == _l10n.camNone) {
          _status = null;
        }
      });
    } catch (_) {
      await controller?.dispose();
      if (mounted && _foreground) {
        setState(() => _status = _l10n.camUnavailable);
      }
    }
  }

  @override
  void didUpdateWidget(covariant CaptureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active && _foreground) {
      _resumeCamera();
    } else {
      _stopCountdown();
      _tagIds = {};
      ++_cameraEpoch;
      _releasing ??= _releaseCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopCountdown();
      _tagIds = {};
      _foreground = false;
      ++_cameraEpoch;
      _releasing ??= _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _resumeCamera();
    }
  }

  Future<void> _resumeCamera() async {
    await _operation;
    await _releasing;
    _releasing = null;
    if (mounted && _foreground && widget.active) await _init();
  }

  Future<void> _releaseCamera() async {
    await _initializing;
    await _operation;
    await _orienting;
    final controller = _controller;
    try {
      if (_recording && controller != null) {
        await _stopRecording(controller, awaitData: false);
      }
    } catch (error) {
      if (mounted) setState(() => _status = _saveError(error));
    } finally {
      _timer?.cancel();
      _recording = false;
      _privacy?.hold(this, false);
      // Detach the preview before disposing its controller so queued frames
      // cannot rebuild a CameraPreview against an already-disposed camera.
      if (identical(_controller, controller)) {
        _controller = null;
        if (mounted) setState(() {});
      }
      await controller?.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusRingTimer?.cancel();
    _countdownTimer?.cancel();
    _statusTimer?.cancel();
    _privacy?.hold(this, false);
    _foreground = false;
    ++_cameraEpoch;
    widget.session.cast.removeListener(_onCast);
    widget.session.vault.catalog.removeListener(_onCatalog);
    if (_landscape) SystemChrome.setPreferredOrientations([]);
    _timer?.cancel();
    unawaited(_recordedData?.cancel());
    _releasing ??= _releaseCamera();
    unawaited(
      _releasing!.whenComplete(() {
        if (identical(_lastShutdown, _shutdown.future)) _lastShutdown = null;
        _shutdown.complete();
      }),
    );
    super.dispose();
  }

  /// A confirmation, unlike a problem, clears itself.
  void _showPassing(String text) {
    _statusTimer?.cancel();
    setState(() => _status = text);
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _status == text) setState(() => _status = null);
    });
  }

  /// Quiet confirmation: a light tap and a brief edge flash.
  Future<void> _confirm() async {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _flash = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) setState(() => _flash = false);
  }

  Future<void> _capture(Future<void> Function() action) {
    if (_busy ||
        _choosingAlbum ||
        _releasing != null ||
        !_foreground ||
        !widget.active) {
      return Future.value();
    }
    setState(() => _busy = true);
    final orientation = _orienting;
    return _operation = () async {
      try {
        await orientation;
        await action();
      } catch (error) {
        if (mounted) {
          setState(() => _status = _saveError(error));
        }
      } finally {
        _busy = false;
        if (mounted) setState(() {});
      }
    }();
  }

  /// Focuses and meters on the tapped point. Devices that cannot do it keep
  /// their automatic focus, so a refusal is ignored.
  Future<void> _focusAt(
    BuildContext box,
    TapUpDetails tap,
    CameraController controller,
  ) async {
    final size = (box.findRenderObject() as RenderBox).size;
    final point = Offset(
      (tap.localPosition.dx / size.width).clamp(0.0, 1.0),
      (tap.localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    final wasLocked = identical(_lockedController, controller);
    _focusRingTimer?.cancel();
    setState(() {
      _focusRing = tap.globalPosition;
      _lockedController = null;
    });
    _focusRingTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && _lockedController == null) {
        setState(() => _focusRing = null);
      }
    });
    try {
      if (wasLocked) {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      }
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (_) {
      // Best effort: no manual focus on this camera.
    }
  }

  /// Off, automatic, on (decision 035).
  Future<void> _cycleFlash(CameraController controller) async {
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {
      if (mounted) {
        setState(() {
          _flashMode = FlashMode.off;
          _status = _l10n.camFlashUnavailable;
        });
      }
    }
  }

  /// Pinch on the preview, or the zoom label to go back (decision 035).
  void _setZoom(double wanted, CameraController controller) {
    final zoom = wanted.clamp(_minZoom, _maxZoom);
    if (zoom == _zoom) return;
    setState(() => _zoom = zoom);
    // Best effort: a refusal leaves the picture as it is.
    controller.setZoomLevel(zoom).catchError((Object _) {});
  }

  /// Long press: focus and meter at the point, then hold both until the next
  /// tap on the preview.
  Future<void> _lockAt(
    BuildContext box,
    LongPressStartDetails press,
    CameraController controller,
  ) async {
    final size = (box.findRenderObject() as RenderBox).size;
    final point = Offset(
      (press.localPosition.dx / size.width).clamp(0.0, 1.0),
      (press.localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    _focusRingTimer?.cancel();
    setState(() {
      _focusRing = press.globalPosition;
      _lockedController = controller;
    });
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
      await controller.setFocusMode(FocusMode.locked);
      await controller.setExposureMode(ExposureMode.locked);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _focusRing = null;
        _lockedController = null;
        _status = _l10n.camFocusLockFailed;
      });
    }
  }

  Future<void> _openGallery() async {
    if (_galleryRequested || _choosingAlbum) return;
    setState(() => _galleryRequested = true);
    final epoch = _cameraEpoch;
    try {
      await _initializing;
      if (!mounted ||
          !_foreground ||
          !widget.active ||
          epoch != _cameraEpoch ||
          _recording ||
          _busy ||
          _releasing != null) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GalleryScreen(session: widget.session),
        ),
      );
    } finally {
      _galleryRequested = false;
      if (mounted) setState(() {});
    }
  }

  String _saveError(Object error) => switch (error) {
    _RecordingStartException() => _l10n.camRecordStartFailed,
    _RecordingStopException() => _l10n.camRecordStopFailed,
    EmptyCaptureException(extension: 'mp4') => _l10n.camNoFrames,
    PendingCaptureException(albumApplied: false) => _l10n.camPendingNoTags,
    PendingCaptureException() => _l10n.camPendingSave,
    _ => _l10n.camSaveFailed,
  };

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null) {
      _countdown = null;
      if (mounted) setState(() {});
    }
  }

  /// The shutter button: take a photo now, or start or cancel the self timer.
  void _onShutter() {
    if (_countdown != null) {
      _stopCountdown();
    } else if (_delay == 0) {
      _shutter();
    } else {
      setState(() => _countdown = _delay);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = (_countdown ?? 1) - 1;
        if (left > 0) {
          setState(() => _countdown = left);
        } else {
          _stopCountdown();
          _shutter();
        }
      });
    }
  }

  int _burstSize = BurstSetting.standard;

  /// Takes [_burstSize] photos one after another. Each one is saved through the
  /// same private path as a single photo, so a stop part way keeps what is saved.
  Future<void> _burst() {
    final tagIds = {..._tagIds};
    return _capture(() async {
      final c = _controller;
      if (c == null) return;
      var saved = 0;
      for (var i = 0; i < _burstSize; i++) {
        if (!mounted || !_foreground || !widget.active) break;
        final shot = await c.takePicture();
        _confirm();
        await _ingest(File(shot.path), 'jpg', tagIds);
        saved++;
      }
      if (mounted && saved > 1) _showPassing(_l10n.camSavedPhotos(saved));
    });
  }

  Future<void> _shutter() {
    final tagIds = {..._tagIds};
    return _capture(() async {
      final c = _controller;
      if (c == null) return;
      final shot = await c.takePicture();
      _confirm();
      await _ingest(File(shot.path), 'jpg', tagIds);
    });
  }

  Future<void> _flipCamera() => _capture(() async {
    final c = _controller;
    if (c == null || _recording) return;
    final next = _cameras.firstWhere(
      (camera) =>
          camera.lensDirection ==
          (_lens == CameraLensDirection.front
              ? CameraLensDirection.back
              : CameraLensDirection.front),
    );
    try {
      await c.setDescription(next);
      _lens = next.lensDirection;
      if (widget.session.cast.isCasting) {
        await c.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      }
    } catch (_) {
      // The switch closed the working camera before it failed to open the new
      // one, so replace the dead controller with one on the unchanged lens.
      if (mounted) setState(() => _controller = null);
      try {
        await c.dispose();
      } catch (_) {}
      await _init(recover: false);
      if (mounted) {
        setState(() => _status = _l10n.camSwitchFailed);
      }
    }
  });

  /// [awaitData] gives a recording that has not written anything yet a bounded
  /// chance to receive its first keyframe; a background release stops at once.
  Future<void> _stopRecording(
    CameraController controller, {
    bool awaitData = true,
  }) async {
    final tagIds = {..._recordingTagIds};
    final firstData = _firstData;
    if (awaitData && firstData != null && !firstData.isCompleted) {
      await firstData.future.timeout(_firstDataWait, onTimeout: () {});
    }
    final XFile clip;
    try {
      clip = await controller.stopVideoRecording();
    } on CameraException {
      throw const _RecordingStopException();
    } finally {
      // A failed stop must not keep the shutter disabled or the idle lock held.
      _recording = false;
      _recordStarted = null;
      _firstData = null;
      unawaited(_recordedData?.cancel());
      _recordedData = null;
      _recordingTagIds = {};
      _privacy?.hold(this, false);
      _timer?.cancel();
    }
    _confirm();
    await _ingest(File(clip.path), 'mp4', tagIds);
  }

  Future<void> _toggleVideo() {
    final tagIds = {..._tagIds};
    return _capture(() async {
      var c = _controller;
      if (c == null) return;
      if (_recording) {
        try {
          await _stopRecording(c);
        } finally {
          await _reopenForPhotos(c);
        }
      } else {
        final granted = await const MethodChannel('quietake/camera')
            .invokeMethod<bool>('requestMicrophone');
        if (!mounted || !_foreground || !widget.active) return;
        if (granted != true) {
          setState(() => _status = _l10n.camMicDenied);
          return;
        }
        if (!c.enableAudio) {
          // Keep this transition in the capture queue so a permission prompt's
          // resume event cannot open a competing photo controller.
          setState(() => _controller = null);
          await c.dispose();
          await _init(enableAudio: true, recover: false);
          c = _controller;
          if (c == null) {
            await _init();
            if (mounted && _controller != null) {
              setState(() => _status = _l10n.camVideoStartFailed);
            }
            return;
          }
        }
        // Subscribe before starting so the first data event cannot be missed.
        final firstData = Completer<void>();
        final data = recordedData(CameraPlatform.instance);
        final subscription = data?.listen((_) {
          if (!firstData.isCompleted) firstData.complete();
        });
        if (data == null) firstData.complete();
        try {
          await c.startVideoRecording();
        } on CameraException {
          await subscription?.cancel();
          throw const _RecordingStartException();
        }
        _recordingTagIds = tagIds;
        _recording = true;
        _firstData = firstData;
        _recordedData = subscription;
        _privacy?.hold(this, true);
        unawaited(firstData.future.then((_) => _goLive(firstData)));
        if (mounted) setState(() {});
      }
    });
  }

  /// The recording camera is bound to the video preset, so photos get their
  /// own camera back after every recording, saved or not (decision 034). This
  /// also releases the microphone.
  Future<void> _reopenForPhotos(CameraController recorder) async {
    if (!mounted || !identical(_controller, recorder)) return;
    setState(() => _controller = null);
    await recorder.dispose();
    await _init(recover: false);
  }

  /// The recording frame and timer start with the first recorded data, not
  /// with the start call: CameraX can take seconds to stream after a rebuild.
  void _goLive(Completer<void> firstData) {
    if (!mounted || !identical(_firstData, firstData)) return;
    _recordStarted = DateTime.now();
    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _ingest(File plain, String ext, Set<String> tagIds) async {
    if (mounted) setState(() => _status = _l10n.camSaving);
    final saved = ext == 'mp4'
        ? await ingestVideo(widget.session.vault, plain, tagIds: tagIds)
        : await CaptureStore(widget.session.vault)
              .ingest(plain, extension: ext, tagIds: tagIds);
    unawaited(widget.session.sync.sync());
    if (saved.castReady && widget.session.cast.isCasting) {
      await widget.session.cast.show(VaultItem(saved.container));
    }
    if (!mounted) return;
    final notes = [
      if (!saved.albumApplied) _l10n.camTagsNotApplied,
      if (!saved.castReady) _l10n.camNotCastReady,
    ];
    if (notes.isEmpty) {
      _showPassing(_l10n.camSaved);
    } else {
      setState(() => _status = [_l10n.camSaved, ...notes].join('. '));
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: quietakeTheme(highContrast: MediaQuery.highContrastOf(context)),
    child: Builder(builder: _buildCamera),
  );

  Widget _buildCamera(BuildContext context) {
    final l10n = context.l10n;
    final c = _controller;
    final busy =
        _busy || _choosingAlbum || _releasing != null || _initializing != null;
    final cast = widget.session.cast;
    final canFlip =
        _cameras.any((c) => c.lensDirection == CameraLensDirection.front) &&
        _cameras.any((c) => c.lensDirection == CameraLensDirection.back);
    // Light status bar icons: the canvas is black in every theme.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: _cameraScaffold(context, l10n, c, busy, cast, canFlip),
    );
  }

  Widget _cameraScaffold(
    BuildContext context,
    AppLocalizations l10n,
    CameraController? c,
    bool busy,
    CastController cast,
    bool canFlip,
  ) {
    final videoControl = _labeledControl(
      IconButton(
        key: Keys.videoToggle,
        // Stop takes the centre while recording.
        iconSize: _recording ? 64 : 36,
        color: _recording ? recordAccent : onMediaCanvas,
        icon: Icon(_recording ? Icons.stop_circle : Icons.videocam_outlined),
        onPressed:
            c == null ||
                busy ||
                _countdown != null ||
                !_foreground ||
                !widget.active
            ? null
            : _toggleVideo,
        tooltip: _recording ? l10n.camStopRecording : l10n.camRecordVideo,
      ),
      _recording ? l10n.camStop : l10n.camVideo,
    );
    final photoControl = _labeledControl(
      _burstGesture(
        enabled: c != null && !_recording && !busy && _countdown == null,
        // The tooltip must not claim the long press itself.
        child: TooltipTheme(
          data: const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
          child: IconButton(
            key: Keys.shutter,
            iconSize: _recording ? 36 : 64,
            color: onMediaCanvas,
            icon: const _ShutterGlyph(),
            onPressed: c == null || _recording || busy ? null : _onShutter,
            tooltip: _countdown == null
                ? l10n.camTakePhoto
                : l10n.camCancelTimer,
          ),
        ),
      ),
      l10n.camPhoto,
    );
    return Scaffold(
      backgroundColor: mediaCanvas,
      // The camera has no text field of its own; a keyboard under a dialog or
      // the lock route must not squeeze the controls on a short landscape screen.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (c != null)
            Center(
              key: Keys.preview,
              child: Builder(
                builder: (box) => Semantics(
                  label: l10n.camPreview,
                  hint: l10n.camPreviewHint,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (tap) => _focusAt(box, tap, c),
                    onLongPressStart: (press) => _lockAt(box, press, c),
                    onScaleStart: (_) => _zoomAtPinchStart = _zoom,
                    onScaleUpdate: (pinch) {
                      if (pinch.pointerCount > 1) {
                        _setZoom(_zoomAtPinchStart * pinch.scale, c);
                      }
                    },
                    child: CameraPreview(c),
                  ),
                ),
              ),
            ),
          if (_countdown != null)
            IgnorePointer(
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '$_countdown',
                    key: Keys.captureCountdown,
                    style: const TextStyle(
                      color: onMediaCanvas,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          if (_focusRing != null &&
              (_lockedController == null || identical(_lockedController, c)))
            Positioned(
              left: _focusRing!.dx - 32,
              top: _focusRing!.dy - 32,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Container(
                      key: Keys.captureFocusRing,
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: flashRing, width: 2),
                      ),
                    ),
                    if (_lockedController != null)
                      Text(
                        l10n.camFocusLocked,
                        key: Keys.captureLock,
                        style: TextStyle(
                          color: onMediaCanvas,
                          shadows: [Shadow(blurRadius: 8)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (c != null && _grid)
            const IgnorePointer(
              child: CustomPaint(
                key: Keys.cameraGridOverlay,
                size: Size.infinite,
                painter: _GridPainter(),
              ),
            ),
          // Edge cues: a white flash after a capture, a red frame while recording.
          if (_flash || _recordStarted != null)
            IgnorePointer(
              child: AnimatedContainer(
                key: _flash ? Keys.captureFlash : Keys.captureRecordingFrame,
                // Reduced motion: the cue appears and goes without a fade.
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _flash ? flashRing : recordRing,
                    width: _flash ? 6 : 3,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          child: _controlSurface(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    ListenableBuilder(
                                      listenable: widget.session.sync,
                                      builder: (context, _) {
                                        final sync = widget.session.sync;
                                        final (
                                          icon,
                                          color,
                                        ) = switch (sync.state) {
                                          SyncState.idle => (
                                            Icons.cloud_outlined,
                                            onMediaCanvasMuted,
                                          ),
                                          SyncState.unconfigured => (
                                            Icons.smartphone_outlined,
                                            onMediaCanvasMuted,
                                          ),
                                          SyncState.syncing => (
                                            sync.isVerifying
                                                ? Icons.fact_check_outlined
                                                : Icons.cloud_upload_outlined,
                                            onMediaCanvasMuted,
                                          ),
                                          SyncState.synced => (
                                            sync.verificationCurrent
                                                ? Icons.verified_outlined
                                                : Icons.cloud_done_outlined,
                                            okAccent,
                                          ),
                                          SyncState.pending => (
                                            Icons.cloud_sync_outlined,
                                            warnAccent,
                                          ),
                                        };
                                        return Tooltip(
                                          key: Keys.captureBackup,
                                          message: sync.label,
                                          triggerMode: TooltipTriggerMode.tap,
                                          excludeFromSemantics: true,
                                          child: Semantics(
                                            label: sync.label,
                                            // Only a backup that needs
                                            // attention interrupts a shoot.
                                            liveRegion:
                                                sync.state == SyncState.pending,
                                            child: Container(
                                              width: 48,
                                              height: 48,
                                              decoration: const BoxDecoration(
                                                color: mediaScrimCircle,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(icon, color: color),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const Spacer(),
                                    // In the top row: the bottom row has no
                                    // room left on a 320 px wide screen.
                                    IconButton(
                                      key: Keys.cameraFlashMode,
                                      tooltip: switch (_flashMode) {
                                        FlashMode.auto => l10n.camFlashAuto,
                                        FlashMode.always => l10n.camFlashOn,
                                        _ => l10n.camFlashOff,
                                      },
                                      onPressed: c == null || _recording || busy
                                          ? null
                                          : () => _cycleFlash(c),
                                      icon: Icon(switch (_flashMode) {
                                        FlashMode.auto => Icons.flash_auto,
                                        FlashMode.always => Icons.flash_on,
                                        _ => Icons.flash_off,
                                      }),
                                    ),
                                    CastButton(
                                      key: Keys.captureCast,
                                      cast: cast,
                                    ),
                                    const LockButton(),
                                  ],
                                ),
                                if (_recordStarted != null)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      l10n.camRecTimer(
                                        '${DateTime.now().difference(_recordStarted!).inMinutes}:${(DateTime.now().difference(_recordStarted!).inSeconds % 60).toString().padLeft(2, '0')}',
                                      ),
                                      key: Keys.captureTimer,
                                      style: const TextStyle(
                                        color: recordAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (_recording)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        l10n.camStartingVideo,
                                        key: Keys.captureStarting,
                                        style: const TextStyle(
                                          color: recordAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_status != null && !_recording)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(_status!, key: Keys.status),
                                    ),
                                  ),
                                if (c == null &&
                                    !busy &&
                                    _foreground &&
                                    widget.active &&
                                    (_status == l10n.camNone ||
                                        _status == l10n.camUnavailable))
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      key: Keys.captureRetry,
                                      onPressed: () {
                                        setState(() => _status = null);
                                        _init(recover: false);
                                      },
                                      child: Text(l10n.castRetry),
                                    ),
                                  ),
                                if (cast.isCasting || cast.error != null)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      cast.error != null
                                          ? l10n.camCastFailed
                                          : l10n.camCasting(cast.device!.name),
                                      key: Keys.captureCastState,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (c != null && _zoom > _minZoom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextButton(
                          key: Keys.captureZoom,
                          style: TextButton.styleFrom(
                            backgroundColor: cameraCanvas,
                            foregroundColor: onMediaCanvas,
                          ),
                          onPressed: () => _setZoom(_minZoom, c),
                          child: Text(
                            '${NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 1).format(_zoom)}×',
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Tooltip(
                              message: l10n.camChooseTags,
                              child: TextButton.icon(
                                key: Keys.captureAlbum,
                                style: TextButton.styleFrom(
                                  backgroundColor: cameraCanvas,
                                  foregroundColor: onMediaCanvas,
                                  disabledForegroundColor: onMediaCanvasMuted,
                                  disabledBackgroundColor: const Color(
                                    0xff121923,
                                  ),
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed:
                                    _recording ||
                                        busy ||
                                        !_foreground ||
                                        !widget.active
                                    ? null
                                    : _chooseAlbum,
                                icon: const Icon(Icons.sell_outlined, size: 20),
                                label: Text(
                                  _tagIds.isEmpty
                                      ? l10n.camTags
                                      : _tagIds.length == 1
                                      ? widget
                                                .session
                                                .vault
                                                .catalog
                                                .albums[_tagIds.single] ??
                                            l10n.camTags
                                      : l10n.camTagCount(_tagIds.length),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          key: Keys.captureDelay,
                          style: IconButton.styleFrom(
                            backgroundColor: cameraCanvas,
                            foregroundColor: onMediaCanvas,
                          ),
                          tooltip: _delay == 0
                              ? l10n.camTimerOff
                              : l10n.camTimerSeconds(_delay),
                          onPressed: _recording || _countdown != null
                              ? null
                              : () => setState(
                                  () => _delay = switch (_delay) {
                                    0 => 3,
                                    3 => 10,
                                    _ => 0,
                                  },
                                ),
                          icon: Icon(switch (_delay) {
                            3 => Icons.timer_3,
                            10 => Icons.timer_10,
                            _ => Icons.timer_off_outlined,
                          }),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          key: Keys.cameraGrid,
                          style: IconButton.styleFrom(
                            backgroundColor: cameraCanvas,
                            foregroundColor: onMediaCanvas,
                          ),
                          tooltip: _grid ? l10n.camGridHide : l10n.camGridShow,
                          onPressed: () => setState(() => _grid = !_grid),
                          icon: Icon(_grid ? Icons.grid_off : Icons.grid_on),
                        ),
                        const SizedBox(width: 8),
                        if (canFlip)
                          IconButton.filledTonal(
                            key: Keys.cameraFlip,
                            style: IconButton.styleFrom(
                              backgroundColor: cameraCanvas,
                              foregroundColor: onMediaCanvas,
                            ),
                            tooltip: _lens == CameraLensDirection.front
                                ? l10n.camSwitchRear
                                : l10n.camSwitchFront,
                            onPressed:
                                c == null ||
                                    _recording ||
                                    busy ||
                                    !_foreground ||
                                    !widget.active
                                ? null
                                : _flipCamera,
                            icon: const Icon(Icons.cameraswitch),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _controlSurface(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...(_recording
                              ? [photoControl, videoControl]
                              : [videoControl, photoControl]),
                          _labeledControl(
                            IconButton(
                              key: Keys.openGallery,
                              iconSize: 36,
                              color: onMediaCanvas,
                              icon: const Icon(Icons.photo_library_outlined),
                              tooltip: l10n.camOpenLibrary,
                              onPressed:
                                  _recording ||
                                      _busy ||
                                      _choosingAlbum ||
                                      _releasing != null ||
                                      _galleryRequested
                                  ? null
                                  : _openGallery,
                            ),
                            l10n.camLibrary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlSurface(Widget child) => Material(
    color: cameraCanvas,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: IconTheme(
        data: const IconThemeData(color: onMediaCanvas),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(color: onMediaCanvas),
          child: child,
        ),
      ),
    ),
  );

  /// Press and hold the shutter for a burst. A custom action offers the same
  /// to screen readers, since the gesture has no button of its own.
  Widget _burstGesture({required bool enabled, required Widget child}) =>
      MergeSemantics(
        child: Semantics(
          customSemanticsActions: enabled
              ? {
                  CustomSemanticsAction(label: _l10n.camTakeBurst(_burstSize)):
                      _burst,
                }
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: enabled ? _burst : null,
            child: child,
          ),
        ),
      );

  Widget _labeledControl(Widget button, String label) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 80, child: Center(child: button)),
        ExcludeSemantics(child: Text(label, textAlign: TextAlign.center)),
        const SizedBox(height: 4),
      ],
    ),
  );
}

/// The shutter: a ring around a disc, in the button's own colour so a
/// disabled shutter dims like any other control.
class _ShutterGlyph extends StatelessWidget {
  const _ShutterGlyph();

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 64;
    final color = theme.color ?? onMediaCanvas;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size / 9),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: size / 16),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _RecordingStartException implements Exception {
  const _RecordingStartException();
}

class _RecordingStopException implements Exception {
  const _RecordingStopException();
}

/// Rule-of-thirds lines over the preview. They are never part of a capture.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x99ffffff)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
