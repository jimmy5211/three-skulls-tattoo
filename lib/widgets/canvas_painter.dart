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
    // opacity = hardness (0=suave, 1=duro). El OPA del slider afecta el radio
    // del borrador (enviado como radius desde canvas_screen).
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

  // ── OVERLAY STROKE: stamps con interpolación para evitar gaps ───────────────
  // Los stamps rellenos (PaintingStyle.fill) replican el GPU visualmente.
  // La interpolación lineal entre puntos consecutivos elimina el efecto
  // punteado cuando el dedo se mueve rápido (gap > stampDiameter).
  void _drawOverlayStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;
    final h = stroke.hardness.clamp(0.0, 1.0);
    final radius = stroke.strokeWidth / 2;

    final isEraser = stroke.type == StrokeType.eraser;
    final color = isEraser
        ? Colors.white.withOpacity(0.5)
        : stroke.color.withOpacity(stroke.opacity);

    // FIX CÍRCULOS: saveLayer con la opacidad total del trazo.
    // Sin saveLayer, cada stamp se dibuja con la opacidad individual y se acumulan
    // visiblemente en las superposiciones → círculos. Con saveLayer, todos los
    // stamps se dibujan al 100% dentro de una capa opaca, luego se aplica la
    // opacidad al componer la capa → mismo resultado visual que el GPU.
    final layerOpacity = isEraser ? 0.5 : stroke.opacity;
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, layerOpacity));

    final paint = Paint()
      ..color = isEraser ? Colors.white : stroke.color  // sin opacity aquí
      ..style = PaintingStyle.fill;

    if (h < 0.95 && !isEraser) {
      paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal, radius * (1 - h) * 0.3);
    }

    final minDist = max(0.5, radius * 0.08);
    int _stampCount = 0;
    const _maxStamps = 500;

    void stamp(Offset p) => canvas.drawCircle(p, radius, paint);

    Offset? last;
    for (final p in stroke.points) {
      if (_stampCount >= _maxStamps) break;
      if (last == null) {
        stamp(p); _stampCount++;
        last = p;
        continue;
      }
      final delta = p - last;
      final dist = delta.distance;
      if (dist < minDist) continue;
      int steps = (dist / minDist).floor().clamp(1, 50); // max 50 interp stamps per segment
      for (int s = 1; s <= steps; s++) {
        if (_stampCount >= _maxStamps) break;
        stamp(last! + delta * (s / steps));
        _stampCount++;
      }
      last = p;
    }
    canvas.restore(); // cierra el saveLayer de opacidad
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

// ─────────────────────────────────────────────────────────────────────────────
/// Overlay permanente que se dibuja SIEMPRE encima del RawImage del GPU.
/// Incluye: grilla, guías del centro, línea de simetría, e imágenes importadas.
/// Separado de CanvasPainter para no duplicar el renderer de strokes.
// ─────────────────────────────────────────────────────────────────────────────
class CanvasOverlayPainter extends CustomPainter {
  final CanvasController controller;
  final bool showGrid;
  final bool showCenterGuides;
  final bool showSymmetryLine;
  final int paintVersion;
  // Mirror stroke en tiempo real (mientras el dedo sigue en pantalla)
  final StrokeModel? currentMirrorStroke;

  CanvasOverlayPainter({
    required this.controller,
    required this.paintVersion,
    this.showGrid = false,
    this.showCenterGuides = false,
    this.showSymmetryLine = false,
    this.currentMirrorStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = controller.canvasSize.width;
    final h = controller.canvasSize.height;

    // Clipear al bounds del canvas para que ningún stroke (borrador, simetría,
    // imágenes) desborde visualmente hacia el fondo oscuro fuera del canvas.
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));

    // ── Grilla ──────────────────────────────────────────────────────────
    if (showGrid) {
      final p = Paint()
        ..color = Colors.grey.withOpacity(0.18)
        ..strokeWidth = 0.5;
      const gs = 50.0;
      for (double x = 0; x < w; x += gs) canvas.drawLine(Offset(x, 0), Offset(x, h), p);
      for (double y = 0; y < h; y += gs) canvas.drawLine(Offset(0, y), Offset(w, y), p);
    }

