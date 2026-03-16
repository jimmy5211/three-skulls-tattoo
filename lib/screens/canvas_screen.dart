import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/brush_selector.dart';
import '../widgets/layer_panel.dart';
import '../widgets/color_picker.dart';
import '../models/brush_model.dart';

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
      backgroundColor: const Color(0xFF3A3A3A),
      body: SafeArea(
        child: Stack(
          children: [
            // Canvas principal ocupa toda la pantalla
            _buildCanvas(),

            // Barra superior flotante
            if (!_isFullscreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),

            // Panel de pinceles izquierda
            if (!_isFullscreen)
              Positioned(
                left: 0,
                top: 56,
                bottom: 56,
                child: AnimatedBuilder(
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
              ),

            // Botón capas derecha (burbuja)
            if (!_isFullscreen)
              Positioned(
                right: 8,
                top: 70,
                child: _buildLayersBubble(),
              ),

            // Panel de capas expandido
            if (_showLayers && !_isFullscreen)
              Positioned(
                right: 0,
                top: 56,
                bottom: 56,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return LayerPanel(
                      layers: _controller.layers,
                      activeLayerId: _controller.activeLayerId,
                      onLayerSelected: _controller.setActiveLayer,
                      onLayerVisibilityToggled:
                          _controller.toggleLayerVisibility,
                      onLayerDeleted: _controller.removeLayer,
                      onLayerAdded: _controller.addLayer,
                    );
                  },
                ),
              ),

            // Selector de color (burbuja esquina derecha abajo)
            if (!_isFullscreen)
              Positioned(
                right: 8,
                bottom: 64,
                child: _buildColorBubble(),
              ),

            // Panel de colores expandido
            if (_showColors && !_isFullscreen)
              Positioned(
                right: 8,
                bottom: 120,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return ColorPicker(
                      activeColor: _controller.activeColor,
                      onColorSelected: _controller.setActiveColor,
                    );
                  },
                ),
              ),

            // Barra inferior flotante
            if (!_isFullscreen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(),
              ),

            // Botón pantalla completa
            Positioned(
              top: _isFullscreen ? 8 : 64,
              left: _isFullscreen ? 8 : 68,
              child: _buildFullscreenButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.deepBlack.withOpacity(0.95),
        border: const Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Botón regresar
          _buildTopButton(
            icon: Icons.arrow_back,
            onTap: () => context.go('/home'),
          ),
          const SizedBox(width: 4),
          // Deshacer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return _buildTopButton(
                icon: Icons.undo,
                onTap: _controller.undo,
              );
            },
          ),
          // Rehacer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return _buildTopButton(
                icon: Icons.redo,
                onTap: _controller.redo,
              );
            },
          ),
          const Spacer(),
          // Título
          const Text(
            'NUEVO DISEÑO',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 13,
              color: AppTheme.textWhite,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          // Cuadrícula
          _buildTopButton(
            icon: _showGrid ? Icons.grid_on : Icons.grid_off,
            isActive: _showGrid,
            onTap: () => setState(() => _showGrid = !_showGrid),
          ),
          // Simetría
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return _buildTopButton(
                icon: Icons.flip,
                isActive: _controller.symmetryEnabled,
                onTap: _controller.toggleSymmetry,
              );
            },
          ),
          // Guardar
          _buildTopButton(
            icon: Icons.save_outlined,
            color: AppTheme.accentRed,
            onTap: _saveDesign,
          ),
        ],
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    VoidCallback? onTap,
    bool isActive = false,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: AppTheme.accentRed,
                  width: 1,
                )
              : null,
        ),
        child: Icon(
          icon,
          color: color ?? (isActive
              ? AppTheme.accentRed
              : AppTheme.textWhite),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildLayersBubble() {
    return GestureDetector(
      onTap: () => setState(() {
        _showLayers = !_showLayers;
        if (_showLayers) _showColors = false;
      }),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _showLayers
              ? AppTheme.accentRed
              : AppTheme.deepBlack.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _showLayers
                ? AppTheme.accentRed
                : AppTheme.borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.layers_outlined,
              color: Colors.white,
              size: 18,
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Text(
                  '${_controller.layers.length}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontFamily: 'Raleway',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorBubble() {
    return GestureDetector(
      onTap: () => setState(() {
        _showColors = !_showColors;
        if (_showColors) _showLayers = false;
      }),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _controller.activeColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _showColors
                    ? Colors.white
                    : AppTheme.borderColor,
                width: _showColors ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return GestureDetector(
      onTap: () => setState(() => _isFullscreen = !_isFullscreen),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.deepBlack.withOpacity(0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
        child: Icon(
          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          color: AppTheme.textWhite,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Positioned.fill(
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.1,
        maxScale: 10.0,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return GestureDetector(
              onPanStart: (details) =>
                  _controller.startStroke(details.localPosition),
              onPanUpdate: (details) =>
                  _controller.continueStroke(details.localPosition),
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
      decoration: BoxDecoration(
        color: AppTheme.deepBlack.withOpacity(0.95),
        border: const Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomButton('✏️', 'Liner',
              _controller.activeBrush.id == 'liner_fine', () {
            _controller.setActiveBrush(_brushes[0]);
          }),
          _buildBottomButton('🖌️', 'Shader',
              _controller.activeBrush.id == 'shader_soft', () {
            _controller.setActiveBrush(_brushes[2]);
          }),
          _buildBottomButton(
              '⚫', 'Dotwork',
              _controller.activeBrush.id == 'dotwork', () {
            _controller.setActiveBrush(_brushes[3]);
          }),
          _buildBottomButton(
              '🧹', 'Borrador',
              _controller.activeBrush.id == 'eraser', () {
            _controller.setActiveBrush(_brushes[5]);
          }),
          _buildBottomButton('🗑️', 'Limpiar', false,
              () => _showClearDialog()),
        ],
      ),
    );
  }

  Widget _buildBottomButton(
    String emoji,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
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
            Text(emoji, style: const TextStyle(fontSize: 20)),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isActive
                    ? AppTheme.accentRed
                    : AppTheme.textGrey,
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
