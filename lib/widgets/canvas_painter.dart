import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/layer_model.dart';
import '../controllers/canvas_controller.dart';

class CanvasPainter extends CustomPainter {
  final List<LayerModel> layers;
  final StrokeModel? currentStroke;
  final StrokeModel? currentMirrorStroke;
  final bool showGrid;
  final bool showSymmetryLine;
  final bool symmetryEnabled;
  final int activeLayerId;
  final CanvasController controller;

  CanvasPainter({
    required this.layers,
    required this.controller,
    this.currentStroke,
    this.currentMirrorStroke,
    this.showGrid = false,
    this.showSymmetryLine = false,
    this.symmetryEnabled = false,
    this.activeLayerId = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo blanco
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    if (showGrid) _drawGrid(canvas, size);

    for (final layer in layers) {
      if (!layer.isVisible) continue;
      _drawLayerOptimized(canvas, size, layer);
    }

    if (symmetryEnabled && showSymmetryLine) {
      _drawSymmetryLine(canvas, size);
    }
  }

  void _drawLayerOptimized(
      Canvas canvas, Size size, LayerModel layer) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Verificar si hay cache válido
    final cached = controller.getLayerCache(layer.id);

    canvas.saveLayer(
      rect,
      Paint()..color = Colors.white.withOpacity(layer.opacity),
    );

    if (cached != null && layer.id != activeLayerId) {
      // Usar cache para capas no activas
      canvas.drawPicture(cached);
    } else {
      // Dibujar trazos y guardar en cache si no es la capa activa
      final recorder = ui.PictureRecorder();
      final offscreenCanvas = Canvas(recorder);

      if (layer.strokes.isNotEmpty) {
        _drawStrokesOnCanvas(offscreenCanvas, layer.strokes);
      }

      final picture = recorder.endRecording();

      // Guardar en cache solo capas no activas con trazos
      if (layer.id != activeLayerId && layer.strokes.isNotEmpty) {
        controller.setLayerCache(layer.id, picture);
      }

      canvas.drawPicture(picture);
    }

    // Dibujar trazo activo encima (sin cache)
    if (layer.id == activeLayerId) {
      if (currentStroke != null) {
        _drawStroke(canvas, currentStroke!);
      }
      if (currentMirrorStroke != null) {
        _drawStroke(canvas, currentMirrorStroke!);
      }
    }

    canvas.restore();
  }

