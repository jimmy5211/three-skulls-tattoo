import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/brush_selector.dart';
import '../widgets/layer_panel.dart';
import '../widgets/color_picker.dart';
import '../models/brush_model.dart';
import 'package:go_router/go_router.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late CanvasController _controller;
  late List<BrushModel> _brushes;

  bool _showLayers = false;
  bool _showColors = false;
  bool _showGrid = false;
  bool _isFullscreen = false;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _controller = CanvasController();
    _brushes = BrushModel.defaultBrushes();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            if (!_isFullscreen) _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  // Panel de pinceles izquierda
                  if (!_isFullscreen)
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return BrushSelector(
                          activeBrush: _controller.activeBrush,
                          brushes: _brushes,
                          onBrushSelected: _controller.setActiveBrush,
                          onSizeChanged: _controller.setBrushSize,
                          onOpacityChanged: _controller.setBrushOpacity,
                        );
                      },
                    ),
                  // Canvas principal
                  Expanded(
                    child: Stack(
                      children: [
                        _buildCanvas(),
                        // Panel de capas
                        if (_showLayers)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                return LayerPanel(
                                  layers: _controller.layers,
                                  activeLayerId:
                                      _controller.activeLayerId,
                                  onLayerSelected:
                                      _controller.setActiveLayer,
                                  onLayerVisibilityToggled:
                                      _controller.toggleLayerVisibility,
                                  onLayerDeleted:
                                      _controller.removeLayer,
                                  onLayerAdded: _controller.addLayer,
                                );
                              },
                            ),
                          ),
                        // Panel de colores
                        if (_showColors)
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  return ColorPicker(
                                    activeColor:
                                        _controller.activeColor,
                                    onColorSelected:
                                        _controller.setActiveColor,
                                  );
                                },
                              ),
                            ),
                          ),
                        // Botón pantalla completa
                        Positioned(
                          top: 8,
                          left: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isFullscreen = !_isFullscreen;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.deepBlack
                                    .withOpacity(0.8),
                                borderRadius:
                                    BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.borderColor,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _isFullscreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                color: AppTheme.textWhite,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!_isFullscreen) _buildBottomBar(),
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
          // Botón regresar
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textWhite,
              size: 20,
            ),
            onPressed: () => context.go('/home'),
          ),
          // Título
          const Expanded(
            child: Text(
              'NUEVO DISEÑO',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: AppTheme.textWhite,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Deshacer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return IconButton(
                icon: const Icon(
                  Icons.undo,
                  color: AppTheme.textWhite,
                  size: 20,
                ),
                onPressed: _controller.undo,
              );
            },
          ),
          // Rehacer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return IconButton(
                icon: const Icon(
                  Icons.redo,
                  color: AppTheme.textWhite,
                  size: 20,
                ),
                onPressed: _controller.redo,
              );
            },
          ),
          // Guardar
          IconButton(
            icon: const Icon(
              Icons.save_outlined,
              color: AppTheme.accentRed,
              size: 20,
            ),
            onPressed: _saveDesign,
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Container(
      color: const Color(0xFF444444),
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.1,
        maxScale: 10.0,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return GestureDetector(
              onPanStart: (details) {
                _controller.startStroke(
                  details.localPosition,
                );
              },
              onPanUpdate: (details) {
                _controller.continueStroke(
                  details.localPosition,
                );
              },
              onPanEnd: (_) => _controller.endStroke(),
              child: CustomPaint(
                painter: CanvasPainter(
                  layers: _controller.layers,
                  currentStroke: _controller.currentStroke,
                  showGrid: _showGrid,
                  showSymmetryLine: _controller.symmetryEnabled,
                  symmetryEnabled: _controller.symmetryEnabled,
                ),
                size: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Color
          _buildToolButton(
            emoji: '🎨',
            label: 'Color',
            isActive: _showColors,
            onTap: () {
              setState(() {
                _showColors = !_showColors;
                if (_showColors) _showLayers = false;
              });
            },
          ),
          // Capas
          _buildToolButton(
            emoji: '🗂️',
            label: 'Capas',
            isActive: _showLayers,
            onTap: () {
              setState(() {
                _showLayers = !_showLayers;
                if (_showLayers) _showColors = false;
              });
            },
          ),
          // Cuadrícula
          _buildToolButton(
            emoji: '⊞',
            label: 'Grilla',
            isActive: _showGrid,
            onTap: () {
              setState(() => _showGrid = !_showGrid);
            },
          ),
          // Simetría
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return _buildToolButton(
                emoji: '🔄',
                label: 'Sim.',
                isActive: _controller.symmetryEnabled,
                onTap: _controller.toggleSymmetry,
              );
            },
          ),
          // Limpiar
          _buildToolButton(
            emoji: '🗑️',
            label: 'Limpiar',
            isActive: false,
            onTap: () => _showClearDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required String emoji,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppTheme.accentRed
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textGrey,
                fontFamily: 'Raleway',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          '💀 Limpiar Canvas',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: const Text(
          '¿Limpiar toda la capa activa?',
          style: TextStyle(
            color: AppTheme.textGrey,
            fontFamily: 'Raleway',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ),
          TextButton(
            onPressed: () {
              _controller.clearActiveLayer();
              Navigator.pop(context);
            },
            child: const Text(
              'Limpiar',
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }

  void _saveDesign() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            Text('💀', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text(
              'Diseño guardado',
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
}
