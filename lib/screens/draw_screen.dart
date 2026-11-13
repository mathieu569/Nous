import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class Stroke {
  Stroke(this.color, this.width);
  final Color color;
  final double width;
  final List<Offset> points = [];
}

class StrokesPainter extends CustomPainter {
  StrokesPainter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      if (s.points.length == 1) {
        canvas.drawCircle(
            s.points.first, s.width / 2, Paint()..color = s.color);
        continue;
      }
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (var i = 1; i < s.points.length; i++) {
        final a = s.points[i - 1];
        final b = s.points[i];
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
      }
      path.lineTo(s.points.last.dx, s.points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(StrokesPainter oldDelegate) => true;
}

/// Écran de dessin. Renvoie le PNG (Uint8List) via Navigator.pop.
class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  static const _palette = <Color>[
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.brown,
  ];

  final List<Stroke> _strokes = [];
  Color _color = Colors.black;
  double _width = 6;
  bool _eraser = false;
  Size _canvasSize = Size.zero;

  Future<void> _save() async {
    if (_strokes.isEmpty || _canvasSize.isEmpty) return;
    final scale = 600 / _canvasSize.width;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    StrokesPainter(_strokes).paint(canvas, _canvasSize);
    final image = await recorder.endRecording().toImage(
          (_canvasSize.width * scale).round(),
          (_canvasSize.height * scale).round(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null || !mounted) return;
    Navigator.pop(context, data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dessiner'),
        actions: [
          IconButton(
            tooltip: 'Annuler le dernier trait',
            icon: const Icon(Icons.undo),
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(() => _strokes.removeLast()),
          ),
          IconButton(
            tooltip: 'Tout effacer',
            icon: const Icon(Icons.delete_outline),
            onPressed:
                _strokes.isEmpty ? null : () => setState(() => _strokes.clear()),
          ),
          IconButton(
            tooltip: 'Terminer',
            icon: const Icon(Icons.check),
            onPressed: _strokes.isEmpty ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        _canvasSize = Size(c.maxWidth, c.maxHeight);
                        return ClipRect(
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) => setState(() {
                              final s = Stroke(
                                _eraser ? Colors.white : _color,
                                _eraser ? _width * 3 : _width,
                              );
                              s.points.add(e.localPosition);
                              _strokes.add(s);
                            }),
                            onPointerMove: (e) {
                              if (_strokes.isEmpty) return;
                              setState(
                                  () => _strokes.last.points.add(e.localPosition));
                            },
                            child: CustomPaint(
                              painter: StrokesPainter(_strokes),
                              size: Size.infinite,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final col in _palette)
                          GestureDetector(
                            onTap: () => setState(() {
                              _color = col;
                              _eraser = false;
                            }),
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (!_eraser && _color == col)
                                      ? scheme.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Gomme',
                        isSelected: _eraser,
                        icon: const Icon(Icons.cleaning_services),
                        onPressed: () => setState(() => _eraser = !_eraser),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.brush, size: 18),
                      Expanded(
                        child: Slider(
                          value: _width,
                          min: 2,
                          max: 24,
                          onChanged: (v) => setState(() => _width = v),
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
  }
}
