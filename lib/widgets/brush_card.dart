import 'package:flutter/material.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';
import '../theme/app_theme.dart';

class BrushCard extends StatelessWidget {
  final BrushModel brush;
  final bool isActive;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;
  final bool isCustom;

  const BrushCard({
    super.key,
    required this.brush,
    required this.isActive,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDelete,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
              child: CustomPaint(
                painter: _BrushPreviewPainter(brush: brush),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        brush.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        brush.name,
                        style: const TextStyle(
                          fontFamily: 'BlackOpsOne',
                          fontSize: 13,
                          color: AppTheme.textWhite,
                          letterSpacing: 1,
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CUSTOM',
                            style: TextStyle(
                              fontFamily: 'Raleway',
                              fontSize: 8,
                              color: AppTheme.accentRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStat('TAM', '${brush.size.round()}'),
                      const SizedBox(width: 12),
                      _buildStat(
                        'OPA',
                        '${(brush.opacity * 100).round()}%',
                      ),
                      const SizedBox(width: 12),
                      _buildStat(
                        'TIPO',
                        _getTypeName(brush.type),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: onFavoriteToggle,
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite
                        ? Colors.amber
                        : AppTheme.textGrey,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                if (isCustom)
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.textGrey,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 9,
            color: AppTheme.textGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 11,
            color: AppTheme.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getTypeName(StrokeType type) {
    switch (type) {
      case StrokeType.liner:
        return 'Liner';
      case StrokeType.shader:
        return 'Shader';
      case StrokeType.dotwork:
        return 'Dotwork';
      case StrokeType.fill:
        return 'Relleno';
      case StrokeType.eraser:
        return 'Borrador';
    }
  }
}

class _BrushPreviewPainter extends CustomPainter {
  final BrushModel brush;

  _BrushPreviewPainter({required this.brush});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(brush.opacity)
      ..strokeWidth = brush.size.clamp(1.0, 20.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (brush.type == StrokeType.shader) {
      paint.maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        2.0,
      );
    }

    if (brush.type == StrokeType.dotwork) {
      paint.style = PaintingStyle.fill;
      final dotSize = brush.size.clamp(1.0, 8.0);
      for (double x = 8; x < size.width - 8; x += 8) {
        canvas.drawCircle(
          Offset(x, size.height / 2),
          dotSize / 2,
          paint,
        );
      }
      return;
    }

    final path = Path();
    path.moveTo(8, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.2,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.8,
      size.width - 8,
      size.height * 0.4,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BrushPreviewPainter oldDelegate) => false;
}
