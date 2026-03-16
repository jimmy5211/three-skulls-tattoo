import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/layer_model.dart';

class CanvasPainter extends CustomPainter {
  final List<LayerModel> layers;
  final StrokeModel? currentStroke;
  final bool showGrid;
  final bool showSymmetryLine;
  final bool symmetryEnabled;

  CanvasPainter({
    required this.layers,
    this.currentStroke,
    this.showGrid = false,
    this.showSymmetryLine = false,
    this.symmetryEnabled = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo blanco del canvas
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Dibujar cuadrícula si está activada
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // SaveLayer para que el borrador funcione correctamente
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // Dibujar capas
    for (final layer in layers) {
      if (!layer.isVisible) continue;
      for (final stroke in layer.strokes) {
        _drawStroke(canvas, stroke, layer.opacity);
      }
    }

    // Dibujar trazo actual
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, 1.0);
    }

    // Restaurar layer
    canvas.restore();

    // Dibujar línea de simetría encima
    if (symmetryEnabled && showSymmetryLine) {
      _drawSymmetryLine(canvas, size);
    }
  }

  void _drawStroke(
    Canvas canvas,
    StrokeModel stroke,
    double layerOpacity,
  ) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Configurar borrador correctamente
    if (stroke.type == StrokeType.eraser) {
      paint
        ..color = Colors.white
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke;
    } else {
      paint
        ..color = stroke.color.withOpacity(
          stroke.opacity * layerOpacity,
        )
        ..blendMode = BlendMode.srcOver;
    }

    switch (stroke.type) {
      case StrokeType.dotwork:
        _drawDotwork(canvas, stroke, paint);
        break;
      case StrokeType.shader:
        paint.maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          2.0,
        );
        _drawSmoothStroke(canvas, stroke, paint);
        break;
      case StrokeType.eraser:
        paint.strokeWidth = stroke.strokeWidth * 2;
        _drawSmoothStroke(canvas, stroke, paint);
        break;
      default:
        _drawSmoothStroke(canvas, stroke, paint);
    }
  }

  void _drawSmoothStroke(
    Canvas canvas,
    StrokeModel stroke,
    Paint paint,
  ) {
    if (stroke.points.length < 2) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(
      stroke.points.first.dx,
      stroke.points.first.dy,
    );

    for (int i = 1; i < stroke.points.length - 1; i++) {
      final midPoint = Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
        stroke.points[i].dx,
        stroke.points[i].dy,
        midPoint.dx,
        midPoint.dy,
      );
    }

    path.lineTo(
      stroke.points.last.dx,
      stroke.points.last.dy,
    );

    canvas.drawPath(path, paint);
  }

  void _drawDotwork(
    Canvas canvas,
    StrokeModel stroke,
    Paint paint,
  ) {
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < stroke.points.length; i++) {
      if (i % 3 == 0) {
        canvas.drawCircle(
          stroke.points[i],
          stroke.strokeWidth / 2,
          paint,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;

    const gridSize = 50.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  void _drawSymmetryLine(Canvas canvas, Size size) {
    final symmetryPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      symmetryPaint,
    );
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return true;
  }
}
