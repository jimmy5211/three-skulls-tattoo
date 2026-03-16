import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final bool isGridView;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const ProjectCard({
    super.key,
    required this.project,
    required this.isGridView,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return isGridView ? _buildGridCard() : _buildListCard();
  }

  Widget _buildGridCard() {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: project.thumbnailPath.isEmpty
                      ? const Text(
                          '🖼️',
                          style: TextStyle(fontSize: 32),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 32,
                        ),
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    project.style,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 9,
                      color: AppTheme.accentRed,
                    ),
                  ),
                  Text(
                    project.formattedDate,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 9,
                      color: AppTheme.textGrey,
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

  Widget _buildListCard() {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Miniatura
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: project.thumbnailPath.isEmpty
                    ? const Text(
                        '🖼️',
                        style: TextStyle(fontSize: 24),
                      )
                    : const Icon(
                        Icons.image_outlined,
                        color: Colors.grey,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 14,
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
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
                        child: Text(
                          project.style,
                          style: const TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 9,
                            color: AppTheme.accentRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        project.formattedSize,
                        style: const TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Editado: ${project.formattedDate}',
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            // Acciones
            Column(
              children: [
                GestureDetector(
                  onTap: onExport,
                  child: const Icon(
                    Icons.share_outlined,
                    color: AppTheme.textGrey,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
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
}