  void _drawStrokesOnCanvas(
      Canvas canvas, List<StrokeModel> strokes) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
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
// ─── LINER ───────────────────────────────────────────────
  void _drawLiner(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ─── SHADER ──────────────────────────────────────────────
  void _drawShader(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.4)
      ..strokeWidth = stroke.strokeWidth * 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.6)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);

    final paint2 = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.6)
      ..strokeWidth = stroke.strokeWidth * 0.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint2);
  }

  // ─── DOTWORK ─────────────────────────────────────────────
  void _drawDotwork(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < stroke.points.length; i += 2) {
      canvas.drawCircle(
        stroke.points[i],
        stroke.strokeWidth / 2,
        paint,
      );
    }
  }

  // ─── FILL ────────────────────────────────────────────────
  void _drawFill(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth * 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ─── CALIGRAFÍA ──────────────────────────────────────────
  void _drawCaligrafia(
      Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    // Procesar cada 2 puntos para mejor rendimiento
    for (int i = 1; i < stroke.points.length; i += 2) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final angle = atan2(dy, dx);
      final thickness = stroke.strokeWidth *
          (0.5 + 1.5 * (sin(angle - pi / 4).abs()));
      final paint = Paint()
        ..color = color
        ..strokeWidth =
            thickness.clamp(0.5, stroke.strokeWidth * 3)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, paint);
    }
  }

  // ─── AERÓGRAFO ───────────────────────────────────────────
  void _drawAerografo(
      Canvas canvas, StrokeModel stroke, Color color) {
    // Usar seed basado en stroke para consistencia
    final seed = stroke.points.length + stroke.strokeWidth.toInt();
    final rng = Random(seed);
    final paint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.05)
      ..style = PaintingStyle.fill;

    // Procesar solo cada 3er punto para mejor rendimiento
    for (int pi = 0; pi < stroke.points.length; pi += 3) {
      final point = stroke.points[pi];
      final radius = stroke.strokeWidth * 1.5;
      for (int i = 0; i < 12; i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final dist = rng.nextDouble() * radius;
        final px = point.dx + cos(angle) * dist;
        final py = point.dy + sin(angle) * dist;
        canvas.drawCircle(
            Offset(px, py), rng.nextDouble() * 1.2, paint);
      }
    }
  }

  // ─── TEXTURA ─────────────────────────────────────────────
  void _drawTextura(
      Canvas canvas, StrokeModel stroke, Color color) {
    final seed = stroke.strokeWidth.toInt() * 31;
    final rng = Random(seed);
    if (stroke.points.length < 2) return;
    // Procesar cada 2 puntos
    for (int i = 1; i < stroke.points.length; i += 2) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      for (int j = 0; j < 3; j++) {
        final offsetX =
            (rng.nextDouble() - 0.5) * stroke.strokeWidth;
        final offsetY =
            (rng.nextDouble() - 0.5) * stroke.strokeWidth;
        final paint = Paint()
          ..color = color.withOpacity(
              stroke.opacity * (0.3 + rng.nextDouble() * 0.4))
          ..strokeWidth =
              rng.nextDouble() * stroke.strokeWidth * 0.7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(p1.dx + offsetX, p1.dy + offsetY),
          Offset(p2.dx + offsetX, p2.dy + offsetY),
          paint,
        );
      }
    }
  }

  // ─── ABSTRACTO ───────────────────────────────────────────
  void _drawAbstracto(
      Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(77);
    for (int line = 0; line < 2; line++) {
      final paint = Paint()
        ..color = color
            .withOpacity(stroke.opacity * (0.3 + line * 0.25))
        ..strokeWidth =
            stroke.strokeWidth * (0.4 + line * 0.4)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length < 2) continue;
      final path = Path();
      path.moveTo(
        stroke.points.first.dx +
            (rng.nextDouble() - 0.5) * stroke.strokeWidth,
        stroke.points.first.dy +
            (rng.nextDouble() - 0.5) * stroke.strokeWidth,
      );
      for (int i = 1; i < stroke.points.length; i += 2) {
        path.lineTo(
          stroke.points[i].dx +
              (rng.nextDouble() - 0.5) *
                  stroke.strokeWidth *
                  1.5,
          stroke.points[i].dy +
              (rng.nextDouble() - 0.5) *
                  stroke.strokeWidth *
                  1.5,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  // ─── CARBONCILLO ─────────────────────────────────────────
  void _drawCarboncillo(
      Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(55);
    const numStrands = 4;
    for (int s = 0; s < numStrands; s++) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = color.withOpacity(
            stroke.opacity * (0.2 + rng.nextDouble() * 0.35))
        ..strokeWidth = max(0.5, stroke.strokeWidth * 0.12)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final spread = stroke.strokeWidth * 0.5;
      path.moveTo(
        stroke.points.first.dx +
            (rng.nextDouble() - 0.5) * spread,
        stroke.points.first.dy +
            (rng.nextDouble() - 0.5) * spread,
      );
      for (int i = 1; i < stroke.points.length; i += 2) {
        path.lineTo(
          stroke.points[i].dx +
              (rng.nextDouble() - 0.5) * spread,
          stroke.points[i].dy +
              (rng.nextDouble() - 0.5) * spread,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  // ─── ELEMENTO ────────────────────────────────────────────
  void _drawElemento(
      Canvas canvas, StrokeModel stroke, Color color) {
    final borderPaint = Paint()
      ..color =
          Colors.black.withOpacity(stroke.opacity * 0.4)
      ..strokeWidth = stroke.strokeWidth + 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, borderPaint);

    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ─── AEROSOL ─────────────────────────────────────────────
  void _drawAerosol(
      Canvas canvas, StrokeModel stroke, Color color) {
    final seed = stroke.points.length * 3 + stroke.strokeWidth.toInt();
    final rng = Random(seed);
    final paint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.12)
      ..style = PaintingStyle.fill;

    for (int pi = 0; pi < stroke.points.length; pi += 2) {
      final point = stroke.points[pi];
      final radius = stroke.strokeWidth * 1.0;
      for (int i = 0; i < 18; i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final dist = rng.nextDouble() * radius;
        final px = point.dx + cos(angle) * dist;
        final py = point.dy + sin(angle) * dist;
        canvas.drawCircle(
            Offset(px, py), rng.nextDouble() * 1.8, paint);
      }
    }

    final corePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.35)
      ..strokeWidth = stroke.strokeWidth * 0.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);
  }

  // ─── RETOQUE ─────────────────────────────────────────────
  void _drawRetoque(
      Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.12)
      ..strokeWidth = stroke.strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.4)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ─── LUMINANCIA ──────────────────────────────────────────
  void _drawLuminancia(
      Canvas canvas, StrokeModel stroke, Color color) {
    final haloPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.12)
      ..strokeWidth = stroke.strokeWidth * 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 1.5)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, haloPaint);

    final colorPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.7)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, colorPaint);

    final corePaint = Paint()
      ..color =
          Colors.white.withOpacity(stroke.opacity * 0.8)
      ..strokeWidth = stroke.strokeWidth * 0.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);
  }

  // ─── INDUSTRIAL ──────────────────────────────────────────
  void _drawIndustrial(
      Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);

    final centerPaint = Paint()
      ..color =
          Colors.black.withOpacity(stroke.opacity * 0.25)
      ..strokeWidth = stroke.strokeWidth * 0.15
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, centerPaint);
  }

  // ─── ORGÁNICO ────────────────────────────────────────────
  void _drawOrganico(
      Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(33);
    for (int i = 1; i < stroke.points.length; i += 2) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final variation = 0.7 + rng.nextDouble() * 0.6;
      final paint = Paint()
        ..color =
            color.withOpacity(stroke.opacity * variation)
        ..strokeWidth = stroke.strokeWidth * variation
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, paint);
    }
  }

  // ─── AGUA ────────────────────────────────────────────────
  void _drawAgua(Canvas canvas, StrokeModel stroke, Color color) {
    final basePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.12)
      ..strokeWidth = stroke.strokeWidth * 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.4)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, basePaint);

    final midPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.22)
      ..strokeWidth = stroke.strokeWidth * 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, midPaint);

    final edgePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.35)
      ..strokeWidth = stroke.strokeWidth * 0.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, edgePaint);
  }
