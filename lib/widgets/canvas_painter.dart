import 'package:flutter/material.dart';

class DrawPoint {
  final Offset point;
  final Paint paint;

  DrawPoint(this.point, this.paint);
}

class ErasePoint {
  final Offset point;
  final double radius;
  final double hardness;

  ErasePoint({
    required this.point,
    required this.radius,
    required this.hardness,
  });
}

class CanvasPainter extends CustomPainter {
  final List<DrawPoint?> points;
  final List<ErasePoint?> erasePoints;

  CanvasPainter({
    required this.points,
    required this.erasePoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawLines(canvas);
    _drawErase(canvas);
  }

  // =========================
  // ✏️ DIBUJO NORMAL
  // =========================
  void _drawLines(Canvas canvas) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.point,
          points[i + 1]!.point,
          points[i]!.paint,
        );
      }
    }
  }

  // =========================
  // 🧽 BORRADOR CON DUREZA REAL
  // =========================
  void _drawErase(Canvas canvas) {
    for (int i = 0; i < erasePoints.length - 1; i++) {
      if (erasePoints[i] != null && erasePoints[i + 1] != null) {
        final current = erasePoints[i]!;
        final next = erasePoints[i + 1]!;

        final path = Path()
          ..moveTo(current.point.dx, current.point.dy)
          ..lineTo(next.point.dx, next.point.dy);

        _drawEraseStroke(canvas, path, current);
      }
    }
  }

  void _drawEraseStroke(Canvas canvas, Path path, ErasePoint erase) {
    final hardness = erase.hardness.clamp(0.0, 1.0);

    // =========================
    // BORRADO PRINCIPAL
    // =========================
    final mainPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.white.withOpacity(hardness)
      ..strokeWidth = erase.radius * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, mainPaint);

    // =========================
    // DIFUMINADO (BORDE SUAVE)
    // =========================
    if (hardness < 1.0) {
      final blurSteps = 4;

      for (int i = 1; i <= blurSteps; i++) {
        final factor = i / blurSteps;

        final blurPaint = Paint()
          ..blendMode = BlendMode.dstOut
          ..color = Colors.white.withOpacity(
            (1 - hardness) * 0.5 * (1 - factor),
          )
          ..strokeWidth = erase.radius * 2 * (1 + factor)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            erase.radius * 0.4 * factor,
          )
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawPath(path, blurPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return true;
  }
}
