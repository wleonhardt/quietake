import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import 'locked_capture_store.dart';

/// Photo-only camera shown from the lock screen (decision 028). It never has
/// the vault key: each photo is sealed to the vault public key and published
/// at the next unlock. It shows no library, tags or settings.
class LockedCameraScreen extends StatefulWidget {
  const LockedCameraScreen({
    super.key,
    required this.store,
    required this.publicKey,
  });

  final LockedCaptureStore store;
  final Uint8List publicKey;

  @override
  State<LockedCameraScreen> createState() => _LockedCameraScreenState();
}

class _LockedCameraScreenState extends State<LockedCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String Function(AppLocalizations)? _status;
  bool _busy = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  Future<void> _open() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _status = (l) => l.camNone);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || _closing) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller?.dispose();
      if (mounted) setState(() => _status = (l) => l.camUnavailable);
    }
  }

  /// Leaving the app ends the locked camera; it must not outlive the lock.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted && !_closing) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    File? plain;
    try {
      final shot = await c.takePicture();
      plain = File(shot.path);
      await widget.store.save(
        plain,
        extension: 'jpg',
        publicKey: widget.publicKey,
      );
      if (mounted) setState(() => _status = (l) => l.lockedCameraSaved);
    } catch (_) {
      // A photo that could not be sealed is dropped rather than left as
      // plaintext: the vault is locked and there is no pending retry for it.
      try {
        if (plain != null && await plain.exists()) await plain.delete();
      } catch (_) {}
      if (mounted) setState(() => _status = (l) => l.lockedCameraFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: l10n.lockedCameraClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: c == null
                ? const SizedBox.shrink()
                : Center(child: CameraPreview(c)),
          ),
          if (_status != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _status!(l10n),
                  key: Keys.lockedStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: IconButton.filled(
              key: Keys.lockedShutter,
              iconSize: 40,
              tooltip: l10n.lockCamera,
              onPressed: c == null || _busy ? null : _shoot,
              icon: const Icon(Icons.camera_alt),
            ),
          ),
        ],
      ),
    );
  }
}
