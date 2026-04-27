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
  final bool showCenterGuides;
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
    this.showCenterGuides = false,
    this.showSymmetryLine = false,
    this.symmetryEnabled = false,
    this.activeLayerId = 0,
    this.backgroundColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasW = controller.canvasSize.width;
    final canvasH = controller.canvasSize.height;

    // Modo overlay: layers vacío = solo trazo en curso sobre GPU RawImage.
    // En este modo se omiten el fondo gris, la sombra y el background del lienzo
    // para que el overlay sea 100% transparente y el RawImage se vea debajo.
    // Sin esta condición, la sombra (Paint opacity 0.4) oscurece el canvas
    // durante cada trazo aunque el backgroundColor sea transparent.
    final _isOverlayMode = layers.isEmpty;

    if (!_isOverlayMode) {
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
    }

    // 4. Grid (solo dentro del lienzo)
    if (showGrid) _drawGrid(canvas, canvasW, canvasH);

    // 4b. Guías del centro
    if (showCenterGuides) _drawCenterGuides(canvas, canvasW, canvasH);

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

    // OVERLAY MODE: renderizar trazo en tiempo real durante el dibujo.
    // Usa _drawOverlayStroke (no BrushStampPainter) para garantizar grosor correcto:
    // BrushStampPainter interpreta strokeWidth como radio en lugar de diámetro,
    // dando la mitad del grosor esperado. _drawOverlayStroke usa el diámetro completo
    // con MaskFilter.blur proporcional a (1-hardness) para simular el borde suave del GPU.
    // El borrador también se muestra (blanco semitransparente para indicar área borrada).
    if (_isOverlayMode && currentStroke != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, canvasW, canvasH));
      _drawOverlayStroke(canvas, currentStroke!);
      if (currentMirrorStroke != null) {
        _drawOverlayStroke(canvas, currentMirrorStroke!);
      }
      canvas.restore();
    }

    canvas.restore();

    // 6. Borde de la hoja (solo en modo normal, no overlay)
    if (!_isOverlayMode) {
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

    // FIX: eliminado clipRect — causaba recorte en sellos

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
      // Safety: solo renderizar el stroke actual para no acumular
      // Los históricos ya están horneados en la imagen via _bakeErases
      final toRender = img.currentEraseStroke != null
          ? [img.currentEraseStroke!]
          : img.eraseStrokes.length <= 3
              ? img.eraseStrokes
              : img.eraseStrokes.sublist(img.eraseStrokes.length - 3);
      for (final erase in toRender) {
        _drawEraseStroke(canvas, erase);
      }
      canvas.restore();
    }

    canvas.restore();
  }

  // FIX: handles fuera del caché — siempre se dibujan frescos
  void _drawSelectionHandles(Canvas canvas, CanvasImageModel img) {
    if (!img.isSelected) return;
    final cx = img.center.dx;
    final cy = img.center.dy;

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

  void _drawEraseStroke(Canvas canvas, EraseStroke erase) {
    if (erase.points.isEmpty) return;
    final hardness = erase.hardness.clamp(0.0, 1.0);
    // Una sola operación drawPath — evita cientos de drawCircle/gradientes
    final opacity = hardness >= 0.99 ? 1.0 : hardness.clamp(0.1, 1.0);
    final paint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = erase.radius * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (erase.points.length == 1) {
      canvas.drawCircle(erase.points.first, erase.radius,
          Paint()..blendMode = BlendMode.dstOut
                 ..color = Colors.white.withOpacity(opacity)
                 ..style = PaintingStyle.fill);
      return;
    }
    final path = Path();
    path.moveTo(erase.points.first.dx, erase.points.first.dy);
    for (int i = 1; i < erase.points.length - 1; i++) {
      final mid = Offset(
        (erase.points[i].dx + erase.points[i+1].dx) / 2,
        (erase.points[i].dy + erase.points[i+1].dy) / 2,
      );
      path.quadraticBezierTo(
          erase.points[i].dx, erase.points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(erase.points.last.dx, erase.points.last.dy);
    canvas.drawPath(path, paint);
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

    // FIX: usar cache de imágenes ordenadas (no sort() por frame)
    final layerImages = controller.getSortedImagesForLayer(layer.id);

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
        // FIX: dibujar handles ANTES del return — el early return los saltaba
        for (final img in layerImages) {
          if (img.isSelected) _drawSelectionHandles(canvas, img);
        }
        return;
      }
    }

    final strokes = layer.strokes;

    // FIX CRÍTICO: render UNA sola vez
    // Si no hay stroke activo → grabar en Picture Y usar esa Picture para mostrar
    // Antes: dibujaba 2 veces (una a canvas, una a recorder) = doble trabajo
    if (!hasCurrentStroke && strokes.isNotEmpty) {
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
      final picture = recorder.endRecording();
      controller.setLayerCache(layer.id, picture);
      canvas.drawPicture(picture); // usar la misma picture para mostrar
    } else if (!hasCurrentStroke) {
      // capa vacía sin strokes — no hay nada que dibujar
    } else {
      // Stroke activo — dibujar todo + stroke actual
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
      _drawStroke(canvas, currentStroke!);
      if (currentMirrorStroke != null) {
        _drawStroke(canvas, currentMirrorStroke!);
      }
      controller.invalidateLayerCache(layer.id);
    }

    canvas.restore();
    if (layer.opacity < 1.0) canvas.restore();

    // FIX: handles SIEMPRE fuera del caché — se dibujan frescos sobre todo lo demás
    for (final img in layerImages) {
      if (img.isSelected) _drawSelectionHandles(canvas, img);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  DIBUJO DE STROKES
  // ══════════════════════════════════════════════════════════

  // ── OVERLAY STROKE: preview en tiempo real que imita el algoritmo del GPU ────
  // Usa stamps circulares (igual que el motor C++) para que el preview coincida
  // visualmente con el resultado final. Spacing=0.08 = mismo valor que el GPU.
  void _drawOverlayStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;
    final h = stroke.hardness.clamp(0.0, 1.0);
    final radius = stroke.strokeWidth / 2;

    final isEraser = stroke.type == StrokeType.eraser;
    final color = isEraser
        ? Colors.white.withOpacity(0.5)
        : stroke.color.withOpacity(stroke.opacity);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Borde suave: MaskFilter por cada stamp (solo cuando hardness < 1.0)
    if (h < 0.95 && !isEraser) {
      paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal, radius * (1 - h) * 0.3);
    }

    // Dibujar stamps individuales igual que el GPU (spacing = 8% del diámetro)
    final minDist = 0.08 * stroke.strokeWidth;
    Offset? lastStamp;
    for (final p in stroke.points) {
      if (lastStamp == null || (p - lastStamp).distance >= minDist) {
        canvas.drawCircle(p, radius, paint);
        lastStamp = p;
      }
    }
  }

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
    // FIX: usar path simple en lugar de gradient-per-point (causaba crash de GPU)
    // El gradiente se aplica solo en el bake (canvas_screen._drawEraseOnCanvas)
    final softness = hardness >= 0.99 ? 1.0 : hardness.clamp(0.1, 1.0);
    final paint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.white.withOpacity(opacity * softness)
      ..strokeWidth = radius * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.isEmpty) return;
    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, radius,
          Paint()..blendMode = BlendMode.dstOut
                 ..color = Colors.white.withOpacity(opacity * softness)
                 ..style = PaintingStyle.fill);
      return;
    }
    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      final mid = Offset(
        (stroke.points[i].dx + stroke.points[i+1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i+1].dy) / 2,
      );
      path.quadraticBezierTo(
          stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
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

  void _drawCenterGuides(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2).withOpacity(0.5)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;
    final dashPaint = Paint()
      ..color = const Color(0xFF4A90E2).withOpacity(0.5)
      ..strokeWidth = 0.75;
    // Horizontal center
    _drawDashedLine(canvas, Offset(0, h / 2), Offset(w, h / 2), dashPaint);
    // Vertical center
    _drawDashedLine(canvas, Offset(w / 2, 0), Offset(w / 2, h), dashPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 8.0;
    const gapLen = 5.0;
    final total = (end - start).distance;
    final dir = (end - start) / total;
    double dist = 0.0;
    bool drawing = true;
    while (dist < total) {
      final segEnd = (dist + (drawing ? dashLen : gapLen)).clamp(0.0, total);
      if (drawing) canvas.drawLine(start + dir * dist, start + dir * segEnd, paint);
      dist = segEnd;
      drawing = !drawing;
    }
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

  void _drawSymmetryLine(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), paint);
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    // FIX: O(1) checks — sin iterar strokes
    if (oldDelegate.currentStroke != currentStroke) return true;
    if (oldDelegate.currentMirrorStroke != currentMirrorStroke) return true;
    // version counter cubre: endStroke, undo, redo, layer ops
    if (oldDelegate.controller.paintVersion != controller.paintVersion) return true;
    if (oldDelegate.showGrid != showGrid) return true;
    if (oldDelegate.showCenterGuides != showCenterGuides) return true;
    if (oldDelegate.activeLayerId != activeLayerId) return true;
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
