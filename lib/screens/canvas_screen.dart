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
  bool _zoomMode = false;

  // Zoom y paneo
  double _scale = 1.0;
  double _startScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  bool _isScaling = false;

  // Área del lienzo
  static const double _brushPanelWidth = 64.0;
  static const double _topBarHeight = 52.0;
  static const double _layerPanelWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _controller = CanvasController();
    _brushes = BrushModel.defaultBrushes();
  }

  Offset _screenToCanvas(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - _offset.dx) / _scale,
      (screenPoint.dy - _offset.dy) / _scale,
    );
  }

  // Verificar si el toque está dentro del lienzo
  bool _isTouchOnCanvas(Offset point) {
    final screenWidth = MediaQuery.of(context).size.width;
    final canvasLeft = _brushPanelWidth;
    final canvasRight = _showLayers
        ? screenWidth - _layerPanelWidth
        : screenWidth;
    final canvasTop = _isFullscreen ? 0.0 : _topBarHeight;

    return point.dx > canvasLeft &&
        point.dx < canvasRight &&
        point.dy > canvasTop;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _controller.updateCanvasSize(size);
    });

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
                      onBrushSelected:
                          _controller.setActiveBrush,
                      onSizeChanged: _controller.setBrushSize,
                      onOpacityChanged:
                          _controller.setBrushOpacity,
                    );
                  },
                ),
              ),

            // Burbuja capas
            if (!_isFullscreen)
              Positioned(
                right: 8,
                top: 60,
                child: _buildLayersBubble(),
              ),

            // Panel capas
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
                      activeLayerId:
                          _controller.activeLayerId,
                      onLayerSelected:
                          _controller.setActiveLayer,
                      onLayerVisibilityToggled:
                          _controller.toggleLayerVisibility,
                      onLayerDeleted:
                          _controller.removeLayer,
                      onLayerAdded: _controller.addLayer,
                      onClose: () => setState(
                        () => _showLayers = false,
                      ),
                      onLayerDuplicated:
                          _controller.duplicateLayer,
                      onLayerMergedDown:
                          _controller.mergeDownLayer,
                      onLayerLocked: _controller.lockLayer,
                      onLayersFlatten:
                          _controller.flattenLayers,
                    );
                  },
                ),
              ),

            // Burbuja color
            if (!_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 50,
                child: _buildColorBubble(),
              ),

            // Panel colores
            if (_showColors &&
                !_isFullscreen &&
                !_showLayers)
              Positioned(
                right: 8,
                bottom: 110,
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

            // Indicador zoom
            if (!_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 12,
                child: _buildZoomIndicator(),
              ),

            // Botón pantalla completa
            Positioned(
              top: _isFullscreen ? 8 : 60,
              left: _isFullscreen ? 8 : 68,
              child: _buildFullscreenButton(),
            ),

            // Indicador modo zoom
            if (_zoomMode)
              Positioned(
                top: _isFullscreen ? 8 : 60,
                left: _isFullscreen ? 50 : 110,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔍 ZOOM',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Positioned.fill(
      child: GestureDetector(
        onScaleStart: (details) {
          final touchOnCanvas =
              _isTouchOnCanvas(details.localFocalPoint);

          if (details.pointerCount >= 2) {
            // 2 dedos SIEMPRE = zoom/paneo
            // tanto dentro como fuera del lienzo
            _isScaling = true;
            _controller.endStroke();
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
          } else if (!touchOnCanvas || _zoomMode) {
            // 1 dedo fuera del lienzo = zoom/paneo
            // 1 dedo en modo zoom = zoom/paneo
            _isScaling = true;
            _controller.endStroke();
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
          } else {
            // 1 dedo dentro del lienzo = dibujar
            _isScaling = false;
            final canvasPoint = _screenToCanvas(
              details.localFocalPoint,
            );
            _controller.startStroke(canvasPoint);
          }
        },
        onScaleUpdate: (details) {
          if (details.pointerCount >= 2) {
            // 2 dedos = zoom + paneo
            _isScaling = true;
            setState(() {
              _scale = (_startScale * details.scale)
                  .clamp(0.1, 10.0);
              final delta = details.localFocalPoint -
                  _startFocalPoint;
              _offset = _startOffset + delta;
            });
          } else if (_isScaling) {
            // 1 dedo fuera o modo zoom = paneo
            setState(() {
              final delta = details.localFocalPoint -
                  _startFocalPoint;
              _offset = _startOffset + delta;
            });
          } else {
            // 1 dedo dentro = dibujar
            final canvasPoint = _screenToCanvas(
              details.localFocalPoint,
            );
            _controller.continueStroke(canvasPoint);
          }
        },
        onScaleEnd: (details) {
          if (!_isScaling) {
            _controller.endStroke();
          }
          _isScaling = false;
        },
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..translate(_offset.dx, _offset.dy)
                  ..scale(_scale),
                child: CustomPaint(
                  painter: CanvasPainter(
                    layers: _controller.layers,
                    currentStroke: _controller.currentStroke,
                    currentMirrorStroke:
                        _controller.currentMirrorStroke,
                    showGrid: _showGrid,
                    showSymmetryLine:
                        _controller.symmetryEnabled,
                    symmetryEnabled:
                        _controller.symmetryEnabled,
                    activeLayerId: _controller.activeLayerId,
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
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return _buildTopButton(
                icon: Icons.undo,
                onTap: _controller.undo,
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return _buildTopButton(
                icon: Icons.redo,
                onTap: _controller.redo,
              );
            },
          ),
          _buildTopButton(
            icon: _zoomMode
                ? Icons.edit_outlined
                : Icons.zoom_in,
            isActive: _zoomMode,
            onTap: () =>
                setState(() => _zoomMode = !_zoomMode),
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
            icon: _showGrid ? Icons.grid_on : Icons.grid_off,
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
        setState(() {
          _scale = 1.0;
          _offset = Offset.zero;
          _startScale = 1.0;
          _startOffset = Offset.zero;
        });
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
          '${(_scale * 100).round()}%',
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
