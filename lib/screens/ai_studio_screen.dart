import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AiStudioScreen extends StatelessWidget {
  const AiStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '🤖',
                      style: TextStyle(fontSize: 60),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'IA STUDIO',
                      style: TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 24,
                        color: AppTheme.textWhite,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Próximamente',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 1,
                      color: AppTheme.accentRed,
                    ),
                    const SizedBox(height: 24),
                    // Preview de funciones
                    _buildFeaturePreview(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textWhite,
              size: 20,
            ),
            onPressed: () => context.go('/home'),
          ),
          const Expanded(
            child: Text(
              'IA STUDIO',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: AppTheme.textWhite,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildFeaturePreview() {
    final features = [
      {'emoji': '🎨', 'title': 'Generador de Ideas'},
      {'emoji': '💬', 'title': 'Asistente Tatuador'},
      {'emoji': '🔄', 'title': 'Mejorar Diseño'},
      {'emoji': '🖼️', 'title': 'Separador de Elementos'},
      {'emoji': '📏', 'title': 'Calculadora de Tamaño'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: features.map((feature) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  feature['emoji']!,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  feature['title']!,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 13,
                    color: AppTheme.textGrey,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Próximo',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: AppTheme.accentRed,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
