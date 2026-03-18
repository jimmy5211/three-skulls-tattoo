import 'package:flutter/material.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';
import '../theme/app_theme.dart';

class BrushCard extends StatelessWidget {
  final BrushModel brush;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BrushCard({
    super.key,
    required this.brush,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.accentRed : AppTheme.borderColor,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.accentRed.withOpacity(0.2)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  brush.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brush.name,
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 14,
                      color: isActive
                          ? AppTheme.accentRed
                          : AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getBrushTypeName(brush.type),
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CustomPaint(
                    size: const Size(double.infinity, 12),
                    painter: _BrushPreviewPainter(
                      color: isActive
                          ? AppTheme.accentRed
                          : AppTheme.textGrey,
                      strokeWidth: brush.size.clamp(1, 8),
                      isDotwork: brush.type == StrokeType.dotwork,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle,
                color: AppTheme.accentRed,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _getBrushTypeName(StrokeType type) {
    switch (type) {
      case StrokeType.liner: return 'Liner';
      case StrokeType.shader: return 'Shader';
      case StrokeType.dotwork: return 'Dotwork';
      case StrokeType.fill: return 'Relleno';
      case StrokeType.eraser: return 'Borrador';
      case StrokeType.caligrafia: return 'Caligrafía';
      case StrokeType.aerografo: return 'Aerógrafo';
      case StrokeType.textura: return 'Textura';
      case StrokeType.abstracto: return 'Abstracto';
      case StrokeType.carbonciilo: return 'Carboncillo';
      case StrokeType.elemento: return 'Elemento';
      case StrokeType.aerosol: return 'Aerosol';
      case StrokeType.retoque: return 'Retoque';
      case StrokeType.luminancia: return 'Luminancia';
      case StrokeType.industrial: return 'Industrial';
      case StrokeType.organico: return 'Orgánico';
      case StrokeType.agua: return 'Agua';
      case StrokeType.importado: return 'Importado';
    }
  }
}

class _BrushPreviewPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isDotwork;

  _BrushPreviewPainter({
    required this.color,
    required this.strokeWidth,
    this.isDotwork = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isDotwork) {
      paint.style = PaintingStyle.fill;
      double x = 2;
      while (x < size.width - 2) {
        canvas.drawCircle(
          Offset(x, size.height / 2),
          strokeWidth / 2,
          paint,
        );
        x += strokeWidth * 2.5;
      }
      return;
    }

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.2,
      size.width - 4,
      size.height * 0.5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BrushPreviewPainter oldDelegate) => false;
}
