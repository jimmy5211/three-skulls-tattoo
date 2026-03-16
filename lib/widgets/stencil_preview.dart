import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StencilPreview extends StatefulWidget {
  final Uint8List originalImage;
  final Uint8List? processedImage;
  final bool isProcessing;
  final String aiAnalysis;

  const StencilPreview({
    super.key,
    required this.originalImage,
    this.processedImage,
    this.isProcessing = false,
    this.aiAnalysis = '',
  });

  @override
  State<StencilPreview> createState() => _StencilPreviewState();
}

class _StencilPreviewState extends State<StencilPreview> {
  bool _showOriginal = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle Original/Procesado
        Container(
          margin: const EdgeInsets.all(12),
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
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showOriginal = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _showOriginal
                          ? AppTheme.accentRed
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ORIGINAL',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _showOriginal
                            ? Colors.white
                            : AppTheme.textGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showOriginal = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_showOriginal
                          ? AppTheme.accentRed
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ESTENCIL',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !_showOriginal
                            ? Colors.white
                            : AppTheme.textGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Vista previa de imagen
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.isProcessing
                  ? _buildProcessing()
                  : _buildImage(),
            ),
          ),
        ),

        // Análisis de IA
        if (widget.aiAnalysis.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.accentRed.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    const Text(
                      'ANÁLISIS IA',
                      style: TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 12,
                        color: AppTheme.accentRed,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.aiAnalysis,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 12,
                    color: AppTheme.textGrey,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: AppTheme.accentRed,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '💀 Procesando con IA...',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analizando imagen',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 12,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final imageToShow = !_showOriginal && widget.processedImage != null
        ? widget.processedImage!
        : widget.originalImage;

    return Image.memory(
      imageToShow,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
