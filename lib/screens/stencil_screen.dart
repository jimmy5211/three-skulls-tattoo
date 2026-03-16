import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../widgets/stencil_preview.dart';
import 'package:go_router/go_router.dart';

class StencilScreen extends StatefulWidget {
  const StencilScreen({super.key});

  @override
  State<StencilScreen> createState() => _StencilScreenState();
}

class _StencilScreenState extends State<StencilScreen> {
  Uint8List? _originalImage;
  Uint8List? _processedImage;
  bool _isProcessing = false;
  String _aiAnalysis = '';
  String _selectedMode = 'estencil';
  double _contrastLevel = 0.5;
  double _detailLevel = 0.5;
  bool _generateDotwork = false;

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _originalImage == null
                  ? _buildEmptyState()
                  : _buildContent(),
            ),
            if (_originalImage != null) _buildBottomActions(),
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
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textWhite,
              size: 20,
            ),
            onPressed: () => context.go('/home'),
          ),
          const Expanded(
            child: Text(
              'CREAR ESTENCIL',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: AppTheme.textWhite,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_originalImage != null)
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: AppTheme.textGrey,
                size: 20,
              ),
              onPressed: _resetImage,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📸', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          const Text(
            'CREAR ESTENCIL',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 20,
              color: AppTheme.textWhite,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Importa una foto para convertirla\nen un estencil profesional',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Botón galería
          _buildImportButton(
            emoji: '🖼️',
            label: 'IMPORTAR DE GALERÍA',
            onTap: _pickFromGallery,
          ),
          const SizedBox(height: 16),
          // Botón cámara
          _buildImportButton(
            emoji: '📷',
            label: 'TOMAR FOTO',
            onTap: _pickFromCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton({
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentRed,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: AppTheme.textWhite,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Opciones de modo
        _buildModeSelector(),
        // Ajustes
        _buildAdjustments(),
        // Vista previa
        Expanded(
          child: StencilPreview(
            originalImage: _originalImage!,
            processedImage: _processedImage,
            isProcessing: _isProcessing,
            aiAnalysis: _aiAnalysis,
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      color: AppTheme.surfaceColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildModeChip('estencil', '✂️ Estencil'),
          const SizedBox(width: 8),
          _buildModeChip('cuerpo', '💪 Detectar Cuerpo'),
          const SizedBox(width: 8),
          _buildModeChip('mejorar', '✨ Mejorar Diseño'),
        ],
      ),
    );
  }

  Widget _buildModeChip(String mode, String label) {
    final isActive = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Raleway',
            fontSize: 12,
            color: isActive
                ? Colors.white
                : AppTheme.textGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustments() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      color: AppTheme.deepBlack,
      child: Column(
        children: [
          // Contraste
          Row(
            children: [
              const SizedBox(
                width: 80,
                child: Text(
                  'Contraste',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
              ),
              Expanded(
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
                    value: _contrastLevel,
                    onChanged: (v) =>
                        setState(() => _contrastLevel = v),
                  ),
                ),
              ),
            ],
          ),
          // Detalle
          Row(
            children: [
              const SizedBox(
                width: 80,
                child: Text(
                  'Detalle',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
              ),
              Expanded(
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
                    value: _detailLevel,
                    onChanged: (v) =>
                        setState(() => _detailLevel = v),
                  ),
                ),
              ),
            ],
          ),
          // Dotwork
          Row(
            children: [
              const Text(
                '⚫ Puntillismo para sombras',
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 11,
                  color: AppTheme.textGrey,
                ),
              ),
              const Spacer(),
              Switch(
                value: _generateDotwork,
                onChanged: (v) =>
                    setState(() => _generateDotwork = v),
                activeColor: AppTheme.accentRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Botón procesar con IA
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _isProcessing ? null : _processWithAI,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isProcessing
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
                      _isProcessing
                          ? 'Procesando...'
                          : 'PROCESAR CON IA',
                      style: const TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 13,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón exportar
          Expanded(
            child: GestureDetector(
              onTap: _processedImage != null ? _exportStencil : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _processedImage != null
                      ? AppTheme.cardColor
                      : AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _processedImage != null
                        ? AppTheme.accentRed
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('💾', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 4),
                    Text(
                      'GUARDAR',
                      style: TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 11,
                        color: AppTheme.textWhite,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _originalImage = bytes;
          _processedImage = null;
          _aiAnalysis = '';
        });
      }
    } catch (e) {
      _showError('Error al abrir galería');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _originalImage = bytes;
          _processedImage = null;
          _aiAnalysis = '';
        });
      }
    } catch (e) {
      _showError('Error al abrir cámara');
    }
  }

  Future<void> _processWithAI() async {
    if (_originalImage == null) return;
    setState(() {
      _isProcessing = true;
      _aiAnalysis = '';
    });

    try {
      String result;
      switch (_selectedMode) {
        case 'cuerpo':
          result = await AIService.analyzeBodyPart(
            _originalImage!,
            'image/jpeg',
          );
          break;
        case 'mejorar':
          result = await AIService.suggestDesignImprovements(
            _originalImage!,
            'image/jpeg',
          );
          break;
        default:
          result = await AIService.convertToStencil(
            _originalImage!,
            'image/jpeg',
          );
      }

      setState(() {
        _aiAnalysis = result;
        _processedImage = _originalImage;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Error al procesar con IA');
    }
  }

  void _resetImage() {
    setState(() {
      _originalImage = null;
      _processedImage = null;
      _aiAnalysis = '';
    });
  }

  void _exportStencil() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            Text('💀', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text(
              'Estencil guardado',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: AppTheme.textWhite,
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.accentRed,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Raleway',
            color: Colors.white,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
