import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../cast/device_picker.dart';
import '../gallery/gallery_screen.dart';
import '../gallery/item.dart';
import '../keys.dart';
import '../brand.dart';
import '../privacy/privacy_controller.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import '../sync/sync_controller.dart';
import 'ingest_video.dart';
import 'capture_store.dart';
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
  static const _cameraUnavailable =
      'Camera unavailable. Check camera permission in Settings.';
  static Future<void>? _lastShutdown;
  late final Future<void>? _previousShutdown;
  final _shutdown = Completer<void>();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.back;
  bool _recording = false;
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
  bool _busy = false;
  bool _galleryRequested = false;
  bool _foreground = true;
  int _cameraEpoch = 0;
  Future<void>? _initializing;
  Future<void>? _operation;
  Future<void>? _orienting;
  Future<void>? _releasing;
  DateTime? _recordStarted;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _previousShutdown = _lastShutdown;
    _lastShutdown = _shutdown.future;
    WidgetsBinding.instance.addObserver(this);
    widget.session.cast.addListener(_onCast);
    widget.session.vault.catalog.addListener(_onCatalog);
    _init();
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
        setState(
          () => _status = 'Could not open private tags. Retry from Library.',
        );
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
          setState(() => _status = 'Could not update camera orientation.');
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
            _status = 'Capture waiting for secure save. Free storage, then lock and unlock to retry.';
          } else if (recovery.recovered > 0) {
            _status = [
              'Recovered ${recovery.recovered} capture(s).',
              if (recovery.unnormalized > 0)
                'Interrupted videos may be incomplete or may not play on a TV.',
            ].join(' ');
            unawaited(widget.session.sync.sync());
          }
        } catch (_) {
          _status = 'Could not check pending captures. Free storage and reopen the camera.';
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
        setState(() => _status = 'No camera');
        return;
      }
      _cameras = cameras;
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: enableAudio,
      );
      await controller.initialize();
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
        if (_status == _cameraUnavailable || _status == 'No camera') {
          _status = null;
        }
      });
    } catch (_) {
      await controller?.dispose();
      if (mounted && _foreground) {
        setState(() => _status = _cameraUnavailable);
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
      _tagIds = {};
      ++_cameraEpoch;
      _releasing ??= _releaseCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
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
      if (_recording && controller != null) await _stopRecording(controller);
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
    _privacy?.hold(this, false);
    _foreground = false;
    ++_cameraEpoch;
    widget.session.cast.removeListener(_onCast);
    widget.session.vault.catalog.removeListener(_onCatalog);
    if (_landscape) SystemChrome.setPreferredOrientations([]);
    _timer?.cancel();
    _releasing ??= _releaseCamera();
    unawaited(
      _releasing!.whenComplete(() {
        if (identical(_lastShutdown, _shutdown.future)) _lastShutdown = null;
        _shutdown.complete();
      }),
    );
    super.dispose();
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
    _RecordingStartException() => 'Could not start recording. Try again.',
    _RecordingStopException() => 'Could not stop recording. Try again.',
    EmptyCaptureException(extension: 'mp4') =>
      'No video frames were recorded. Try again.',
    PendingCaptureException(albumApplied: false) => 'Capture waiting for secure save. Tags were not applied; check Library after recovery.',
    PendingCaptureException() => 'Capture waiting for secure save. Free storage, then lock and unlock to retry.',
    _ => 'Could not save capture. Try again.',
  };

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
      if (mounted) {
        setState(() => _status = 'Could not switch camera. Try again.');
      }
    }
  });

  Future<void> _stopRecording(CameraController controller) async {
    final tagIds = {..._recordingTagIds};
    final XFile clip;
    try {
      clip = await controller.stopVideoRecording();
    } on CameraException {
      throw const _RecordingStopException();
    } finally {
      // A failed stop must not keep the shutter disabled or the idle lock held.
      _recording = false;
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
        await _stopRecording(c);
      } else {
        final granted = await const MethodChannel('quietake/camera')
            .invokeMethod<bool>('requestMicrophone');
        if (!mounted || !_foreground || !widget.active) return;
        if (granted != true) {
          setState(
            () => _status = 'Allow microphone access in Settings to record video. Photos are still available.',
          );
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
              setState(
                () => _status = 'Could not start video. Check camera and microphone permissions in Settings.',
              );
            }
            return;
          }
        }
        try {
          await c.startVideoRecording();
        } on CameraException {
          throw const _RecordingStartException();
        }
        _recordingTagIds = tagIds;
        _recording = true;
        _privacy?.hold(this, true);
        _recordStarted = DateTime.now();
        HapticFeedback.mediumImpact();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _ingest(File plain, String ext, Set<String> tagIds) async {
    if (mounted) setState(() => _status = 'Saving securely…');
    final saved = ext == 'mp4'
        ? await ingestVideo(widget.session.vault, plain, tagIds: tagIds)
        : await CaptureStore(widget.session.vault)
              .ingest(plain, extension: ext, tagIds: tagIds);
    unawaited(widget.session.sync.sync());
    if (saved.castReady && widget.session.cast.isCasting) {
      await widget.session.cast.show(VaultItem(saved.container));
    }
    if (mounted) {
      setState(
        () => _status = [
          'Saved securely',
          if (!saved.albumApplied)
            'Tags were not applied; organize in Library.',
          if (!saved.castReady) 'This video may not play on your TV.',
        ].join('. '),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: quietakeTheme(highContrast: MediaQuery.highContrastOf(context)),
    child: Builder(builder: _buildCamera),
  );

  Widget _buildCamera(BuildContext context) {
    final c = _controller;
    final busy =
        _busy || _choosingAlbum || _releasing != null || _initializing != null;
    final cast = widget.session.cast;
    final canFlip =
        _cameras.any((c) => c.lensDirection == CameraLensDirection.front) &&
        _cameras.any((c) => c.lensDirection == CameraLensDirection.back);
    return Scaffold(
      backgroundColor: mediaCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (c != null) Center(key: Keys.preview, child: CameraPreview(c)),
          // Edge cues: a white flash after a capture, a red frame while recording.
          if (_flash || _recording)
            IgnorePointer(
              child: AnimatedContainer(
                key: _flash ? Keys.captureFlash : Keys.captureRecordingFrame,
                duration: const Duration(milliseconds: 160),
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
                                            Icons.phone_android_outlined,
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
                                            liveRegion: true,
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
                                    CastButton(
                                      key: Keys.captureCast,
                                      cast: cast,
                                    ),
                                    const LockButton(),
                                  ],
                                ),
                                if (_recording)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'REC ${DateTime.now().difference(_recordStarted!).inMinutes}:${(DateTime.now().difference(_recordStarted!).inSeconds % 60).toString().padLeft(2, '0')}',
                                      key: Keys.captureTimer,
                                      style: const TextStyle(
                                        color: recordAccent,
                                        fontWeight: FontWeight.bold,
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
                                if (cast.isCasting || cast.error != null)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      cast.error != null
                                          ? 'Could not cast. Try again.'
                                          : 'Casting to ${cast.device!.name}',
                                      key: Keys.captureCastState,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Tooltip(
                              message: 'Choose tags for new captures',
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
                                      ? 'Tags'
                                      : _tagIds.length == 1
                                      ? widget
                                                .session
                                                .vault
                                                .catalog
                                                .albums[_tagIds.single] ??
                                            'Tags'
                                      : '${_tagIds.length} tags',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
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
                                ? 'Switch to rear camera'
                                : 'Switch to front camera',
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
                          _labeledControl(
                            IconButton(
                              key: Keys.videoToggle,
                              iconSize: 36,
                              color: _recording ? recordAccent : onMediaCanvas,
                              icon: Icon(
                                _recording
                                    ? Icons.stop_circle
                                    : Icons.videocam_outlined,
                              ),
                              onPressed:
                                  c == null ||
                                      busy ||
                                      !_foreground ||
                                      !widget.active
                                  ? null
                                  : _toggleVideo,
                              tooltip: _recording
                                  ? 'Stop recording'
                                  : 'Record video',
                            ),
                            _recording ? 'Stop' : 'Video',
                          ),
                          _labeledControl(
                            IconButton(
                              key: Keys.shutter,
                              iconSize: 64,
                              color: onMediaCanvas,
                              icon: const Icon(Icons.radio_button_checked),
                              onPressed: c == null || _recording || busy
                                  ? null
                                  : _shutter,
                              tooltip: 'Take photo',
                            ),
                            'Photo',
                          ),
                          _labeledControl(
                            IconButton(
                              key: Keys.openGallery,
                              iconSize: 36,
                              color: onMediaCanvas,
                              icon: const Icon(Icons.photo_library_outlined),
                              tooltip: 'Open Library',
                              onPressed:
                                  _recording ||
                                      _busy ||
                                      _choosingAlbum ||
                                      _releasing != null ||
                                      _galleryRequested
                                  ? null
                                  : _openGallery,
                            ),
                            'Library',
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

  Widget _labeledControl(IconButton button, String label) => Expanded(
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

class _RecordingStartException implements Exception {
  const _RecordingStartException();
}

class _RecordingStopException implements Exception {
  const _RecordingStopException();
}
