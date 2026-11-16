import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_controller.dart';
import '../privacy/privacy_scope.dart';

/// Lets the owner drag rectangles over a photo. Pops the chosen areas in 0..1
/// image fractions, or null when the owner goes back. The photo stays in memory
/// only while this screen is open, and the screen closes when the app locks.
class RedactScreen extends StatefulWidget {
  const RedactScreen({super.key, required this.bytes, this.initial = const []});
  final Uint8List bytes;
  final List<Rect> initial;
  @override
  State<RedactScreen> createState() => _RedactScreenState();
}

class _RedactScreenState extends State<RedactScreen> {
  static const _minimum = .02;
  late final Future<ui.Image> _decoded = _decode(widget.bytes);
  ui.Image? _image;
  late final List<Rect> _regions = [...widget.initial];
  Offset? _start;
  Rect? _draft;
  PrivacyController? _privacy;

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  void _onPrivacy() {
    if (_privacy?.enabled == false && mounted) Navigator.maybePop(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final privacy = PrivacyScope.maybeOf(context);
    if (privacy != _privacy) {
      _privacy?.removeListener(_onPrivacy);
      _privacy = privacy;
      _privacy?.addListener(_onPrivacy);
    }
  }

  @override
  void dispose() {
    _privacy?.removeListener(_onPrivacy);
    _decoded.then((image) => image.dispose(), onError: (_) {});
    super.dispose();
  }

  Offset _fraction(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _end() {
    final draft = _draft;
    setState(() {
      if (draft != null &&
          draft.width >= _minimum &&
          draft.height >= _minimum) {
        _regions.add(draft);
      }
      _draft = null;
      _start = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.redactTitle),
        actions: [
          IconButton(
            key: Keys.redactUndo,
            tooltip: l10n.redactUndo,
            onPressed: _regions.isEmpty
                ? null
                : () => setState(_regions.removeLast),
            icon: const Icon(Icons.undo),
          ),
          TextButton(
            key: Keys.redactDone,
            onPressed: () => Navigator.pop(context, List<Rect>.of(_regions)),
            child: Text(l10n.redactDone),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.redactStatus(_regions.length),
              key: const Key('redact.status'),
            ),
          ),
          Expanded(
            child: Center(
              child: FutureBuilder<ui.Image>(
                future: _decoded,
                builder: (context, snapshot) {
                  final image = snapshot.data;
                  if (snapshot.hasError) return Text(l10n.redactFailed);
                  if (image == null) return const CircularProgressIndicator();
                  _image = image;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: image.width / image.height,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final size = box.biggest;
                          return GestureDetector(
                            key: Keys.redactCanvas,
                            onPanDown: (d) => setState(
                              () => _start = _fraction(d.localPosition, size),
                            ),
                            onPanUpdate: (d) => setState(
                              () => _draft = Rect.fromPoints(
                                _start!,
                                _fraction(d.localPosition, size),
                              ),
                            ),
                            onPanEnd: (_) => _end(),
                            onPanCancel: _end,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                RawImage(image: _image, fit: BoxFit.fill),
                                CustomPaint(
                                  painter: _AreasPainter([
                                    ..._regions,
                                    ?_draft,
                                  ]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreasPainter extends CustomPainter {
  _AreasPainter(this.areas);
  final List<Rect> areas;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xCC000000);
    final edge = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final area in areas) {
      final rect = Rect.fromLTRB(
        area.left * size.width,
        area.top * size.height,
        area.right * size.width,
        area.bottom * size.height,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, edge);
    }
  }

  @override
  bool shouldRepaint(_AreasPainter old) => true;
}
