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
// ─── LINER — trazo técnico preciso con punta fina ────────
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

  // ─── SHADER — degradado difuminado con capas ─────────────
  void _drawShader(Canvas canvas, StrokeModel stroke, Color color) {
    for (int layer = 3; layer >= 1; layer--) {
      final paint = Paint()
        ..color = color.withOpacity(stroke.opacity * 0.08 * layer)
        ..strokeWidth = stroke.strokeWidth * (1.0 + layer * 0.6)
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, stroke.strokeWidth * layer * 0.4)
        ..style = PaintingStyle.stroke;
      _drawSmoothStroke(canvas, stroke, paint);
    }
  }

  // ─── DOTWORK — puntos precisos con variación de tamaño ───
  void _drawDotwork(Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(stroke.strokeWidth.toInt() * 7);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < stroke.points.length; i += 3) {
      final variation = 0.6 + rng.nextDouble() * 0.8;
      canvas.drawCircle(
        stroke.points[i],
        stroke.strokeWidth * 0.4 * variation,
        paint,
      );
    }
  }

  // ─── FILL — relleno sólido con bordes suaves ─────────────
  void _drawFill(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth * 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ─── CALIGRAFÍA — grosor dinámico según ángulo ───────────
  void _drawCaligrafia(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final angle = atan2(dy, dx);
      // Grosor varía según ángulo — simula pluma oblicua
      final thickness = stroke.strokeWidth *
          (0.3 + 2.0 * sin(angle + pi / 4).abs());
      final paint = Paint()
        ..color = color
        ..strokeWidth = thickness.clamp(0.3, stroke.strokeWidth * 3.5)
        ..strokeCap = StrokeCap.square
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, paint);
    }
  }

  // ─── AERÓGRAFO — nube de puntos con densidad central ─────
  void _drawAerografo(Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(42);
    for (int pi = 0; pi < stroke.points.length; pi += 2) {
      final point = stroke.points[pi];
      final radius = stroke.strokeWidth * 1.8;
      // 3 anillos de densidad decreciente
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

  // ─── TEXTURA — líneas transversales irregulares ──────────
  void _drawTextura(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(99);
    // Trazo base
    final basePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.5)
      ..strokeWidth = stroke.strokeWidth * 0.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, basePaint);

    // Líneas transversales para textura
    for (int i = 1; i < stroke.points.length; i += 3) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      // Perpendicular al trazo
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

  // ─── ABSTRACTO — trazos caóticos superpuestos ────────────
  void _drawAbstracto(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(77);
    for (int pass = 0; pass < 3; pass++) {
      final path = Path();
      final spread = stroke.strokeWidth * (0.5 + pass * 0.8);
      path.moveTo(
        stroke.points.first.dx + (rng.nextDouble() - 0.5) * spread,
        stroke.points.first.dy + (rng.nextDouble() - 0.5) * spread,
      );
      for (int i = 1; i < stroke.points.length; i++) {
        final cp = Offset(
          stroke.points[i].dx + (rng.nextDouble() - 0.5) * spread * 2,
          stroke.points[i].dy + (rng.nextDouble() - 0.5) * spread * 2,
        );
        path.lineTo(cp.dx, cp.dy);
      }
      final paint = Paint()
        ..color = color.withOpacity(stroke.opacity * (0.4 - pass * 0.1))
        ..strokeWidth = stroke.strokeWidth * (0.8 - pass * 0.2)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }      case StrokeType.aerosol:
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

// ─── CARBONCILLO — múltiples hebras con ruido ────────────
  void _drawCarboncillo(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(55);

    // Trazo base semitransparente
    final basePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.3)
      ..strokeWidth = stroke.strokeWidth * 0.9
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, basePaint);

    // 5 hebras irregulares
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
        ..color = color.withOpacity(
            stroke.opacity * (0.1 + rng.nextDouble() * 0.25))
        ..strokeWidth = max(0.3, stroke.strokeWidth * 0.08)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }

    // Líneas transversales cortas (textura de grafito)
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

  // ─── ELEMENTO — trazo con contorno definido ───────────────
  void _drawElemento(Canvas canvas, StrokeModel stroke, Color color) {
    // Sombra
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(stroke.opacity * 0.2)
      ..strokeWidth = stroke.strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, shadowPaint);

    // Borde negro
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(stroke.opacity * 0.8)
      ..strokeWidth = stroke.strokeWidth + 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, borderPaint);

    // Color principal
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);

    // Brillo interno
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(stroke.opacity * 0.3)
      ..strokeWidth = stroke.strokeWidth * 0.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, highlightPaint);
  }

  // ─── AEROSOL — spray urbano con drips ────────────────────
  void _drawAerosol(Canvas canvas, StrokeModel stroke, Color color) {
    final rng = Random(88);

    // Nube de spray exterior
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

    // Núcleo sólido
    final corePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.7)
      ..strokeWidth = stroke.strokeWidth * 0.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);

    // Efecto drip en puntos aleatorios
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
          Offset(p.dx + (rng.nextDouble() - 0.5) * 3,
              p.dy + dripLen),
          dripPaint,
        );
      }
    }
  }

  // ─── RETOQUE — dodge/burn con blendMode ──────────────────
  void _drawRetoque(Canvas canvas, StrokeModel stroke, Color color) {
    // Capa dodge (aclara)
    final dodgePaint = Paint()
      ..color = Colors.white.withOpacity(stroke.opacity * 0.15)
      ..strokeWidth = stroke.strokeWidth * 2
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.colorDodge
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.6)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, dodgePaint);

    // Capa suave encima
    final softPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.08)
      ..strokeWidth = stroke.strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, softPaint);
  }

  // ─── LUMINANCIA — neón con halo y núcleo blanco ──────────
  void _drawLuminancia(Canvas canvas, StrokeModel stroke, Color color) {
    // Halo exterior difuso
    final haloPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.08)
      ..strokeWidth = stroke.strokeWidth * 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 2.5)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, haloPaint);

    // Halo medio
    final midPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.4)
      ..strokeWidth = stroke.strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.5)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, midPaint);

    // Color principal
    final colorPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.9)
      ..strokeWidth = stroke.strokeWidth * 0.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, colorPaint);

    // Núcleo blanco brillante
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(stroke.opacity)
      ..strokeWidth = stroke.strokeWidth * 0.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);
  }

  // ─── INDUSTRIAL — trazo mecánico con remaches ────────────
  void _drawIndustrial(Canvas canvas, StrokeModel stroke, Color color) {
    // Trazo base cuadrado
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);

    // Línea central oscura (soldadura)
    final weldPaint = Paint()
      ..color = Colors.black.withOpacity(stroke.opacity * 0.4)
      ..strokeWidth = stroke.strokeWidth * 0.12
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, weldPaint);

    // Remaches — círculos a intervalos
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

  // ─── ORGÁNICO — trazo vivo con variación natural ─────────
  void _drawOrganico(Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.length < 2) return;
    final rng = Random(33);

    // Trazo base orgánico
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

    // Filamentos orgánicos laterales
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

  // ─── AGUA — acuarela con bordes húmedos ──────────────────
  void _drawAgua(Canvas canvas, StrokeModel stroke, Color color) {
    // Capa base muy difusa
    final basePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.06)
      ..strokeWidth = stroke.strokeWidth * 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 1.0)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, basePaint);

    // Capa media
    final midPaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.12)
      ..strokeWidth = stroke.strokeWidth * 1.8
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, stroke.strokeWidth * 0.3)
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, midPaint);

    // Borde húmedo irregular
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

    // Núcleo de color
    final corePaint = Paint()
      ..color = color.withOpacity(stroke.opacity * 0.3)
      ..strokeWidth = stroke.strokeWidth * 0.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, corePaint);
  }
