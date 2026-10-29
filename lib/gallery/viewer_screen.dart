import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../cast/device_picker.dart';
import '../keys.dart';
import '../brand.dart';
import '../library/name_dialog.dart';
import '../privacy/privacy_scope.dart';
import '../privacy/privacy_controller.dart';
import '../session.dart';
import '../sync/sync_settings.dart';
import '../vault/vault.dart';
import 'item.dart';
import 'preview.dart';
import 'share_dialog.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.session,
    required this.items,
    required this.initialIndex,
  });
  final Session session;
  final List<VaultItem> items;
  final int initialIndex;
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  late final _items = List<VaultItem>.of(widget.items);
  bool _sharing = false;
  bool _deleting = false;
  bool _photoZoomed = false;
  bool _controlsVisible = true;
  VaultItem get _current => _items[_index];

  /// Hidden chrome fades, then leaves the tree so finders and semantics see it
  /// gone; showing mounts it first and fades it in.
  bool _chromeMounted = true;

  void _toggleControls() {
    if (!_sharing && !_deleting) {
      setState(() {
        _controlsVisible = !_controlsVisible;
        if (_controlsVisible) _chromeMounted = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.session.cast.isCasting) widget.session.cast.show(_current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isActive =>
      mounted &&
      TickerMode.valuesOf(context).enabled &&
      ModalRoute.of(context)!.isCurrent &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing || _deleting) return;
    final item = _current;
    setState(() => _sharing = true);
    try {
      if (!buttonContext.mounted) return;
      final box = buttonContext.findRenderObject()! as RenderBox;
      await showShareCopies(context, widget.session.vault, [
        item,
      ], origin: box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (mounted && _isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _delete() async {
    if (_sharing || _deleting) return;
    final item = _current;
    setState(() => _deleting = true);
    try {
      final configured = (await SyncSettings.load()).isConfigured;
      if (!mounted || !_isActive) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: Keys.deleteDialog,
          title: Text(
            configured
                ? 'Delete from phone and NAS?'
                : 'Delete from this phone?',
          ),
          content: Text(
            'This ${item.isVideo ? 'video' : 'photo'} will be permanently removed '
            'from this phone${configured ? ' and your configured NAS' : ''}. '
            '${configured ? 'If the NAS is unavailable, deletion finishes when sync succeeds. ' : 'Pending deletions apply if you reconnect a NAS backup. '}'
            'Other backups and shared '
            'copies are unaffected. Active casting will stop.',
          ),
          actions: [
            TextButton(
              key: Keys.deleteCancel,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: Keys.deleteConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_isActive) return;
      final cast = widget.session.cast;
      if (cast.isCasting || cast.isConnecting) await cast.stop();
      await widget.session.sync.delete(item.file);
      widget.session.previews.evict(item.name);
      if (!mounted) return;
      if (_items.length == 1) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          final removedIndex = _items.indexOf(item);
          _items.removeAt(removedIndex);
          _index = removedIndex < _items.length
              ? removedIndex
              : _items.length - 1;
          _photoZoomed = false;
        });
        _controller.jumpToPage(_index);
      }
    } catch (_) {
      if (mounted && _isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not finish deleting. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: quietakeTheme(highContrast: MediaQuery.highContrastOf(context)),
    child: Builder(builder: _buildViewer),
  );

  List<Widget> _viewerActions() => [
    ListenableBuilder(
      listenable: widget.session.vault.catalog,
      builder: (context, _) {
        final favorite = widget.session.vault.catalog
            .details(_current.name)
            .favorite;
        return IconButton(
          key: Keys.viewerFavorite,
          tooltip: favorite ? 'Remove favorite' : 'Add favorite',
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          onPressed:
              _sharing || _deleting || !widget.session.vault.catalog.isLoaded
              ? null
              : () {
                  final name = _current.name;
                  updateLibrary(
                    context,
                    () => widget.session.vault.catalog.organize({
                      name,
                    }, favorite: !favorite),
                  );
                },
        );
      },
    ),
    Builder(
      builder: (buttonContext) => IconButton(
        key: Keys.viewerShare,
        tooltip: 'Share a copy',
        onPressed: _sharing || _deleting ? null : () => _share(buttonContext),
        icon: _sharing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.ios_share),
      ),
    ),
    IconButton(
      key: Keys.viewerDelete,
      tooltip: _current.isVideo ? 'Delete video' : 'Delete photo',
      onPressed: _sharing || _deleting ? null : _delete,
      icon: _deleting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_outline),
    ),
    CastButton(key: Keys.viewerCast, cast: widget.session.cast, item: _current),
  ];

  Widget _visibilityButton() => IconButton(
    key: Keys.viewerControls,
    tooltip: _controlsVisible ? 'Hide controls' : 'Show controls',
    color: onMediaCanvas,
    style: IconButton.styleFrom(backgroundColor: mediaScrim),
    onPressed: _toggleControls,
    icon: Icon(
      _controlsVisible
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
    ),
  );

  /// Hidden chrome stays in the tree for the fade and slide but takes no
  /// pointer events and leaves the semantics tree.
  Widget _chrome({required bool fromTop, required Widget child}) {
    if (!_chromeMounted) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: ExcludeSemantics(
        excluding: !_controlsVisible,
        child: AnimatedSlide(
          offset: _controlsVisible ? Offset.zero : Offset(0, fromTop ? -1 : 1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            onEnd: () {
              if (mounted && !_controlsVisible) {
                setState(() => _chromeMounted = false);
              }
            },
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AbsorbPointer(
      absorbing: _deleting,
      child: Scaffold(
        backgroundColor: mediaCanvas,
        // The bars overlay the media and fade or slide away, so the page never
        // changes size when chrome toggles.
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: _chrome(
            fromTop: true,
            child: AppBar(
              backgroundColor: mediaCanvas,
              foregroundColor: onMediaCanvas,
              title: Text(
                '${_index + 1} / ${_items.length}',
                key: Keys.viewerPosition,
              ),
              actions: const [LockButton()],
            ),
          ),
        ),
        bottomNavigationBar: _chrome(
          fromTop: false,
          child: ColoredBox(
            color: mediaCanvas,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListenableBuilder(
                    listenable: widget.session.cast,
                    builder: (context, _) {
                      final cast = widget.session.cast;
                      if (cast.error == null && !cast.isCasting) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        cast.error != null
                            ? 'Could not cast. Try again.'
                            : cast.isCasting
                            ? 'casting to ${cast.device!.name}'
                            : '',
                        key: Keys.viewerCastState,
                        style: const TextStyle(
                          color: onMediaCanvasMuted,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _viewerActions(),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            PageView.builder(
              key: Keys.viewerPager,
              scrollDirection: Axis.vertical,
              controller: _controller,
              physics: _photoZoomed
                  ? const NeverScrollableScrollPhysics()
                  : null,
              onPageChanged: (i) {
                setState(() {
                  _index = i;
                  _photoZoomed = false;
                });
                if (widget.session.cast.isCasting) {
                  widget.session.cast.show(_current);
                }
              },
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return item.isVideo
                    ? _VideoPage(
                        key: ValueKey(item.name),
                        session: widget.session,
                        item: item,
                        active: i == _index,
                        controlsVisible: _controlsVisible,
                        onTap: _toggleControls,
                      )
                    : _PhotoPage(
                        key: ValueKey(item.name),
                        vault: widget.session.vault,
                        item: item,
                        controlsVisible: _controlsVisible,
                        onTap: _toggleControls,
                        onZoomChanged: (zoomed) {
                          if (mounted &&
                              i == _index &&
                              _photoZoomed != zoomed) {
                            setState(() => _photoZoomed = zoomed);
                          }
                        },
                      );
              },
            ),
            // The one visibility toggle lives here in both states; it slides
            // below the app bar while chrome is shown.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.viewPaddingOf(context).top +
                      (_controlsVisible ? kToolbarHeight : 0),
                ),
                child: Row(
                  children: [
                    if (!_controlsVisible) ...[
                      const BackButton(
                        key: Keys.viewerBack,
                        color: onMediaCanvas,
                      ),
                      const LockButton(),
                      ListenableBuilder(
                        listenable: widget.session.cast,
                        builder: (context, _) =>
                            widget.session.cast.isCasting ||
                                widget.session.cast.isConnecting
                            ? CastButton(
                                key: Keys.viewerCast,
                                cast: widget.session.cast,
                                item: _current,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                    const Spacer(),
                    _visibilityButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhotoPage extends StatefulWidget {
  const _PhotoPage({
    super.key,
    required this.vault,
    required this.item,
    required this.onZoomChanged,
    required this.controlsVisible,
    required this.onTap,
  });
  final Vault vault;
  final VaultItem item;
  final ValueChanged<bool> onZoomChanged;
  final bool controlsVisible;
  final VoidCallback onTap;
  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

/// Decode side for a photo page: the screen's longest edge in device pixels
/// (a 4032×3024 photo is about 49 MB at the full 4096 cap, more than ten
/// times what a phone screen shows), rising to the cap once the user zooms
/// past 2x. Never above 4096.
int viewerDecodeSide(
  Size view,
  double devicePixelRatio, {
  required double zoom,
}) {
  const cap = 4096;
  if (zoom > 2) return cap;
  return min(cap, (max(view.width, view.height) * devicePixelRatio).ceil());
}

class _PhotoPageState extends State<_PhotoPage> {
  late Future<Uint8List> _bytes = widget.vault.readAll(widget.item.file);
  final _transformation = TransformationController();
  Offset _doubleTapPosition = Offset.zero;
  bool _zoomed = false;
  bool _highRes = false;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_onTransform);
  }

  // Ignore rounding near minimum zoom so ordinary paging reliably returns.
  void _onTransform() {
    final scale = _transformation.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.001;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
    final highRes = scale > 2;
    if (highRes != _highRes) setState(() => _highRes = highRes);
  }

  void _reset() => _transformation.value = Matrix4.identity();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  Widget _unavailable() => Center(
    child: TextButton.icon(
      key: Keys.viewerError,
      onPressed: () => setState(() {
        _bytes = widget.vault.readAll(widget.item.file);
      }),
      icon: const Icon(Icons.refresh),
      label: const Text('Photo unavailable. Retry'),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, snap) {
      if (snap.hasError) {
        final error = snap.error;
        if (error is PhotoTooLargeException) {
          return Center(
            child: Text(
              error.message,
              key: Keys.viewerError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: onMediaCanvasMuted),
            ),
          );
        }
        return _unavailable();
      }
      if (snap.data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            onDoubleTapDown: (details) =>
                _doubleTapPosition = details.localPosition,
            onDoubleTap: () {
              if (_transformation.value.getMaxScaleOnAxis() > 1.001) {
                _reset();
              } else {
                final point = _doubleTapPosition;
                _transformation.value = Matrix4.identity()
                  ..translateByDouble(-point.dx * 2, -point.dy * 2, 0, 1)
                  ..scaleByDouble(3, 3, 1, 1);
              }
            },
            child: InteractiveViewer(
              transformationController: _transformation,
              maxScale: 6,
              child: Center(
                child: Image(
                  image: _PhotoImage(
                    snap.data!,
                    viewerDecodeSide(
                      MediaQuery.sizeOf(context),
                      MediaQuery.devicePixelRatioOf(context),
                      zoom: _highRes ? 3 : 1,
                    ),
                  ),
                  key: Keys.viewerPhoto,
                  fit: BoxFit.contain,
                  // Keep the fitted frame while the larger decode arrives.
                  gaplessPlayback: true,
                  semanticLabel: 'Private photo',
                  errorBuilder: (_, _, _) => _unavailable(),
                ),
              ),
            ),
          ),
          if (widget.controlsVisible && _zoomed)
            Positioned(
              bottom: 16,
              right: 16,
              child: SafeArea(
                child: FilledButton.tonalIcon(
                  key: Keys.viewerFit,
                  onPressed: _reset,
                  icon: const Icon(Icons.fit_screen),
                  label: const Text('Reset to fit'),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _PhotoImage extends ResizeImage {
  _PhotoImage(Uint8List bytes, this.side)
    : super(MemoryImage(bytes), width: side, height: side);

  final int side;

  @override
  ImageStreamCompleter loadImage(
    ResizeImageKey key,
    ImageDecoderCallback decode,
  ) => super.loadImage(
    key,
    (buffer, {getTargetSize}) => decode(
      buffer,
      getTargetSize: (width, height) => photoDecodeSize(width, height, side),
    ),
  );
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    super.key,
    required this.session,
    required this.item,
    required this.active,
    required this.controlsVisible,
    required this.onTap,
  });
  final Session session;
  final VaultItem item;
  final bool active;
  final bool controlsVisible;
  final VoidCallback onTap;
  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with WidgetsBindingObserver {
  Uri? _url;
  VideoPlayerController? _player;
  bool _visible = true;
  bool _foreground = true;
  bool _wantsPlay = true;
  bool _muted = false;
  bool _failed = false;
  double? _seekPosition;
  PrivacyController? _privacy;

  void _keepUnlocked() => _privacy?.hold(
    this,
    widget.active &&
        _visible &&
        _foreground &&
        (_player?.value.isPlaying ?? false),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  void _open() {
    final url = widget.session.server.register(widget.item.file);
    _url = url;
    final player = VideoPlayerController.networkUrl(url);
    _player = player;
    player.addListener(_keepUnlocked);
    player
        .initialize()
        .then((_) async {
          if (!mounted || !identical(_player, player)) return;
          await player.setVolume(_muted ? 0 : 1);
          if (!mounted || !identical(_player, player)) return;
          setState(() {});
          _playback();
        })
        .catchError((Object _) {
          if (mounted && identical(_player, player)) {
            setState(() => _failed = true);
          }
        });
  }

  Future<void> _retry() async {
    final old = _player;
    if (old == null) return;
    old.removeListener(_keepUnlocked);
    widget.session.server.unregister(_url!);
    _url = null;
    setState(() {
      _player = null;
      _failed = false;
      _seekPosition = null;
    });
    _keepUnlocked();
    await old.dispose();
    if (!mounted) return;
    setState(_open);
  }

  void _playback() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (widget.active && _visible && _foreground && _wantsPlay) {
      player.play();
    } else {
      player.pause();
    }
  }

  void _skip(int seconds) {
    final player = _player!;
    final milliseconds = (player.value.position + Duration(seconds: seconds))
        .inMilliseconds
        .clamp(0, player.value.duration.inMilliseconds);
    player.seekTo(Duration(milliseconds: milliseconds));
  }

  Future<void> _togglePlayback() async {
    final player = _player!;
    _wantsPlay = !player.value.isPlaying;
    if (_wantsPlay && player.value.isCompleted) {
      // Finish native completion's pause/seek before restarting at the beginning.
      await player.pause();
      if (!mounted || !identical(_player, player)) return;
      await player.seekTo(Duration.zero);
    }
    if (mounted && identical(_player, player)) _playback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    final privacy = PrivacyScope.maybeOf(context);
    if (!identical(_privacy, privacy)) {
      _privacy?.hold(this, false);
      _privacy = privacy;
    }
    _keepUnlocked();
    _playback();
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _keepUnlocked();
      _playback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _keepUnlocked();
    _playback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.removeListener(_keepUnlocked);
    _privacy?.hold(this, false);
    _player?.dispose();
    if (_url != null) widget.session.server.unregister(_url!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null) return const Center(child: CircularProgressIndicator());
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) {
        if (_failed || value.hasError) {
          return Center(
            child: TextButton.icon(
              key: Keys.viewerError,
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Video unavailable. Retry'),
            ),
          );
        }
        if (!value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        final duration = value.duration;
        final position = Duration(
          milliseconds:
              (_seekPosition ?? value.position.inMilliseconds.toDouble())
                  .round(),
        );
        final completed =
            value.isCompleted ||
            (duration > Duration.zero && value.position >= duration);
        return SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: value.aspectRatio,
                          child: VideoPlayer(player, key: Keys.viewerVideo),
                        ),
                        if (value.isBuffering)
                          const CircularProgressIndicator(),
                        if (!widget.controlsVisible &&
                            !value.isPlaying &&
                            !value.isBuffering)
                          // A paused video with hidden chrome still needs a
                          // discoverable way to resume.
                          IconButton.filledTonal(
                            key: Keys.viewerPlayOverlay,
                            tooltip: completed ? 'Replay video' : 'Play video',
                            iconSize: 48,
                            onPressed: () => completed
                                ? player
                                      .seekTo(Duration.zero)
                                      .then((_) => player.play())
                                : player.play(),
                            icon: Icon(
                              completed ? Icons.replay : Icons.play_arrow,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.controlsVisible)
                ColoredBox(
                  color: mediaScrimStrong,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Semantics(
                          label: 'Video position',
                          child: Slider(
                            key: Keys.viewerSeek,
                            semanticFormatterCallback: (value) => mediaTime(
                              Duration(milliseconds: value.round()),
                            ),
                            min: 0,
                            max: duration.inMilliseconds.toDouble().clamp(
                              1,
                              double.infinity,
                            ),
                            value: position.inMilliseconds.toDouble().clamp(
                              0,
                              duration.inMilliseconds.toDouble().clamp(
                                1,
                                double.infinity,
                              ),
                            ),
                            onChangeStart: (position) =>
                                setState(() => _seekPosition = position),
                            onChanged: (position) =>
                                setState(() => _seekPosition = position),
                            onChangeEnd: (position) {
                              setState(() => _seekPosition = null);
                              player.seekTo(
                                Duration(milliseconds: position.round()),
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              key: Keys.viewerSkipBack,
                              tooltip: 'Back 10 seconds',
                              color: onMediaCanvas,
                              icon: const Icon(Icons.replay_10),
                              onPressed: () => _skip(-10),
                            ),
                            IconButton(
                              key: Keys.viewerPlay,
                              tooltip: value.isPlaying
                                  ? 'Pause video'
                                  : completed
                                  ? 'Replay video'
                                  : 'Play video',
                              color: onMediaCanvas,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : completed
                                    ? Icons.replay
                                    : Icons.play_arrow,
                              ),
                              onPressed: _togglePlayback,
                            ),
                            IconButton(
                              key: Keys.viewerSkipForward,
                              tooltip: 'Forward 10 seconds',
                              color: onMediaCanvas,
                              icon: const Icon(Icons.forward_10),
                              onPressed: () => _skip(10),
                            ),
                            IconButton(
                              key: Keys.viewerMute,
                              tooltip: _muted ? 'Unmute video' : 'Mute video',
                              color: onMediaCanvas,
                              icon: Icon(
                                _muted
                                    ? Icons.volume_off_outlined
                                    : Icons.volume_up_outlined,
                              ),
                              onPressed: () {
                                setState(() => _muted = !_muted);
                                player.setVolume(_muted ? 0 : 1);
                              },
                            ),
                            Expanded(
                              child: Text(
                                '${mediaTime(position)} / ${mediaTime(duration)}',
                                key: Keys.viewerVideoState,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: onMediaCanvas,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