    // ── Guías del centro ─────────────────────────────────────────────────
    if (showCenterGuides) {
      final dashPaint = Paint()
        ..color = const Color(0xFF4A90E2).withOpacity(0.55)
        ..strokeWidth = 0.75;
      _dashedLine(canvas, Offset(0, h / 2), Offset(w, h / 2), dashPaint);
      _dashedLine(canvas, Offset(w / 2, 0), Offset(w / 2, h), dashPaint);
    }

    // ── Línea de simetría ────────────────────────────────────────────────
    if (showSymmetryLine) {
      canvas.drawLine(
        Offset(w / 2, 0), Offset(w / 2, h),
        Paint()
          ..color = Colors.blue.withOpacity(0.35)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Mirror stroke — guía visual de posición (no replica el stroke real) ─
    // El GPU ya dibuja el espejo permanente. Este overlay solo indica DÓNDE irá.
    //
    // Pincel: línea guía delgada (2px) al 50% opacidad. No imita el grosor real
    // para no confundir con el resultado del GPU.
    //
    // Borrador: contorno exterior (2px) de la zona que se va a borrar + línea
    // central (1px) para indicar el recorrido exacto.
    if (currentMirrorStroke != null && currentMirrorStroke!.points.length > 1) {
      final pts  = currentMirrorStroke!.points;
      final sw   = currentMirrorStroke!.strokeWidth; // diámetro real del borrador
      final isEr = currentMirrorStroke!.type == StrokeType.eraser;

      // Construir el path del recorrido
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length - 1; i++) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2,
          (pts[i].dy + pts[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);

      if (isEr) {
        // Área semi-transparente roja con exactamente el diámetro del borrador.
        canvas.drawPath(path, Paint()
          ..color = const Color(0xFFE53935).withOpacity(0.45)
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke);
      } else {
        // Pincel: línea guía de 2px al 50% del color real.
        // No usa el grosor real del brush para no confundirse con el GPU.
        canvas.drawPath(path, Paint()
          ..color = currentMirrorStroke!.color.withOpacity(0.5)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke);
      }
    }

    // ── Imágenes importadas ──────────────────────────────────────────────
    for (final img in controller.canvasImages) {
      _drawImage(canvas, img);
    }
    // Handles encima de todo (para que no queden detrás de otras imágenes)
    for (final img in controller.canvasImages) {
      if (img.isSelected) _drawHandles(canvas, img);
    }
  }

  void _drawImage(Canvas canvas, CanvasImageModel img) {
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
    if (img.flipX || img.flipY) {
      canvas.translate(cx, cy);
      canvas.scale(img.flipX ? -1.0 : 1.0, img.flipY ? -1.0 : 1.0);
      canvas.translate(-cx, -cy);
    }

    final paint = Paint()
      ..color = Colors.white.withOpacity(img.opacity)
      ..filterQuality = FilterQuality.medium;

    if (!img.hasErases) {
      canvas.drawImageRect(img.image, src, img.rect, paint);
    } else {
      canvas.saveLayer(img.rect, Paint());
      canvas.drawImageRect(img.image, src, img.rect, paint);
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

  void _drawHandles(Canvas canvas, CanvasImageModel img) {
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
    final rotHandle = img.rect.topCenter - const Offset(0, 36);
    canvas.drawLine(img.rect.topCenter, rotHandle,
        Paint()..color = Colors.white..strokeWidth = 1.5);
    canvas.drawCircle(rotHandle, 12.0,
        Paint()..color = const Color(0xFFE74C3C)..style = PaintingStyle.fill);
    canvas.drawCircle(rotHandle, 12.0, hb);
    canvas.restore();
  }

  void _drawEraseStroke(Canvas canvas, EraseStroke erase) {
    if (erase.points.isEmpty) return;
    final opacity = (erase.hardness.clamp(0.1, 1.0));
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
        (erase.points[i].dx + erase.points[i + 1].dx) / 2,
        (erase.points[i].dy + erase.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
          erase.points[i].dx, erase.points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(erase.points.last.dx, erase.points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _dashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
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

  @override
  bool shouldRepaint(CanvasOverlayPainter old) {
    if (old.showGrid != showGrid) return true;
    if (old.showCenterGuides != showCenterGuides) return true;
    if (old.showSymmetryLine != showSymmetryLine) return true;
    if (old.paintVersion != paintVersion) return true;
    if (old.currentMirrorStroke != currentMirrorStroke) return true;
    if (controller.imagesChanged) {
      controller.resetImagesChanged();
      return true;
    }
    return false;
  }
}