// ─── SMOOTH STROKE base ──────────────────────────────────
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

  // ─── GRID ────────────────────────────────────────────────
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..strokeWidth = 0.5;
    const gridSize = 50.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  // ─── SYMMETRY LINE ───────────────────────────────────────
  void _drawSymmetryLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
  }

  // ─── SHOULD REPAINT inteligente ──────────────────────────
  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    // Solo repintar si algo cambió
    if (oldDelegate.currentStroke != currentStroke)
      return true;
    if (oldDelegate.currentMirrorStroke != currentMirrorStroke)
      return true;
    if (oldDelegate.showGrid != showGrid) return true;
    if (oldDelegate.symmetryEnabled != symmetryEnabled)
      return true;
    if (oldDelegate.showSymmetryLine != showSymmetryLine)
      return true;
    if (oldDelegate.activeLayerId != activeLayerId)
      return true;
    if (oldDelegate.layers.length != layers.length)
      return true;
    if (controller.cacheInvalidated) {
      controller.resetCacheFlag();
      return true;
    }
    return false;
  }
}
Ahora necesitas actualizar el canvas_screen.dart para pasar el controller al CanvasPainter. Busca en canvas_screen.dart donde llamas CanvasPainter( y agrégale el parámetro controller: _controller:
painter: CanvasPainter(
  layers: _controller.layers,
  currentStroke: _controller.currentStroke,
  currentMirrorStroke: _controller.currentMirrorStroke,
  showGrid: _showGrid,
  showSymmetryLine: _controller.symmetryEnabled,
  symmetryEnabled: _controller.symmetryEnabled,
  activeLayerId: _controller.activeLayerId,
  controller: _controller, // ← agregar esta línea
),
