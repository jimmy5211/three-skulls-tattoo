import 'package:flutter/material.dart';
import '../models/brush_model.dart';
import '../theme/app_theme.dart';

class BrushSelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          right: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Lista de pinceles
          Expanded(
            child: ListView.builder(
              itemCount: brushes.length,
              itemBuilder: (context, index) {
                final brush = brushes[index];
                final isActive = brush.id == activeBrush.id;
                return GestureDetector(
                  onTap: () => onBrushSelected(brush),
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accentRed.withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.accentRed
                            : AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          brush.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          brush.name.split(' ').first,
                          style: const TextStyle(
                            fontSize: 7,
                            color: AppTheme.textGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Separador
          Container(
            height: 1,
            color: AppTheme.borderColor,
          ),
          // Control de tamaño
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                const Text(
                  'TAM',
                  style: TextStyle(
                    fontSize: 8,
                    color: AppTheme.textGrey,
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
                          enabledThumbRadius: 6,
                        ),
                        activeTrackColor: AppTheme.accentRed,
                        thumbColor: AppTheme.accentRed,
                        inactiveTrackColor: AppTheme.borderColor,
                      ),
                      child: Slider(
                        value: activeBrush.size.clamp(1.0, 50.0),
                        min: 1.0,
                        max: 50.0,
                        onChanged: onSizeChanged,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${activeBrush.size.round()}',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppTheme.textWhite,
                  ),
                ),
              ],
            ),
          ),
          // Control de opacidad
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                const Text(
                  'OPA',
                  style: TextStyle(
                    fontSize: 8,
                    color: AppTheme.textGrey,
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
                          enabledThumbRadius: 6,
                        ),
                        activeTrackColor: AppTheme.accentRed,
                        thumbColor: AppTheme.accentRed,
                        inactiveTrackColor: AppTheme.borderColor,
                      ),
                      child: Slider(
                        value: activeBrush.opacity,
                        min: 0.1,
                        max: 1.0,
                        onChanged: onOpacityChanged,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${(activeBrush.opacity * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppTheme.textWhite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
