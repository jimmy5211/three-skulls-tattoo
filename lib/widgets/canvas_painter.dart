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

  void _drawLayerOptimized(Canvas canvas, Size size, LayerModel layer) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
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
      if (currentMirrorStroke != null) _drawStroke(canvas, currentMirrorStroke!);
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
      case StrokeType.liner: _drawLiner(canvas, stroke, baseColor); break;
      case StrokeType.shader: _drawShader(canvas, stroke, baseColor); break;
      case StrokeType.dotwork: _drawDotwork(canvas, stroke, baseColor); break;
      case StrokeType.fill: _drawFill(canvas, stroke, baseColor); break;
      case StrokeType.caligrafia: _drawCaligrafia(canvas, stroke, baseColor); break;
      case StrokeType.aerografo: _drawAerografo(canvas, stroke, baseColor); break;
      case StrokeType.textura: _drawTextura(canvas, stroke, baseColor); break;
      case StrokeType.abstracto: _drawAbstracto(canvas, stroke, baseColor); break;
      case StrokeType.carbonciilo: _drawCarboncillo(canvas, stroke, baseColor); break;
      case StrokeType.elemento: _drawElemento(canvas, stroke, baseColor); break;
      case StrokeType.aerosol: _drawAerosol(canvas, stroke, baseColor); break;
      case StrokeType.retoque: _drawRetoque(canvas, stroke, baseColor); break;
      case StrokeType.luminancia: _drawLuminancia(canvas, stroke, baseColor); break;
      case StrokeType.industrial: _drawIndustrial(canvas, stroke, baseColor); break;
      case StrokeType.organico: _drawOrganico(canvas, stroke, baseColor); break;
      case StrokeType.agua: _drawAgua(canvas, stroke, baseColor); break;
      case StrokeType.importado: _drawLiner(canvas, stroke, baseColor); break;
      case StrokeType.eraser: break;
    }
  }

  // ─── LINER ───────────────────────────────────────────────
  void _drawLiner(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ─── SHADER ──────────────────────────────────────────────
  void _drawShader(Canvas canvas, StrokeModel stroke, Color color) {
    for (int layer = 3; layer >= 1; layer--) {
      final paint = Paint()
        ..color = color.withOpacity(stroke.opacity * 0.08 * layer)
        ..strokeWidth = stroke.strokeWidth * (1.0 + layer * 0.6)
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.strokeWidth * layer * 0.4)
        ..style = PaintingStyle.stroke;
      _drawSmoothStroke(canvas, stroke, paint);
    }
  }

  // ─── DOTWORK ─────────────────────────────────────────────
  void _drawDotwork(Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(stroke.strokeWidth.toInt() * 7);
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    for (int i = 0; i < stroke.points.length; i += 3) {
      final variation = 0.6 + rng.nextDouble() * 0.8;
      canvas.drawCircle(stroke.points[i], stroke.strokeWidth * 0.4 * variation, paint);
    }
  }

  // ─── FILL ────────────────────────────────────────────────
  void _drawFill(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth * 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ─── CALIGRAFÍA ──────────────────────────────────────────
  void _drawCaligrafia(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      final thickness = stroke.strokeWidth * (0.3 + 2.0 * sin(angle + pi / 4).abs());
      final paint = Paint()
        ..color = color
        ..strokeWidth = thickness.clamp(0.3, stroke.strokeWidth * 3.5)
        ..strokeCap = StrokeCap.square
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, paint);
    }
  }
