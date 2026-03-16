import 'package:flutter/material.dart';
import '../models/brush_model.dart';
import '../theme/app_theme.dart';

class BrushSelector extends StatefulWidget {
  final BrushModel activeBrush;
  final List<BrushModel> brushes;
  final Function(BrushModel) onBrushSelected;
  final Function(double) onSizeChanged;
  final Function(double) onOpacityChanged;

  const BrushSelector({
    super.key,
    required this.activeBrush,
    required this.brushes,
    required this.onBrushSelected,
    required this.onSizeChanged,
    required this.onOpacityChanged,
  });

  @override
  State<BrushSelector> createState() => _BrushSelectorState();
}

class _BrushSelectorState extends State<BrushSelector> {
  bool _showOptions = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: AppTheme.deepBlack.withOpacity(0.95),
        border: const Border(
          right: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Botón opciones "..."
          _buildOptionsButton(),
          const SizedBox(height: 4),
          // Lista de pinceles
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: 4,
              ),
              itemCount: widget.brushes.length,
              itemBuilder: (context, index) {
                final brush = widget.brushes[index];
                final isActive =
                    brush.id == widget.activeBrush.id;
                return _buildBrushItem(brush, isActive);
              },
            ),
          ),
          // Divisor
          Container(
            height: 0.5,
            color: AppTheme.borderColor,
          ),
          // Control tamaño
          _buildSizeControl(),
          // Control opacidad
          _buildOpacityControl(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionsButton() {
    return GestureDetector(
      onTap: () => _showBrushOptions(context),
      child: Container(
        width: 52,
        height: 36,
        margin: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.more_horiz,
              color: AppTheme.textGrey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrushItem(BrushModel brush, bool isActive) {
    return GestureDetector(
      onTap: () => widget.onBrushSelected(brush),
      child: Container(
        width: 52,
        height: 64,
        margin: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.2)
              : AppTheme.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview del pincel
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: CustomPaint(
                painter: _MiniPainter(brush: brush),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              brush.name.split(' ').first,
              style: TextStyle(
                fontSize: 7,
                color: isActive
                    ? AppTheme.accentRed
                    : AppTheme.textGrey,
                fontFamily: 'Raleway',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(
            'TAM',
            style: TextStyle(
              fontSize: 8,
              color: AppTheme.textGrey,
              fontFamily: 'Raleway',
            ),
          ),
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  activeTrackColor: AppTheme.accentRed,
                  thumbColor: AppTheme.accentRed,
                  inactiveTrackColor: AppTheme.borderColor,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: widget.activeBrush.size.clamp(
                    1.0,
                    50.0,
                  ),
                  min: 1.0,
                  max: 50.0,
                  onChanged: widget.onSizeChanged,
                ),
              ),
            ),
          ),
          Text(
            '${widget.activeBrush.size.round()}',
            style: TextStyle(
              fontSize: 8,
              color: AppTheme.textWhite,
              fontFamily: 'Raleway',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpacityControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(
            'OPA',
            style: TextStyle(
              fontSize: 8,
              color: AppTheme.textGrey,
              fontFamily: 'Raleway',
            ),
          ),
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  activeTrackColor: AppTheme.accentRed,
                  thumbColor: AppTheme.accentRed,
                  inactiveTrackColor: AppTheme.borderColor,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: widget.activeBrush.opacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: widget.onOpacityChanged,
                ),
              ),
            ),
          ),
          Text(
            '${(widget.activeBrush.opacity * 100).round()}%',
            style: TextStyle(
              fontSize: 8,
              color: AppTheme.textWhite,
              fontFamily: 'Raleway',
            ),
          ),
        ],
      ),
    );
  }

  void _showBrushOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            '🖌️ OPCIONES DE PINCELES',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 14,
              color: AppTheme.textWhite,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          _buildOptionTile(
            '➕',
            'Crear nuevo pincel',
            'Diseña tu propio pincel',
            () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/brushes');
            },
          ),
          _buildOptionTile(
            '📥',
            'Importar pincel',
            'Importa archivo .brush',
            () => Navigator.pop(context),
          ),
          _buildOptionTile(
            '⭐',
            'Mis pinceles favoritos',
            'Ver pinceles guardados',
            () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/brushes');
            },
          ),
          _buildOptionTile(
            '🗑️',
            'Limpiar capa actual',
            'Borra todo en esta capa',
            () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    String emoji,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.borderColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 14,
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textGrey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPainter extends CustomPainter {
  final BrushModel brush;

  _MiniPainter({required this.brush});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(brush.opacity)
      ..strokeWidth = brush.size.clamp(1.0, 12.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (brush.type.name == 'shader') {
      paint.maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        2.0,
      );
    }

    if (brush.type.name == 'dotwork') {
      paint.style = PaintingStyle.fill;
      final dotSize = brush.size.clamp(1.0, 6.0);
      for (double x = 4; x < size.width - 4; x += 6) {
        canvas.drawCircle(
          Offset(x, size.height / 2),
          dotSize / 2,
          paint,
        );
      }
      return;
    }

    if (brush.type.name == 'eraser') {
      paint
        ..color = Colors.grey.withOpacity(0.5)
        ..strokeWidth = brush.size.clamp(1.0, 12.0);
    }

    final path = Path();
    path.moveTo(4, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.2,
      size.width - 4,
      size.height * 0.5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MiniPainter oldDelegate) => false;
}
