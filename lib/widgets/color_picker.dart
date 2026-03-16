import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorPicker extends StatefulWidget {
  final Color activeColor;
  final Function(Color) onColorSelected;

  const ColorPicker({
    super.key,
    required this.activeColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  final List<Color> _tattooColors = [
    Colors.black,
    const Color(0xFF1A1A1A),
    const Color(0xFF333333),
    const Color(0xFF666666),
    const Color(0xFF999999),
    Colors.white,
    const Color(0xFF8B0000),
    const Color(0xFFC0392B),
    const Color(0xFFE74C3C),
    const Color(0xFF1A5276),
    const Color(0xFF2980B9),
    const Color(0xFF1E8449),
    const Color(0xFF27AE60),
    const Color(0xFF7D6608),
    const Color(0xFFD4AC0D),
    const Color(0xFF6E2F8A),
    const Color(0xFF9B59B6),
    const Color(0xFF784212),
    const Color(0xFFCA6F1E),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.deepBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color activo
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: widget.activeColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Paleta de colores
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _tattooColors.map((color) {
              final isActive = color.value == widget.activeColor.value;
              return GestureDetector(
                onTap: () => widget.onColorSelected(color),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? AppTheme.accentRed
                          : AppTheme.borderColor,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: isActive
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: color == Colors.white ||
                                  color == Colors.black
                              ? color == Colors.white
                                  ? Colors.black
                                  : Colors.white
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Colores recientes
          const Text(
            'RECIENTES',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 9,
              color: AppTheme.textGrey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: index == 0
                      ? widget.activeColor
                      : AppTheme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
