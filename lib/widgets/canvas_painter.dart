import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/layer_model.dart';
import '../controllers/canvas_controller.dart';
import 'brush_texture_painter.dart';

class CanvasPainter extends CustomPainter {
  final List<LayerModel> layers;
  final StrokeModel? currentStroke;
  final StrokeModel? currentMirrorStroke;
  final bool showGrid;
  final bool showSymmetryLine;
  final bool symmetryEnabled;
  final int activeLayerId;
  final CanvasController controller;
  final Color backgroundColor;

  CanvasPainter({
    required this.layers,
    required this.controller,
    this.currentStroke,
    this.currentMirrorStroke,
    this.showGrid = false,
    this.showSymmetryLine = false,
    this.symmetryEnabled = false,
    this.activeLayerId = 0,
    this.backgroundColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasW = controller.canvasSize.width;
    final canvasH = controller.canvasSize.height;

    // FIX: El lienzo es una hoja visible centrada en el área de trabajo.
    // La "hoja" ocupa exactamente canvasSize píxeles.
    // Todo lo que esté fuera de la hoja no se pinta.

    // 1. Fondo del área de trabajo (gris oscuro fuera del lienzo)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF3A3A3C),
    );

    // 2. Sombra de la hoja
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(
      Rect.fromLTWH(4, 4, canvasW, canvasH),
      shadowPaint,
    );

    // 3. Fondo de la hoja (color según proyecto)
    if (backgroundColor == Colors.transparent) {
      // Patrón de cuadros para indicar transparencia
      _drawCheckerboard(canvas, canvasW, canvasH);
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasW, canvasH),
        Paint()..color = backgroundColor,
      );
    }

    // 4. Grid (solo dentro del lienzo)
    if (showGrid) _drawGrid(canvas, canvasW, canvasH);

    // 5. Capas — clip al lienzo para que los trazos no salgan
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, canvasW, canvasH));

    for (final layer in layers) {
      if (!layer.isVisible) continue;
      _drawLayerOptimized(canvas, size, layer);
    }

    if (symmetryEnabled && showSymmetryLine) {
      _drawSymmetryLine(canvas, canvasW, canvasH);
    }

    canvas.restore();

    // 6. Borde de la hoja
    final borderColor = backgroundColor == Colors.transparent
        ? const Color(0xAAC0392B)
        : const Color(0x33000000);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()
        ..color = borderColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawCheckerboard(Canvas canvas, double w, double h) {
    const squareSize = 12.0;
    final paint1 = Paint()..color = const Color(0xFFCCCCCC);
    final paint2 = Paint()..color = const Color(0xFFFFFFFF);
    int row = 0;
    for (double y = 0; y < h; y += squareSize) {
      int col = 0;
      for (double x = 0; x < w; x += squareSize) {
        final paint = (row + col) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            y,
            min(squareSize, w - x),
            min(squareSize, h - y),
          ),
          paint,
        );
        col++;
      }
      row++;
    }
  }

  void _drawLayerOptimized(
      Canvas canvas, Size size, LayerModel layer) {
    final rect = Rect.fromLTWH(
        0, 0, controller.canvasSize.width, controller.canvasSize.height);
    final cached = controller.getLayerCache(layer.id);

    canvas.saveLayer(
      rect,
      Paint()..color = Colors.white.withOpacity(layer.opacity),
    );

    if (cached != null && layer.id != activeLayerId) {
      canvas.drawPicture(cached);
    } else {
      final recorder = ui.PictureRecorder();
      final offscreenCanvas = Canvas(recorder);

      if (layer.strokes.isNotEmpty) {
        for (final stroke in layer.strokes) {
          _drawStroke(offscreenCanvas, stroke);
        }
      }

      final picture = recorder.endRecording();
      if (layer.id != activeLayerId && layer.strokes.isNotEmpty) {
        controller.setLayerCache(layer.id, picture);
      }
      canvas.drawPicture(picture);
    }

    if (layer.id == activeLayerId) {
      if (currentStroke != null) _drawStroke(canvas, currentStroke!);
      if (currentMirrorStroke != null)
        _drawStroke(canvas, currentMirrorStroke!);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;
    if (stroke.type == StrokeType.eraser) {
      final paint = Paint()
        ..blendMode = BlendMode.clear
        ..strokeWidth = stroke.strokeWidth * 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      _drawSmoothStroke(canvas, stroke, paint);
      return;
    }
    final baseColor = stroke.color.withOpacity(stroke.opacity);
    switch (stroke.type) {
      case StrokeType.liner:
        _drawLiner(canvas, stroke, baseColor);
        break;
      case StrokeType.shader:
        _drawShader(canvas, stroke, baseColor);
        break;
      case StrokeType.dotwork:
        _drawDotwork(canvas, stroke, baseColor);
        break;
      case StrokeType.fill:
        _drawFill(canvas, stroke, baseColor);
        break;
      case StrokeType.caligrafia:
        _drawCaligrafia(canvas, stroke, baseColor);
        break;
      case StrokeType.aerografo:
        _drawAerografo(canvas, stroke, baseColor);
        break;
      case StrokeType.textura:
        _drawTextura(canvas, stroke, baseColor);
        break;
      case StrokeType.abstracto:
        _drawAbstracto(canvas, stroke, baseColor);
        break;
      case StrokeType.carbonciilo:
        _drawCarboncillo(canvas, stroke, baseColor);
        break;
      case StrokeType.elemento:
        _drawElemento(canvas, stroke, baseColor);
        break;
      case StrokeType.aerosol:
        _drawAerosol(canvas, stroke, baseColor);
        break;
      case StrokeType.retoque:
        _drawRetoque(canvas, stroke, baseColor);
        break;
      case StrokeType.luminancia:
        _drawLuminancia(canvas, stroke, baseColor);
        break;
      case StrokeType.industrial:
        _drawIndustrial(canvas, stroke, baseColor);
        break;
      case StrokeType.organico:
        _drawOrganico(canvas, stroke, baseColor);
        break;
      case StrokeType.agua:
        _drawAgua(canvas, stroke, baseColor);
        break;
      case StrokeType.importado:
        _drawLiner(canvas, stroke, baseColor);
        break;
      case StrokeType.eraser:
        break;
    }
  }

  void _drawLiner(Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawLiner(canvas, stroke, color);
  }

  void _drawShader(Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawShader(canvas, stroke, color);
  }

  void _drawDotwork(
      Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(stroke.strokeWidth.toInt() * 7);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < stroke.points.length; i += 3) {
      final variation = 0.6 + rng.nextDouble() * 0.8;
      canvas.drawCircle(stroke.points[i],
          stroke.strokeWidth * 0.4 * variation, paint);
    }
  }

  void _drawFill(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth * 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  void _drawCaligrafia(
      Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      final thickness = stroke.strokeWidth *
          (0.3 + 2.0 * sin(angle + pi / 4).abs());
      final paint = Paint()
        ..color = color
        ..strokeWidth =
            thickness.clamp(0.3, stroke.strokeWidth * 3.5)
        ..strokeCap = StrokeCap.square
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawAerografo(
      Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawAerografo(canvas, stroke, color);
  }

  void _drawTextura(
      Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawTextura(canvas, stroke, color);
  }

  void _drawAbstracto(
      Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(77);
    for (int pass = 0; pass < 3; pass++) {
      final spread = stroke.strokeWidth * (0.5 + pass * 0.8);
      final path = Path();
      path.moveTo(
        stroke.points.first.dx + (rng.nextDouble() - 0.5) * spread,
        stroke.points.first.dy + (rng.nextDouble() - 0.5) * spread,
      );
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].dx +
              (rng.nextDouble() - 0.5) * spread * 2,
          stroke.points[i].dy +
              (rng.nextDouble() - 0.5) * spread * 2,
        );
      }
      final paint = Paint()
        ..color = color
            .withOpacity(stroke.opacity * (0.4 - pass * 0.1))
        ..strokeWidth = stroke.strokeWidth * (0.8 - pass * 0.2)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  void _drawCarboncillo(
      Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawCarboncillo(canvas, stroke, color);
  }

  void _drawElemento(
      Canvas canvas, StrokeModel stroke, Color color) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(stroke.opacity * 0.2)
      ..strokeWidth = stroke.strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, shadowPaint);
    final borderPaint = Paint()
      ..color =
          Colors.black.withOpacity(stroke.opacity * 0.8)
      ..strokeWidth = stroke.strokeWidth + 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, borderPaint);
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
    final highlightPaint = Paint()
      ..color =
          Colors.white.withOpacity(stroke.opacity * 0.3)
      ..strokeWidth = stroke.strokeWidth * 0.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, highlightPaint);
  }

  void _drawAerosol(
      Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawAerosol(canvas, stroke, color);
  }

  void _drawRetoque(
      Canvas canvas, StrokeModel stroke, Color color) {
    final dodgePaint = Paint()
      ..color =
          Colors.white.withOpacity(stroke.opacity * 0.15)
      ..strokeWidth = stroke.strokeWidth * 2
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.colorDodge
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.6)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, dodgePaint);
    final softPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.08)
      ..strokeWidth = stroke.strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, softPaint);
  }

  void _drawLuminancia(
      Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawLuminancia(canvas, stroke, color);
  }

  void _drawIndustrial(
      Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawIndustrial(canvas, stroke, color);
  }

  void _drawOrganico(
      Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawOrganico(canvas, stroke, color);
  }

  void _drawAgua(Canvas canvas, StrokeModel stroke, Color color) {
    TextureStrokes.drawAcuarela(canvas, stroke, color);
  }

  void _drawSmoothStroke(
      Canvas canvas, StrokeModel stroke, Paint paint) {
    if (stroke.points.isEmpty) return;
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        paint.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    final path = Path();
    path.moveTo(
        stroke.points.first.dx, stroke.points.first.dy);
    if (stroke.points.length == 2) {
      path.lineTo(
          stroke.points.last.dx, stroke.points.last.dy);
    } else {
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
          stroke.points.last.dx, stroke.points.last.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawGrid(Canvas canvas, double w, double h) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 0.5;
    const gridSize = 50.0;
    for (double x = 0; x < w; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  void _drawSymmetryLine(
      Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(w / 2, 0), Offset(w / 2, h), paint);
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    if (oldDelegate.currentStroke != currentStroke)
      return true;
    if (oldDelegate.currentMirrorStroke != currentMirrorStroke)
      return true;
    if (oldDelegate.showGrid != showGrid) return true;
    if (oldDelegate.symmetryEnabled != symmetryEnabled)
      return true;
    if (oldDelegate.showSymmetryLine != showSymmetryLine)
      return true;
    if (oldDelegate.activeLayerId != activeLayerId) return true;
    if (oldDelegate.layers.length != layers.length) return true;
    if (oldDelegate.backgroundColor != backgroundColor)
      return true;
    if (controller.cacheInvalidated) {
      controller.resetCacheFlag();
      return true;
    }
    return false;
  }
}
