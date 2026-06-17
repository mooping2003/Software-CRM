import 'package:flutter/material.dart';
import 'dart:math';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My GoodNotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const CanvasPage(),
    );
  }
}

enum ToolType { pen, highlighter, eraser, line, rect, circle, text, lasso }

class Stroke {
  List<Offset> points;
  Color color;
  double size;
  bool isEraser;
  ToolType tool;
  String? text;
  Offset? textPosition;

  Stroke({
    required this.points,
    required this.color,
    required this.size,
    this.isEraser = false,
    required this.tool,
    this.text,
    this.textPosition,
  });
}

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});
  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  List<Offset> _currentPoints = [];

  ToolType _tool = ToolType.pen;
  Color _penColor = Colors.black;
  double _penSize = 4.0;

  // Lasso
  List<Offset> _lassoPoints = [];
  List<int> _selectedIndexes = [];
  Offset? _lassoMoveStart;
  Offset? _lassoMoveDelta;

  Color get _currentColor {
    if (_tool == ToolType.eraser) return Colors.white;
    if (_tool == ToolType.highlighter) return _penColor.withOpacity(0.3);
    return _penColor;
  }

  double get _currentSize {
    if (_tool == ToolType.eraser) return 24.0;
    if (_tool == ToolType.highlighter) return 20.0;
    return _penSize;
  }

  void _onPanStart(DragStartDetails d) {
    _redoStack.clear();
    if (_tool == ToolType.lasso) {
      // ถ้ามี selection อยู่แล้ว ให้เริ่ม move
      if (_selectedIndexes.isNotEmpty &&
          _isInsideLasso(d.localPosition)) {
        _lassoMoveStart = d.localPosition;
        _lassoMoveDelta = Offset.zero;
      } else {
        _selectedIndexes.clear();
        _lassoPoints = [d.localPosition];
      }
    } else {
      setState(() => _currentPoints = [d.localPosition]);
    }
  }

  bool _isInsideLasso(Offset point) {
    if (_lassoPoints.length < 3) return false;
    // Simple bounding box check
    double minX = _lassoPoints.map((p) => p.dx).reduce(min);
    double maxX = _lassoPoints.map((p) => p.dx).reduce(max);
    double minY = _lassoPoints.map((p) => p.dy).reduce(min);
    double maxY = _lassoPoints.map((p) => p.dy).reduce(max);
    return point.dx >= minX &&
        point.dx <= maxX &&
        point.dy >= minY &&
        point.dy <= maxY;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_tool == ToolType.lasso) {
      if (_lassoMoveStart != null) {
        setState(() {
          _lassoMoveDelta = d.localPosition - _lassoMoveStart!;
        });
      } else {
        setState(() => _lassoPoints.add(d.localPosition));
      }
    } else {
      setState(() => _currentPoints.add(d.localPosition));
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_tool == ToolType.lasso) {
      if (_lassoMoveStart != null && _lassoMoveDelta != null) {
        // Apply move
        setState(() {
          for (final i in _selectedIndexes) {
            _strokes[i].points = _strokes[i]
                .points
                .map((p) => p + _lassoMoveDelta!)
                .toList();
            if (_strokes[i].textPosition != null) {
              _strokes[i].textPosition =
                  _strokes[i].textPosition! + _lassoMoveDelta!;
            }
          }
          _lassoMoveStart = null;
          _lassoMoveDelta = null;
          _lassoPoints = [];
          _selectedIndexes = [];
        });
      } else {
        // Find strokes inside lasso
        setState(() {
          _selectedIndexes = [];
          for (int i = 0; i < _strokes.length; i++) {
            for (final p in _strokes[i].points) {
              if (_isInsideLasso(p)) {
                _selectedIndexes.add(i);
                break;
              }
            }
          }
        });
      }
      return;
    }

    if (_currentPoints.isEmpty) return;

    setState(() {
      _strokes.add(Stroke(
        points: List.from(_currentPoints),
        color: _currentColor,
        size: _currentSize,
        isEraser: _tool == ToolType.eraser,
        tool: _tool,
      ));
      _currentPoints = [];
    });
  }

  void _addText(Offset position) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('พิมพ์ข้อความ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'พิมพ์ที่นี่...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    if (controller.text.isNotEmpty) {
      setState(() {
        _strokes.add(Stroke(
          points: [position],
          color: _penColor,
          size: _penSize,
          tool: ToolType.text,
          text: controller.text,
          textPosition: position,
        ));
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() => _redoStack.add(_strokes.removeLast()));
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() => _strokes.add(_redoStack.removeLast()));
    }
  }

  void _clear() {
    setState(() {
      _redoStack.addAll(_strokes.reversed);
      _strokes.clear();
      _lassoPoints.clear();
      _selectedIndexes.clear();
    });
  }

  Widget _toolBtn(ToolType t, IconData icon, String label) {
    final selected = _tool == t;
    return GestureDetector(
      onTap: () => setState(() {
        _tool = t;
        _lassoPoints.clear();
        _selectedIndexes.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.grey)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My GoodNotes'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _strokes.isEmpty ? null : _undo),
          IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isEmpty ? null : _redo),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _strokes.isEmpty ? null : _clear),
        ],
      ),
      body: Column(children: [
        // Tool Bar Row 1
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            _toolBtn(ToolType.pen, Icons.edit, 'ปากกา'),
            _toolBtn(ToolType.highlighter, Icons.format_color_fill, 'ไฮไลต์'),
            _toolBtn(ToolType.eraser, Icons.auto_fix_normal, 'ยางลบ'),
            _toolBtn(ToolType.line, Icons.remove, 'เส้นตรง'),
            _toolBtn(ToolType.rect, Icons.crop_square, 'สี่เหลี่ยม'),
            _toolBtn(ToolType.circle, Icons.circle_outlined, 'วงกลม'),
            _toolBtn(ToolType.text, Icons.text_fields, 'ข้อความ'),
            _toolBtn(ToolType.lasso, Icons.highlight_alt, 'Lasso'),
          ]),
        ),

        // Color + Size Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Colors.grey.shade50,
          child: Row(children: [
            for (final c in [
              Colors.black, Colors.red, Colors.blue,
              Colors.green, Colors.orange, Colors.purple,
            ])
              GestureDetector(
                onTap: () => setState(() {
                  _penColor = c;
                  if (_tool == ToolType.eraser || _tool == ToolType.lasso) {
                    _tool = ToolType.pen;
                  }
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _penColor == c ? Colors.blue : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            const Icon(Icons.line_weight, size: 16, color: Colors.grey),
            SizedBox(
              width: 100,
              child: Slider(
                value: _penSize,
                min: 1,
                max: 20,
                onChanged: (v) => setState(() => _penSize = v),
              ),
            ),
            Text('${_penSize.toStringAsFixed(0)}px',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),

        // Lasso info bar
        if (_selectedIndexes.isNotEmpty)
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('เลือก ${_selectedIndexes.length} เส้น — ลากเพื่อย้าย',
                  style: const TextStyle(fontSize: 12, color: Colors.blue)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  for (final i in _selectedIndexes.reversed.toList()) {
                    _strokes.removeAt(i);
                  }
                  _selectedIndexes.clear();
                  _lassoPoints.clear();
                }),
                child: const Text('ลบที่เลือก',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ]),
          ),

        // Canvas
        Expanded(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTapUp: _tool == ToolType.text
                ? (d) => _addText(d.localPosition)
                : null,
            child: CustomPaint(
              painter: CanvasPainter(
                strokes: _strokes,
                currentPoints: _currentPoints,
                currentColor: _currentColor,
                currentSize: _currentSize,
                currentTool: _tool,
                lassoPoints: _lassoPoints,
                selectedIndexes: _selectedIndexes,
                lassoMoveDelta: _lassoMoveDelta,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ]),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentSize;
  final ToolType currentTool;
  final List<Offset> lassoPoints;
  final List<int> selectedIndexes;
  final Offset? lassoMoveDelta;

  CanvasPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentSize,
    required this.currentTool,
    required this.lassoPoints,
    required this.selectedIndexes,
    this.lassoMoveDelta,
  });

  void _drawStroke(Canvas canvas, Stroke stroke, {Offset delta = Offset.zero}) {
    if (stroke.points.isEmpty) return;

    // Text
    if (stroke.tool == ToolType.text && stroke.text != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: stroke.text,
          style: TextStyle(
            color: stroke.color,
            fontSize: stroke.size * 4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, (stroke.textPosition ?? stroke.points.first) + delta);
      return;
    }

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = stroke.tool == ToolType.rect || stroke.tool == ToolType.circle
          ? PaintingStyle.stroke
          : PaintingStyle.stroke;

    if (stroke.isEraser) paint.blendMode = BlendMode.clear;

    final pts = stroke.points.map((p) => p + delta).toList();

    if (stroke.tool == ToolType.line && pts.length >= 2) {
      canvas.drawLine(pts.first, pts.last, paint);
    } else if (stroke.tool == ToolType.rect && pts.length >= 2) {
      canvas.drawRect(Rect.fromPoints(pts.first, pts.last), paint);
    } else if (stroke.tool == ToolType.circle && pts.length >= 2) {
      final center = Offset(
        (pts.first.dx + pts.last.dx) / 2,
        (pts.first.dy + pts.last.dy) / 2,
      );
      final radius = (pts.last - pts.first).distance / 2;
      canvas.drawCircle(center, radius, paint);
    } else {
      final path = Path();
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (int i = 0; i < strokes.length; i++) {
      final delta = selectedIndexes.contains(i) && lassoMoveDelta != null
          ? lassoMoveDelta!
          : Offset.zero;
      _drawStroke(canvas, strokes[i], delta: delta);
    }

    // Current stroke preview
    if (currentPoints.length >= 2) {
      final preview = Stroke(
        points: currentPoints,
        color: currentColor,
        size: currentSize,
        tool: currentTool,
      );
      _drawStroke(canvas, preview);
    }

    // Lasso outline
    if (lassoPoints.length > 1) {
      final lassoPaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeDash([6, 4]);
      final path = Path();
      path.moveTo(lassoPoints.first.dx, lassoPoints.first.dy);
      for (final p in lassoPoints) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, lassoPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(CanvasPainter old) => true;
}

extension on Paint {
  void strokeDash(List<double> pattern) {}
}