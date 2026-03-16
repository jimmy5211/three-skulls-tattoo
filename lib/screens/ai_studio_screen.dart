import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_feature_card.dart';
import '../widgets/ai_chat_widget.dart';
import '../services/ai_service.dart';

class AiStudioScreen extends StatefulWidget {
  const AiStudioScreen({super.key});

  @override
  State<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends State<AiStudioScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  int _selectedFeature = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _selectedFeature == -1
                ? _buildFeatureList()
                : _buildFeatureContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
            icon: Icon(
              _selectedFeature == -1
                  ? Icons.arrow_back
                  : Icons.arrow_back,
              color: AppTheme.textWhite,
              size: 20,
            ),
            onPressed: () {
              if (_selectedFeature == -1) {
                context.go('/home');
              } else {
                setState(() => _selectedFeature = -1);
              }
            },
          ),
          Expanded(
            child: Text(
              _selectedFeature == -1
                  ? 'IA STUDIO'
                  : _getFeatureTitle(_selectedFeature),
              style: const TextStyle(
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

  Widget _buildFeatureList() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IA STUDIO',
                      style: TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 18,
                        color: AppTheme.textWhite,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'Inteligencia artificial para tatuadores',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 12,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            height: 1,
            color: AppTheme.borderColor,
          ),
          AiFeatureCard(
            emoji: '🎨',
            title: 'GENERADOR DE IDEAS',
            description: 'Describe tu tatuaje y la IA '
                'sugiere elementos y estilos',
            onTap: () => setState(() => _selectedFeature = 0),
          ),
          AiFeatureCard(
            emoji: '💬',
            title: 'ASISTENTE TATUADOR',
            description: 'Chat con IA especializada '
                'en tatuajes',
            onTap: () => setState(() => _selectedFeature = 1),
          ),
          AiFeatureCard(
            emoji: '🔄',
            title: 'MEJORAR DISEÑO',
            description: 'Sube tu diseño y la IA '
                'sugiere mejoras',
            onTap: () => setState(() => _selectedFeature = 2),
          ),
          AiFeatureCard(
            emoji: '🖼️',
            title: 'SEPARADOR DE ELEMENTOS',
            description: 'Separa automáticamente '
                'líneas, sombras y detalles',
            onTap: () => setState(() => _selectedFeature = 3),
          ),
          AiFeatureCard(
            emoji: '📏',
            title: 'CALCULADORA DE TAMAÑO',
            description: 'Calcula el tamaño ideal '
                'según la zona del cuerpo',
            onTap: () => setState(() => _selectedFeature = 4),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureContent() {
    switch (_selectedFeature) {
      case 0:
        return _buildIdeaGenerator();
      case 1:
        return _buildTattooAssistant();
      case 2:
        return _buildDesignImprover();
      case 3:
        return _buildElementSeparator();
      case 4:
        return _buildSizeCalculator();
      default:
        return const SizedBox();
    }
  }

  // 1. Generador de ideas
  Widget _buildIdeaGenerator() {
    return Expanded(
      child: AiChatWidget(
        systemPrompt: '''Eres un experto tatuador con 20 años 
        de experiencia. El usuario te describe un tatuaje y tú:
        1. Sugieres elementos visuales específicos
        2. Recomiendas el estilo más adecuado
        3. Describes la composición ideal
        4. Sugieres tamaño y ubicación
        5. Das tips técnicos
        Responde siempre en español.''',
        placeholder: '💡 Describe el tatuaje que quieres\n'
            'y la IA te dará ideas detalladas',
      ),
    );
  }

  // 2. Asistente tatuador
  Widget _buildTattooAssistant() {
    return Expanded(
      child: AiChatWidget(
        systemPrompt: '''Eres un asistente experto en tatuajes.
        Ayudas a tatuadores profesionales con preguntas sobre:
        - Estilos de tatuaje
        - Técnicas de sombreado
        - Combinación de elementos
        - Tamaños y proporciones
        - Posicionamiento en el cuerpo
        - Cuidados del tatuaje
        Responde siempre en español de forma profesional.''',
        placeholder: '💬 Pregúntame cualquier cosa\n'
            'sobre tatuajes',
      ),
    );
  }

  // 3. Mejorar diseño
  Widget _buildDesignImprover() {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceColor,
            child: const Text(
              '📸 Próximamente: Sube tu diseño\n'
              'y la IA sugerirá mejoras detalladas',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 13,
                color: AppTheme.textGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: AiChatWidget(
              systemPrompt: '''Eres un experto en diseño de 
              tatuajes. Cuando el usuario describa su diseño,
              sugieres mejoras específicas en:
              1. Composición y balance
              2. Proporciones
              3. Sombreado y volumen
              4. Detalles y texturas
              5. Simplicidad vs complejidad
              Responde siempre en español.''',
              placeholder: '✏️ Describe tu diseño actual\n'
                  'y te diré cómo mejorarlo',
            ),
          ),
        ],
      ),
    );
  }

  // 4. Separador de elementos
  Widget _buildElementSeparator() {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceColor,
            child: const Text(
              '🖼️ Próximamente: Sube una imagen\n'
              'y la IA separará automáticamente\n'
              'líneas, sombras y detalles en capas',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 13,
                color: AppTheme.textGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: AiChatWidget(
              systemPrompt: '''Eres un experto en análisis 
              visual de tatuajes. Cuando el usuario describa
              un diseño, explicas cómo separarlo en:
              1. Líneas principales
              2. Sombras y degradados
              3. Rellenos sólidos
              4. Detalles finos
              5. Elementos secundarios
              Responde siempre en español.''',
              placeholder: '🔍 Describe tu diseño\n'
                  'y te diré cómo separar sus elementos',
            ),
          ),
        ],
      ),
    );
  }

  // 5. Calculadora de tamaño
  Widget _buildSizeCalculator() {
    final TextEditingController bodyPartController =
        TextEditingController();
    final TextEditingController designController =
        TextEditingController();

    return Expanded(
      child: StatefulBuilder(
        builder: (context, setModalState) {
          bool isLoading = false;
          String result = '';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ZONA DEL CUERPO:',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 11,
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bodyPartController,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ej: antebrazo, espalda...',
                        hintStyle: const TextStyle(
                          color: AppTheme.textGrey,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.borderColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'DESCRIPCIÓN DEL DISEÑO:',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 11,
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: designController,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                      ),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe el diseño...',
                        hintStyle: const TextStyle(
                          color: AppTheme.textGrey,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.borderColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () async {
                              if (bodyPartController.text.isEmpty ||
                                  designController.text.isEmpty) {
                                return;
                              }
                              setModalState(() => isLoading = true);
                              final response = await AIService
                                  .calculateSizeAndZone(
                                bodyPartController.text,
                                designController.text,
                              );
                              setModalState(() {
                                result = response;
                                isLoading = false;
                              });
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isLoading
                              ? AppTheme.borderColor
                              : AppTheme.accentRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '🤖',
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isLoading
                                  ? 'Calculando...'
                                  : 'CALCULAR CON IA',
                              style: const TextStyle(
                                fontFamily: 'BlackOpsOne',
                                fontSize: 14,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (result.isNotEmpty)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accentRed.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '🤖',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'RESULTADO IA',
                                style: TextStyle(
                                  fontFamily: 'BlackOpsOne',
                                  fontSize: 12,
                                  color: AppTheme.accentRed,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            result,
                            style: const TextStyle(
                              fontFamily: 'Raleway',
                              fontSize: 13,
                              color: AppTheme.textWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _getFeatureTitle(int index) {
    switch (index) {
      case 0:
        return 'GENERADOR DE IDEAS';
      case 1:
        return 'ASISTENTE TATUADOR';
      case 2:
        return 'MEJORAR DISEÑO';
      case 3:
        return 'SEPARADOR DE ELEMENTOS';
      case 4:
        return 'CALCULADORA DE TAMAÑO';
      default:
        return 'IA STUDIO';
    }
  }
}
