import 'package:flutter/material.dart';
import '../services/font_service.dart';
import '../theme/app_theme.dart';

class FontCard extends StatelessWidget {
  final FontModel font;
  final bool isFavorite;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;

  const FontCard({
    super.key,
    required this.font,
    required this.isFavorite,
    required this.isSelected,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDelete,
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
          color: isSelected
              ? AppTheme.accentRed.withOpacity(0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Categoría
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    font.category.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 9,
                      color: AppTheme.accentRed,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nombre
                Expanded(
                  child: Text(
                    font.name,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 13,
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Default badge
                if (font.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEFAULT',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 8,
                        color: Colors.green,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Favorito
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
                const SizedBox(width: 4),
                // Eliminar
                if (!font.isDefault)
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
            const SizedBox(height: 12),
            // Vista previa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                font.previewText,
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: 18,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
