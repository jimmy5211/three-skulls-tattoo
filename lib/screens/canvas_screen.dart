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
  bool _isPanning = false;
  double _currentScale = 1.0;

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

  Offset _transformToCanvas(Offset localPosition) {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final tx = matrix.getTranslation().x;
    final ty = matrix.getTranslation().y;
    return Offset(
      (localPosition.dx - tx) / scale,
      (localPosition.dy - ty) / scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: SafeArea(
        child: Stack(
          children: [
            // Canvas principal
            _buildCanvas(),

            // Barra superior
            if (!_isFullscreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),

            // Panel pinceles izquierda
            if (!_isFullscreen)
              Positioned(
                left: 0,
                top: 52,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return BrushSelector(
                      activeBrush: _controller.activeBrush,
                      brushes: _brushes,
                      onBrushSelected: _controller.setActiveBrush,
                      onSizeChanged: _controller.setBrushSize,
                      onOpacityChanged:
                          _controller.setBrushOpacity,
                    );
                  },
                ),
              ),

            // Burbuja capas derecha arriba
            if (!_isFullscreen)
              Positioned(
                right: 8,
                top: 60,
                child: _buildLayersBubble(),
              ),

            // Panel capas expandido
            if (_showLayers && !_isFullscreen)
              Positioned(
                right: 0,
                top: 52,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return LayerPanel(
                      layers: _controller.layers,
                      activeLayerId: _controller.activeLayerId,
                      onLayerSelected:
                          _controller.setActiveLayer,
                      onLayerVisibilityToggled:
                          _controller.toggleLayerVisibility,
                      onLayerDeleted: _controller.removeLayer,
                      onLayerAdded: _controller.addLayer,
                    );
                  },
                ),
              ),

            // Burbuja color derecha abajo
            if (!_isFullscreen)
              Positioned(
                right: 8,
                bottom: 80,
                child: _buildColorBubble(),
              ),

            // Panel colores expandido
            if (_showColors && !_isFullscreen)
              Positioned(
                right: 8,
                bottom: 134,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return ColorPicker(
                      activeColor: _controller.activeColor,
                      onColorSelected:
                          _controller.setActiveColor,
                    );
                  },
                ),
              ),

            // Indicador de zoom
            if (!_isFullscreen)
              Positioned(
                right: 8,
                bottom: 40,
                child: _buildZoomIndicator(),
              ),

            // Botón pantalla completa
            Positioned(
              top: _isFullscreen ? 8 : 60,
              left: _isFullscreen ? 8 : 68,
              child: _buildFullscreenButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Positioned.fill(
      child: Listener(
        onPointerDown: (event) {
          // Detectar si hay 2 o más dedos
          if (event.buttons > 1) {
            setState(() => _isPanning = true);
          }
        },
        onPointerUp: (event) {
          setState(() => _isPanning = false);
        },
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.1,
          maxScale: 20.0,
          panEnabled: _isPanning,
          scaleEnabled: true,
          onInteractionUpdate: (details) {
            setState(() {
              _currentScale =
                  _transformationController.value
                      .getMaxScaleOnAxis();
              if (details.pointerCount >= 2) {
                _isPanning = true;
                _controller.endStroke();
              }
            });
          },
          onInteractionEnd: (details) {
            setState(() => _isPanning = false);
          },
          child: GestureDetector(
            onPanStart: (details) {
              if (!_isPanning) {
                _controller.startStroke(
                  _transformToCanvas(details.localPosition),
                );
              }
            },
            onPanUpdate: (details) {
              if (!_isPanning) {
                _controller.continueStroke(
                  _transformToCanvas(details.localPosition),
                );
              }
            },
            onPanEnd: (_) {
              if (!_isPanning) {
                _controller.endStroke();
              }
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: CanvasPainter(
                    layers: _controller.layers,
                    currentStroke: _controller.currentStroke,
                    showGrid: _showGrid,
                    showSymmetryLine:
                        _controller.symmetryEnabled,
                    symmetryEnabled: _controller.symmetryEnabled,
                  ),
                  size: Size(
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.deepBlack.withOpacity(0.97),
        border: const Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTopButton(
            icon: Icons.arrow_back_ios,
            onTap: () => context.go('/home'),
          ),
          _buildTopButton(
            icon: Icons.undo,
            onTap: _controller.undo,
          ),
          _buildTopButton(
            icon: Icons.redo,
            onTap: _controller.redo,
          ),
          const Spacer(),
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
          _buildTopButton(
            icon: _showGrid
                ? Icons.grid_on
                : Icons.grid_off,
            isActive: _showGrid,
            onTap: () =>
                setState(() => _showGrid = !_showGrid),
          ),
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
        width: 38,
        height: 38,
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
          color: color ??
              (isActive
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _showLayers
                  ? AppTheme.accentRed
                  : AppTheme.deepBlack.withOpacity(0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showLayers
                    ? AppTheme.accentRed
                    : AppTheme.borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
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
                  size: 20,
                ),
                Text(
                  '${_controller.layers.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontFamily: 'Raleway',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _controller.activeColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showColors
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                width: _showColors ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _controller.activeColor
                      .withOpacity(0.4),
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

  Widget _buildZoomIndicator() {
    return GestureDetector(
      onTap: () {
        _transformationController.value =
            Matrix4.identity();
        setState(() => _currentScale = 1.0);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppTheme.deepBlack.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
        child: Text(
          '${(_currentScale * 100).round()}%',
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 10,
            color: AppTheme.textGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return GestureDetector(
      onTap: () =>
          setState(() => _isFullscreen = !_isFullscreen),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.deepBlack.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 0.5,
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
