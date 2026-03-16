import 'package:flutter/material.dart';
import '../models/layer_model.dart';
import '../theme/app_theme.dart';

class LayerPanel extends StatelessWidget {
  final List<LayerModel> layers;
  final int activeLayerId;
  final Function(int) onLayerSelected;
  final Function(int) onLayerVisibilityToggled;
  final Function(int) onLayerDeleted;
  final VoidCallback onLayerAdded;

  const LayerPanel({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.onLayerSelected,
    required this.onLayerVisibilityToggled,
    required this.onLayerDeleted,
    required this.onLayerAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.deepBlack.withOpacity(0.97),
        border: const Border(
          left: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: layers.length,
              onReorder: (oldIndex, newIndex) {},
              itemBuilder: (context, index) {
                final layer =
                    layers.reversed.toList()[index];
                return _buildLayerItem(
                  context,
                  layer,
                  index,
                );
              },
            ),
          ),
          _buildBottomActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
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
          const Text(
            'CAPAS',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 13,
              color: AppTheme.textWhite,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          // Botón agregar capa
          GestureDetector(
            onTap: onLayerAdded,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.accentRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerItem(
    BuildContext context,
    LayerModel layer,
    int index,
  ) {
    final isActive = layer.id == activeLayerId;
    return GestureDetector(
      key: ValueKey(layer.id),
      onTap: () => onLayerSelected(layer.id),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.15)
              : AppTheme.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Miniatura de la capa
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        width: 0.5,
                      ),
                    ),
                    child: layer.strokes.isEmpty
                        ? const Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: AppTheme.borderColor,
                          )
                        : CustomPaint(
                            painter: _LayerThumbnailPainter(
                              layer: layer,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Info de la capa
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          layer.name,
                          style: TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 12,
                            color: isActive
                                ? AppTheme.textWhite
                                : AppTheme.textGrey,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${layer.strokes.length} trazos',
                          style: const TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 9,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Acciones
                  Column(
                    children: [
                      // Visibilidad
                      GestureDetector(
                        onTap: () =>
                            onLayerVisibilityToggled(layer.id),
                        child: Icon(
                          layer.isVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: layer.isVisible
                              ? AppTheme.textWhite
                              : AppTheme.textGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Eliminar
                      GestureDetector(
                        onTap: () => layers.length > 1
                            ? onLayerDeleted(layer.id)
                            : null,
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: layers.length > 1
                              ? AppTheme.textGrey
                              : AppTheme.borderColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Slider de opacidad
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 6,
              ),
              child: Row(
                children: [
                  const Text(
                    'OPA',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 8,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        activeTrackColor: isActive
                            ? AppTheme.accentRed
                            : AppTheme.textGrey,
                        thumbColor: isActive
                            ? AppTheme.accentRed
                            : AppTheme.textGrey,
                        inactiveTrackColor:
                            AppTheme.borderColor,
                        overlayShape:
                            SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: layer.opacity,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (value) {
                          layer.opacity = value;
                        },
                      ),
                    ),
                  ),
                  Text(
                    '${(layer.opacity * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 8,
                      color: AppTheme.textWhite,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAction(
            context,
            Icons.copy_outlined,
            'Duplicar',
            () {},
          ),
          _buildAction(
            context,
            Icons.merge_outlined,
            'Combinar',
            () {},
          ),
          _buildAction(
            context,
            Icons.lock_outline,
            'Bloquear',
            () {},
          ),
          _buildAction(
            context,
            Icons.layers_clear_outlined,
            'Aplanar',
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              color: AppTheme.textGrey,
              size: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 8,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerThumbnailPainter extends CustomPainter {
  final LayerModel layer;

  _LayerThumbnailPainter({required this.layer});

  @override
  void paint(Canvas canvas, Size size) {
    if (layer.strokes.isEmpty) return;

    final scaleX = size.width / 400;
    final scaleY = size.height / 700;

    for (final stroke in layer.strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color.withOpacity(stroke.opacity)
        ..strokeWidth =
            (stroke.strokeWidth * scaleX).clamp(0.5, 3.0)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length < 2) {
        canvas.drawCircle(
          Offset(
            stroke.points.first.dx * scaleX,
            stroke.points.first.dy * scaleY,
          ),
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      final path = Path();
      path.moveTo(
        stroke.points.first.dx * scaleX,
        stroke.points.first.dy * scaleY,
      );
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].dx * scaleX,
          stroke.points[i].dy * scaleY,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LayerThumbnailPainter oldDelegate) =>
      true;
}