// ─── AERÓGRAFO ───────────────────────────────────────────
  void _drawAerografo(Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(42);
    for (int pi = 0; pi < stroke.points.length; pi += 2) {
      final point = stroke.points[pi];
      final radius = stroke.strokeWidth * 1.8;
      for (int ring = 0; ring < 3; ring++) {
        final ringRadius = radius * (ring + 1) / 3;
        final ringOpacity = stroke.opacity * (0.08 - ring * 0.02);
        final paint = Paint()
          ..color = color.withOpacity(ringOpacity)
          ..style = PaintingStyle.fill;
        final dots = 15 - ring * 4;
        for (int i = 0; i < dots; i++) {
          final angle = rng.nextDouble() * 2 * pi;
          final dist = rng.nextDouble() * ringRadius;
          canvas.drawCircle(
            Offset(point.dx + cos(angle) * dist,
                point.dy + sin(angle) * dist),
            rng.nextDouble() * 1.2 + 0.3,
            paint,
          );
        }
      }
    }
  }

  // ─── TEXTURA ─────────────────────────────────────────────
  void _drawTextura(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(99);
    final basePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.5)
      ..strokeWidth = stroke.strokeWidth * 0.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, basePaint);
    for (int i = 1; i < stroke.points.length; i += 3) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len;
      final ny = dx / len;
      final w = stroke.strokeWidth * (0.3 + rng.nextDouble() * 0.5);
      final crossPaint = Paint()
        ..color = color.withOpacity(stroke.opacity * (0.2 + rng.nextDouble() * 0.3))
        ..strokeWidth = max(0.3, stroke.strokeWidth * 0.1)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      canvas.drawLine(
        Offset(mid.dx - nx * w, mid.dy - ny * w),
        Offset(mid.dx + nx * w, mid.dy + ny * w),
        crossPaint,
      );
    }
  }

  // ─── ABSTRACTO ───────────────────────────────────────────
  void _drawAbstracto(Canvas canvas, StrokeModel stroke, Color color) {
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
          stroke.points[i].dx + (rng.nextDouble() - 0.5) * spread * 2,
          stroke.points[i].dy + (rng.nextDouble() - 0.5) * spread * 2,
        );
      }
      final paint = Paint()
        ..color = color.withOpacity(stroke.opacity * (0.4 - pass * 0.1))
        ..strokeWidth = stroke.strokeWidth * (0.8 - pass * 0.2)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  // ─── CARBONCILLO ─────────────────────────────────────────
  void _drawCarboncillo(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(55);
    final basePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.3)
      ..strokeWidth = stroke.strokeWidth * 0.9
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, basePaint);
    for (int s = 0; s < 5; s++) {
      final spread = stroke.strokeWidth * 0.7;
      final path = Path();
      path.moveTo(
        stroke.points.first.dx + (rng.nextDouble() - 0.5) * spread,
        stroke.points.first.dy + (rng.nextDouble() - 0.5) * spread,
      );
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].dx + (rng.nextDouble() - 0.5) * spread,
          stroke.points[i].dy + (rng.nextDouble() - 0.5) * spread,
        );
      }
      final paint = Paint()
        ..color = color.withOpacity(stroke.opacity * (0.1 + rng.nextDouble() * 0.25))
        ..strokeWidth = max(0.3, stroke.strokeWidth * 0.08)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
    for (int i = 2; i < stroke.points.length; i += 4) {
      final p = stroke.points[i];
      final crossPaint = Paint()
        ..color = color.withOpacity(stroke.opacity * 0.15)
        ..strokeWidth = max(0.2, stroke.strokeWidth * 0.06)
        ..style = PaintingStyle.stroke;
      final angle = rng.nextDouble() * pi;
      final len = stroke.strokeWidth * 0.4;
      canvas.drawLine(
        Offset(p.dx + cos(angle) * len, p.dy + sin(angle) * len),
        Offset(p.dx - cos(angle) * len, p.dy - sin(angle) * len),
        crossPaint,
      );
    }
  }

  // ─── ELEMENTO ────────────────────────────────────────────
  void _drawElemento(Canvas canvas, StrokeModel stroke, Color color) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(stroke.opacity * 0.2)
      ..strokeWidth = stroke.strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, shadowPaint);
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(stroke.opacity * 0.8)
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
      ..color = Colors.white.withOpacity(stroke.opacity * 0.3)
      ..strokeWidth = stroke.strokeWidth * 0.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, highlightPaint);
  }

  // ─── AEROSOL ─────────────────────────────────────────────
  void _drawAerosol(Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(88);
    for (int pi = 0; pi < stroke.points.length; pi += 2) {
      final point = stroke.points[pi];
      final radius = stroke.strokeWidth * 1.3;
      final paint = Paint()
        ..color = color.withOpacity(stroke.opacity * 0.08)
        ..style = PaintingStyle.fill;
      for (int i = 0; i < 20; i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final dist = pow(rng.nextDouble(), 0.5) * radius;
        canvas.drawCircle(
          Offset(point.dx + cos(angle) * dist,
              point.dy + sin(angle) * dist),
          rng.nextDouble() * 2.0 + 0.5,
          paint,
        );
      }
    }
    final corePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.7)
      ..strokeWidth = stroke.strokeWidth * 0.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);
    if (stroke.points.length > 5) {
      final dripPaint = Paint()
        ..color = color.withOpacity(stroke.opacity * 0.5)
        ..strokeWidth = stroke.strokeWidth * 0.15
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < stroke.points.length; i += 8) {
        final p = stroke.points[i];
        final dripLen = stroke.strokeWidth * (1 + rng.nextDouble() * 2);
        canvas.drawLine(
          p,
          Offset(p.dx + (rng.nextDouble() - 0.5) * 3, p.dy + dripLen),
          dripPaint,
        );
      }
    }
  }

  // ─── RETOQUE ─────────────────────────────────────────────
  void _drawRetoque(Canvas canvas, StrokeModel stroke, Color color) {
    final dodgePaint = Paint()
      ..color = Colors.white.withOpacity(stroke.opacity * 0.15)
      ..strokeWidth = stroke.strokeWidth * 2
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.colorDodge
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.strokeWidth * 0.6)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, dodgePaint);
    final softPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.08)
      ..strokeWidth = stroke.strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.strokeWidth * 0.3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, softPaint);
  }

  // ─── LUMINANCIA ──────────────────────────────────────────
  void _drawLuminancia(Canvas canvas, StrokeModel stroke, Color color) {
    final haloPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.08)
      ..strokeWidth = stroke.strokeWidth * 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.strokeWidth * 2.5)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, haloPaint);
    final midPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.4)
      ..strokeWidth = stroke.strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.strokeWidth * 0.5)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, midPaint);
    final colorPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.9)
      ..strokeWidth = stroke.strokeWidth * 0.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, colorPaint);
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(stroke.opacity)
      ..strokeWidth = stroke.strokeWidth * 0.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);
  }

  // ─── INDUSTRIAL ──────────────────────────────────────────
  void _drawIndustrial(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
    final weldPaint = Paint()
      ..color = Colors.black.withOpacity(stroke.opacity * 0.4)
      ..strokeWidth = stroke.strokeWidth * 0.12
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, weldPaint);
    final rivetPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.8)
      ..style = PaintingStyle.fill;
    final rivetHighlight = Paint()
      ..color = Colors.white.withOpacity(stroke.opacity * 0.5)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < stroke.points.length; i += 6) {
      final p = stroke.points[i];
      final r = stroke.strokeWidth * 0.35;
      canvas.drawCircle(p, r, rivetPaint);
      canvas.drawCircle(
          Offset(p.dx - r * 0.3, p.dy - r * 0.3), r * 0.3, rivetHighlight);
    }
  }

  // ─── ORGÁNICO ────────────────────────────────────────────
  void _drawOrganico(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(33);
    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      final mid = Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
          stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    final paint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.8)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
    for (int i = 2; i < stroke.points.length; i += 5) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len;
      final ny = dx / len;
      final side = rng.nextBool() ? 1.0 : -1.0;
      final fLen = stroke.strokeWidth * (0.3 + rng.nextDouble() * 0.5);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final filPaint = Paint()
        ..color = color.withOpacity(stroke.opacity * 0.3)
        ..strokeWidth = max(0.3, stroke.strokeWidth * 0.08)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        mid,
        Offset(mid.dx + nx * fLen * side, mid.dy + ny * fLen * side),
        filPaint,
      );
    }
  }

  // ─── AGUA ────────────────────────────────────────────────
  void _drawAgua(Canvas canvas, StrokeModel stroke, Color color) {
    final basePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.06)
      ..strokeWidth = stroke.strokeWidth * 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.strokeWidth * 1.0)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, basePaint);
    final midPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.12)
      ..strokeWidth = stroke.strokeWidth * 1.8
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.strokeWidth * 0.3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, midPaint);
    final rng = Random(11);
    for (int i = 1; i < stroke.points.length; i += 3) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len;
      final ny = dx / len;
      final w = stroke.strokeWidth * (0.8 + rng.nextDouble() * 0.4);
      final edgePaint = Paint()
        ..color = color.withOpacity(stroke.opacity * 0.25)
        ..strokeWidth = max(0.3, stroke.strokeWidth * 0.08)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      canvas.drawLine(
        Offset(mid.dx - nx * w, mid.dy - ny * w),
        Offset(mid.dx + nx * w, mid.dy + ny * w),
        edgePaint,
      );
    }
    final corePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.3)
      ..strokeWidth = stroke.strokeWidth * 0.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);
  }
// ─── SMOOTH STROKE base ──────────────────────────────────
  void _drawSmoothStroke(Canvas canvas, StrokeModel stroke, Paint paint) {
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
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    if (stroke.points.length == 2) {
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
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
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
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
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
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

  // ─── SHOULD REPAINT ──────────────────────────────────────
  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    if (oldDelegate.currentStroke != currentStroke) return true;
    if (oldDelegate.currentMirrorStroke != currentMirrorStroke) return true;
    if (oldDelegate.showGrid != showGrid) return true;
    if (oldDelegate.symmetryEnabled != symmetryEnabled) return true;
    if (oldDelegate.showSymmetryLine != showSymmetryLine) return true;
    if (oldDelegate.activeLayerId != activeLayerId) return true;
    if (oldDelegate.layers.length != layers.length) return true;
    if (controller.cacheInvalidated) {
      controller.resetCacheFlag();
      return true;
    }
    return false;
  }
}
