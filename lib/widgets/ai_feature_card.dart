import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AiFeatureCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final bool isAvailable;
  final VoidCallback onTap;

  const AiFeatureCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    required this.onTap,
    this.isAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAvailable
              ? AppTheme.cardColor
              : AppTheme.cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable
                ? AppTheme.accentRed.withOpacity(0.3)
                : AppTheme.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isAvailable
                    ? AppTheme.accentRed.withOpacity(0.15)
                    : AppTheme.borderColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'BlackOpsOne',
                      fontSize: 13,
                      color: isAvailable
                          ? AppTheme.textWhite
                          : AppTheme.textGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isAvailable
                  ? Icons.chevron_right
                  : Icons.lock_outline,
              color: isAvailable
                  ? AppTheme.accentRed
                  : AppTheme.textGrey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
