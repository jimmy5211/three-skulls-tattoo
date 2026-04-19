import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/layer_model.dart';
import '../models/canvas_image_model.dart';
import '../controllers/canvas_controller.dart';
import 'brush_texture_painter.dart';

// Re-export para uso en painter
export '../models/canvas_image_model.dart' show EraseStroke;

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

  void _drawCanvasImage(Canvas canvas, CanvasImageModel img) {
    if (img.rect.width <= 0 || img.rect.height <= 0) return;
    if (img.image.width <= 0 || img.image.height <= 0) return;

    final src = Rect.fromLTWH(
      0, 0, img.image.width.toDouble(), img.image.height.toDouble(),
    );
    final cx = img.center.dx;
    final cy = img.center.dy;

    canvas.save();

    if (img.rotation != 0.0) {
      canvas.translate(cx, cy);
      canvas.rotate(img.rotation);
      canvas.translate(-cx, -cy);
    }

    // FIX: eliminado canvas.clipRect(img.rect) — causaba recorte en sellos rotados.
    // El clipRect del lienzo principal ya maneja los límites del canvas.

    if (img.flipX || img.flipY) {
      canvas.translate(cx, cy);
      canvas.scale(img.flipX ? -1.0 : 1.0, img.flipY ? -1.0 : 1.0);
      canvas.translate(-cx, -cy);
    }

    final imgPaint = Paint()
      ..color = Colors.white.withOpacity(img.opacity)
      ..filterQuality = FilterQuality.medium;

    if (!img.hasErases) {
      canvas.drawImageRect(img.image, src, img.rect, imgPaint);
    } else {
      canvas.saveLayer(img.rect, Paint());
      canvas.drawImageRect(img.image, src, img.rect, imgPaint);
      for (final erase in [
        ...img.eraseStrokes,
        if (img.currentEraseStroke != null) img.currentEraseStroke!,
      ]) {
        _drawEraseStroke(canvas, erase);
      }
      canvas.restore();
    }

    canvas.restore();

    // Handles de selección
    if (img.isSelected) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(img.rotation);
      canvas.translate(-cx, -cy);

      canvas.drawRect(img.rect,
          Paint()..color = const Color(0xFF4A90E2)..strokeWidth = 2.5..style = PaintingStyle.stroke);

      final hp = Paint()..color = const Color(0xFF4A90E2)..style = PaintingStyle.fill;
      final hb = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;

      for (final c in [img.rect.topLeft, img.rect.topRight,
                       img.rect.bottomLeft, img.rect.bottomRight]) {
        canvas.drawCircle(c, 10.0, hp);
        canvas.drawCircle(c, 10.0, hb);
      }

      final rotHandleLocal = img.rect.topCenter - const Offset(0, 36);
      canvas.drawLine(img.rect.topCenter, rotHandleLocal,
          Paint()..color = Colors.white..strokeWidth = 1.5);
      canvas.drawCircle(rotHandleLocal, 12.0,
          Paint()..color = const Color(0xFFE74C3C)..style = PaintingStyle.fill);
      canvas.drawCircle(rotHandleLocal, 12.0, hb);

      canvas.restore();
    }
  }

  void _drawEraseStroke(Canvas canvas, EraseStroke erase) {
    if (erase.points.isEmpty) return;
    final erasePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.white
      ..strokeWidth = erase.radius * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (erase.points.length == 1) {
      canvas.drawCircle(
        erase.points.first,
        erase.radius,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(erase.points.first.dx, erase.points.first.dy);
    for (int i = 1; i < erase.points.length - 1; i++) {
      final mid = Offset(
        (erase.points[i].dx + erase.points[i + 1].dx) / 2,
        (erase.points[i].dy + erase.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
        erase.points[i].dx, erase.points[i].dy,
        mid.dx, mid.dy,
      );
    }
    path.lineTo(erase.points.last.dx, erase.points.last.dy);
    canvas.drawPath(path, erasePaint);
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
          Rect.fromLTWH(x, y, min(squareSize, w - x), min(squareSize, h - y)),
          paint,
        );
        col++;
      }
      row++;
    }
  }

  void _drawLayerOptimized(Canvas canvas, Size size, LayerModel layer) {
    final rect = Rect.fromLTWH(
        0, 0, controller.canvasSize.width, controller.canvasSize.height);

    final layerImages = controller.canvasImages
        .where((img) => img.layerId == layer.id)
        .toList()
      ..sort((a, b) => a.insertionIndex.compareTo(b.insertionIndex));

    final isActiveLayer = layer.id == activeLayerId;
    final hasCurrentStroke = isActiveLayer && currentStroke != null;

    if (layer.opacity < 1.0) {
      canvas.saveLayer(
          rect, Paint()..color = Colors.white.withOpacity(layer.opacity));
    }
    canvas.saveLayer(rect, Paint());

    // ── CACHÉ DE STROKES HISTÓRICOS ──
    if (!hasCurrentStroke) {
      final cached = controller.getLayerCache(layer.id);
      if (cached != null) {
        canvas.drawPicture(cached);
        canvas.restore();
        if (layer.opacity < 1.0) canvas.restore();
        return;
      }
    }

    final strokes = layer.strokes;
    int imgIdx = 0;
    for (int i = 0; i < strokes.length; i++) {
      while (imgIdx < layerImages.length &&
          layerImages[imgIdx].insertionIndex <= i) {
        _drawCanvasImage(canvas, layerImages[imgIdx]);
        imgIdx++;
      }
      _drawStroke(canvas, strokes[i]);
    }
    while (imgIdx < layerImages.length) {
      _drawCanvasImage(canvas, layerImages[imgIdx]);
      imgIdx++;
    }

    // ── GUARDAR EN CACHÉ si no hay stroke activo ──
    if (!hasCurrentStroke && layer.strokes.isNotEmpty) {
      final recorder = ui.PictureRecorder();
      final cacheCanvas = Canvas(recorder, rect);
      int ci = 0;
      for (int i = 0; i < strokes.length; i++) {
        while (ci < layerImages.length &&
            layerImages[ci].insertionIndex <= i) {
          _drawCanvasImage(cacheCanvas, layerImages[ci]);
          ci++;
        }
        _drawStroke(cacheCanvas, strokes[i]);
      }
      while (ci < layerImages.length) {
        _drawCanvasImage(cacheCanvas, layerImages[ci]);
        ci++;
      }
      controller.setLayerCache(layer.id, recorder.endRecording());
    }

    if (hasCurrentStroke) {
      _drawStroke(canvas, currentStroke!);
      if (currentMirrorStroke != null) {
        _drawStroke(canvas, currentMirrorStroke!);
      }
      controller.invalidateLayerCache(layer.id);
    }

    canvas.restore();
    if (layer.opacity < 1.0) canvas.restore();
  }

  // ══════════════════════════════════════════════════════════
  //  DIBUJO DE STROKES
  // ══════════════════════════════════════════════════════════

  void _drawStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;

    // ── BORRADOR: gradiente radial con hardness ──
    if (stroke.type == StrokeType.eraser) {
      _drawEraser(canvas, stroke);
      return;
    }

    final baseColor = stroke.color.withOpacity(stroke.opacity);

    switch (stroke.type) {
      // ── Tipos especiales con lógica propia ──
      case StrokeType.dotwork:
        _drawDotwork(canvas, stroke, baseColor);
        break;
      case StrokeType.fill:
        _drawFill(canvas, stroke, baseColor);
        break;

      // ── TODOS los demás: brush tip PNG → fallback círculo suave ──
      case StrokeType.liner:
      case StrokeType.shader:
      case StrokeType.caligrafia:
      case StrokeType.aerografo:
      case StrokeType.textura:
      case StrokeType.abstracto:
      case StrokeType.carbonciilo:
      case StrokeType.elemento:
      case StrokeType.aerosol:
      case StrokeType.retoque:
      case StrokeType.luminancia:
      case StrokeType.industrial:
      case StrokeType.organico:
      case StrokeType.agua:
      case StrokeType.importado:
        BrushStampPainter.drawStroke(canvas, stroke, baseColor);
        break;

      case StrokeType.eraser:
        break;
    }
  }

  // ── BORRADOR ──

  void _drawEraser(Canvas canvas, StrokeModel stroke) {
    final radius = stroke.strokeWidth.toDouble();
    final hardness = stroke.hardness.clamp(0.0, 1.0);
    final opacity = stroke.opacity.clamp(0.0, 1.0);

    void stamp(Offset point) {
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            point,
            radius,
            [
              Colors.white.withOpacity(opacity),
              Colors.white.withOpacity(hardness * opacity),
              Colors.transparent,
            ],
            [0.0, hardness.clamp(0.01, 0.99), 1.0],
          )
          ..blendMode = BlendMode.dstOut,
      );
    }

    void fillGap(Offset p1, Offset p2) {
      final dist = (p2 - p1).distance;
      final steps = (dist / (radius * 0.5)).ceil().clamp(1, 10);
      for (int s = 1; s < steps; s++) {
        stamp(Offset.lerp(p1, p2, s / steps)!);
      }
    }

    for (int i = 0; i < stroke.points.length; i++) {
      stamp(stroke.points[i]);
      if (i > 0) fillGap(stroke.points[i - 1], stroke.points[i]);
    }
  }

  // ── DOTWORK ──

  void _drawDotwork(Canvas canvas, StrokeModel stroke, Color color) {
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

  // ── RELLENO ──

  void _drawFill(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke.strokeWidth * 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _drawSmoothStroke(canvas, stroke, paint);
  }

  // ── TRAZO SUAVE (utilidad) ──

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
          stroke.points[i].dx, stroke.points[i].dy,
          midPoint.dx, midPoint.dy,
        );
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    }
    canvas.drawPath(path, paint);
  }

  // ── GRID Y SIMETRÍA ──

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

  void _drawSymmetryLine(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), paint);
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    if (oldDelegate.currentStroke != currentStroke) return true;
    if (oldDelegate.currentMirrorStroke != currentMirrorStroke) return true;
    if (oldDelegate.showGrid != showGrid) return true;
    if (oldDelegate.symmetryEnabled != symmetryEnabled) return true;
    if (oldDelegate.showSymmetryLine != showSymmetryLine) return true;
    if (oldDelegate.activeLayerId != activeLayerId) return true;
    if (oldDelegate.layers.length != layers.length) return true;
    for (int i = 0; i < layers.length; i++) {
      if (oldDelegate.layers[i].strokes.length != layers[i].strokes.length) return true;
    }
    if (oldDelegate.backgroundColor != backgroundColor) return true;
    if (controller.imagesChanged) {
      controller.resetImagesChanged();
      return true;
    }
    if (controller.canvasImages.any((img) => img.currentEraseStroke != null)) {
      return true;
    }
    if (controller.cacheInvalidated) {
      controller.resetCacheFlag();
      return true;
    }
    return false;
  }
}
