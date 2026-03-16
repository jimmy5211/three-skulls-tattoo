import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection(
                    '✂️ SELECCIÓN',
                    [
                      _buildTool('🔲', 'Selección Rectangular',
                          'Selecciona áreas rectangulares'),
                      _buildTool('⭕', 'Selección Circular',
                          'Selecciona áreas circulares'),
                      _buildTool('🔗', 'Lazo Libre',
                          'Selección a mano alzada'),
                      _buildTool('🤖', 'Selección Inteligente',
                          'IA detecta bordes automáticamente'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '🔄 TRANSFORMACIÓN',
                    [
                      _buildTool('🔄', 'Rotar',
                          'Rota el diseño libremente'),
                      _buildTool('↔️', 'Voltear',
                          'Voltea horizontal o vertical'),
                      _buildTool('↗️', 'Escalar',
                          'Agranda o reduce el diseño'),
                      _buildTool('〰️', 'Deformar',
                          'Deformación fluida por puntos'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '✍️ TEXTO',
                    [
                      _buildTool('✍️', 'Agregar Texto',
                          'Inserta texto en el diseño'),
                      _buildTool('〰️', 'Texto Curvo',
                          'Texto que sigue un trazo'),
                      _buildTool('✒️', 'Convertir a Trazo',
                          'Edita cada letra como forma'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '🪣 RELLENO',
                    [
                      _buildTool('🪣', 'Balde de Relleno',
                          'Rellena áreas con color'),
                      _buildTool('🌈', 'Degradado',
                          'Relleno con transición de colores'),
                      _buildTool('🔲', 'Patrón',
                          'Rellena con patrón repetido'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '📏 MEDICIÓN',
                    [
                      _buildTool('📏', 'Medir Distancia',
                          'Mide entre dos puntos'),
                      _buildTool('📐', 'Medir Ángulo',
                          'Mide ángulos entre trazos'),
                      _buildTool('⊞', 'Guías',
                          'Líneas de referencia'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '📐 FORMAS',
                    [
                      _buildTool('📏', 'Línea Recta',
                          'Dibuja líneas perfectas'),
                      _buildTool('⭕', 'Círculo',
                          'Círculos y elipses perfectas'),
                      _buildTool('🔷', 'Polígono',
                          'Formas geométricas'),
                      _buildTool('〰️', 'Curva Bézier',
                          'Curvas controladas por puntos'),
                    ],
                  ),
                ],
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
              'HERRAMIENTAS',
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

  Widget _buildSection(String title, List<Widget> tools) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'BlackOpsOne',
            fontSize: 12,
            color: AppTheme.accentRed,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
          ),
          child: Column(children: tools),
        ),
      ],
    );
  }

  Widget _buildTool(
    String emoji,
    String name,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
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
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 13,
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          const Text(
            'Próximo',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 10,
              color: AppTheme.accentRed,
            ),
          ),
        ],
      ),
    );
  }
}
También actualiza app_router.dart agregando la ruta:
Agrega este import:
import 'screens/tools_screen.dart';
Y esta ruta:
GoRoute(
  path: '/tools',
  builder: (BuildContext context, GoRouterState state) {
    return const ToolsScreen();
  },
),
