import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../services/brush_tip_manager.dart';

/// Pinta un trazo estampando un brush tip PNG a lo largo del path.
/// Si no hay PNG cargado, usa un fallback de círculo suave.
class BrushStampPainter {
  /// Dibuja un trazo usando el brush tip PNG asociado al brushId del stroke.
  /// [stampSpacing] — separación entre estampas (0.1=denso, 1.0=espaciado)
  /// [opacityMultiplier] — multiplica la opacidad del stroke
  /// [sizeMultiplier] — multiplica el tamaño del stamp
  static void drawStroke(
    Canvas canvas,
    StrokeModel stroke,
    Color color, {
    double stampSpacing = 0.3,
    double opacityMultiplier = 1.0,
    double sizeMultiplier = 1.0,
  }) {
    if (stroke.points.isEmpty) return;

    final brushTip = BrushTipManager.get(stroke.brushId ?? '');

    if (brushTip != null) {
      _stampAlongPath(canvas, stroke, color, brushTip,
          stampSpacing: stampSpacing,
          opacityMultiplier: opacityMultiplier,
          sizeMultiplier: sizeMultiplier);
    } else {
      _drawRoundFallback(canvas, stroke, color);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  ESTAMPAR PNG A LO LARGO DEL TRAZO
  // ══════════════════════════════════════════════════════════

  static void _stampAlongPath(
    Canvas canvas,
    StrokeModel stroke,
    Color color,
    ui.Image tip, {
    required double stampSpacing,
    required double opacityMultiplier,
    required double sizeMultiplier,
  }) {
    final stampSize = stroke.strokeWidth * 2.0 * sizeMultiplier;
    final spacing = (stampSize * stampSpacing).clamp(1.0, double.infinity);
    final opacity = (stroke.opacity * opacityMultiplier).clamp(0.0, 1.0);

    // Punto único
    if (stroke.points.length == 1) {
      _stamp(canvas, stroke.points.first, stampSize, color, opacity, tip);
      return;
    }

    // Recorrer segmentos y estampar a intervalos regulares
    double accumulated = 0.0;
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final segLen = sqrt(dx * dx + dy * dy);
      if (segLen < 0.5) continue;

      final nx = dx / segLen;
      final ny = dy / segLen;

      double t = accumulated > 0 ? spacing - accumulated : 0;
      while (t <= segLen) {
        final px = p1.dx + nx * t;
        final py = p1.dy + ny * t;
        _stamp(canvas, Offset(px, py), stampSize, color, opacity, tip);
        t += spacing;
      }
      accumulated = (segLen - (t - spacing)) % spacing;
    }
  }

  static void _stamp(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double opacity,
    ui.Image tip,
  ) {
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(
        color.withOpacity(opacity),
        BlendMode.srcATop,
      )
      ..filterQuality = FilterQuality.medium;

    final dst = Rect.fromCenter(center: center, width: size, height: size);
    final src = Rect.fromLTWH(
        0, 0, tip.width.toDouble(), tip.height.toDouble());
    canvas.drawImageRect(tip, src, dst, paint);
  }

  // ══════════════════════════════════════════════════════════
  //  FALLBACK: TRAZO SUAVE CIRCULAR (sin PNG)
  // ══════════════════════════════════════════════════════════

  static void _drawRoundFallback(
      Canvas canvas, StrokeModel stroke, Color color) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = color.withOpacity(stroke.opacity)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2,
          paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

    if (stroke.points.length == 2) {
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    } else {
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final mid = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    }

    canvas.drawPath(path, paint);
  }
}
