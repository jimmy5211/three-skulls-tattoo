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
      width: 200,
      decoration: BoxDecoration(
        color: AppTheme.deepBlack,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CAPAS',
                  style: TextStyle(
                    fontFamily: 'BlackOpsOne',
                    fontSize: 12,
                    color: AppTheme.textWhite,
                    letterSpacing: 2,
                  ),
                ),
                GestureDetector(
                  onTap: onLayerAdded,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de capas
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: layers.length,
              itemBuilder: (context, index) {
                final layer = layers[index];
                final isActive = layer.id == activeLayerId;
                return GestureDetector(
                  onTap: () => onLayerSelected(layer.id),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accentRed.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.accentRed
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Miniatura de capa
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.borderColor,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: AppTheme.textGrey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nombre de capa
                        Expanded(
                          child: Text(
                            layer.name,
                            style: TextStyle(
                              fontFamily: 'Raleway',
                              fontSize: 11,
                              color: isActive
                                  ? AppTheme.textWhite
                                  : AppTheme.textGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Botón visibilidad
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
                        const SizedBox(width: 4),
                        // Botón eliminar
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
