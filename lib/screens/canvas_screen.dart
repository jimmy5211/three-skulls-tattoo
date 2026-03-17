import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/layer_panel.dart';
import '../widgets/color_picker.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';

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
  bool _showBrushPanel = false;
  bool _showGrid = false;
  bool _isFullscreen = false;
  bool _zoomMode = false;

  double _scale = 1.0;
  double _startScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  bool _isScaling = false;

  static const double _sideBarWidth = 52.0;
  static const double _topBarHeight = 52.0;
  static const double _layerPanelWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _controller = CanvasController();
    _brushes = BrushModel.defaultBrushes();
  }

  bool get _isLandscape {
    if (!mounted) return false;
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  Offset _screenToCanvas(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - _offset.dx) / _scale,
      (screenPoint.dy - _offset.dy) / _scale,
    );
  }

  bool _isTouchOnCanvas(Offset point) {
    final screenWidth = MediaQuery.of(context).size.width;
    final canvasLeft = _sideBarWidth;
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
      backgroundColor: const Color(0xFF3A3A3C),
      body: SafeArea(
        child: Stack(
          children: [
            // Canvas
            _buildCanvas(),

            // Barra lateral izquierda TAM/OPA
            if (!_isFullscreen)
              Positioned(
                left: 0,
                top: _topBarHeight,
                bottom: 0,
                child: _buildSideBar(),
              ),

            // Topbar
            if (!_isFullscreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
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
                top: _topBarHeight,
                bottom: 0,
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
                      onClose: () =>
                          setState(() => _showLayers = false),
                      onLayerDuplicated: _controller.duplicateLayer,
                      onLayerMergedDown: _controller.mergeDownLayer,
                      onLayerLocked: _controller.lockLayer,
                      onLayersFlatten: _controller.flattenLayers,
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
            if (_showColors && !_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 110,
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

            // Indicador zoom
            if (!_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 12,
                child: _buildZoomIndicator(),
              ),

            // Panel pinceles overlay estilo Procreate
            if (_showBrushPanel && !_isFullscreen)
              _buildBrushPanelOverlay(),

            // Botón fullscreen
            if (!_showBrushPanel)
              Positioned(
                top: _isFullscreen ? 8 : 60,
                left: _isFullscreen ? 8 : _sideBarWidth + 8,
                child: _buildFullscreenButton(),
              ),

            // Indicador modo zoom
            if (_zoomMode)
              Positioned(
                top: _isFullscreen ? 8 : 60,
                left: _isFullscreen ? 50 : _sideBarWidth + 50,
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

  // ─── TOPBAR ────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: _topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withOpacity(0.97),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Izquierda
          _buildTopButton(
            icon: Icons.arrow_back_ios,
            onTap: () => context.go('/home'),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => _buildTopButton(
              icon: Icons.undo,
              onTap: _controller.undo,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => _buildTopButton(
              icon: Icons.redo,
              onTap: _controller.redo,
            ),
          ),
          _buildTopButton(
            icon: _zoomMode ? Icons.edit_outlined : Icons.zoom_in,
            isActive: _zoomMode,
            onTap: () => setState(() => _zoomMode = !_zoomMode),
          ),

          const Spacer(),

          // Centro — nombre
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

          // Derecha
          _buildTopButton(
            icon: _showGrid ? Icons.grid_on : Icons.grid_off,
            isActive: _showGrid,
            onTap: () => setState(() => _showGrid = !_showGrid),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => _buildTopButton(
              icon: Icons.flip,
              isActive: _controller.symmetryEnabled,
              onTap: _controller.toggleSymmetry,
            ),
          ),
          // Botón pinceles
          GestureDetector(
            onTap: () => setState(() {
              _showBrushPanel = !_showBrushPanel;
              if (_showBrushPanel) {
                _showColors = false;
                _showLayers = false;
              }
            }),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _showBrushPanel
                        ? AppTheme.accentRed.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: _showBrushPanel
                        ? Border.all(
                            color: AppTheme.accentRed, width: 1)
                        : null,
                  ),
                  child: Icon(
                    Icons.brush,
                    color: _showBrushPanel
                        ? AppTheme.accentRed
                        : AppTheme.textWhite,
                    size: 18,
                  ),
                );
              },
            ),
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
              ? Border.all(color: AppTheme.accentRed, width: 1)
              : null,
        ),
        child: Icon(
          icon,
          color: color ??
              (isActive ? AppTheme.accentRed : AppTheme.textWhite),
          size: 18,
        ),
      ),
    );
  }

  // ─── BARRA LATERAL TAM/OPA ─────────────────────────────────
  Widget _buildSideBar() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: _sideBarWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.92),
            border: const Border(
              right: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Label TAM
              const Text(
                'TAM',
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 9,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              // Valor TAM
              Text(
                '${_controller.activeBrush.size.round()}',
                style: const TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              // Slider TAM vertical
              Expanded(
                flex: 3,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: const Color(0xFF3A3A3C),
                      thumbColor: Colors.white,
                      overlayColor:
                          AppTheme.accentRed.withOpacity(0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      trackHeight: 3,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                    ),
                    child: Slider(
                      value: _controller.activeBrush.size,
                      min: 1,
                      max: 100,
                      onChanged: (v) =>
                          setState(() => _controller.setBrushSize(v)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Divisor
              Container(
                height: 0.5,
                width: 32,
                color: const Color(0xFF3A3A3C),
              ),
              const SizedBox(height: 8),
              // Label OPA
              const Text(
                'OPA',
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 9,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              // Valor OPA
              Text(
                '${(_controller.activeBrush.opacity * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              // Slider OPA vertical
              Expanded(
                flex: 3,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: const Color(0xFF3A3A3C),
                      thumbColor: Colors.white,
                      overlayColor:
                          AppTheme.accentRed.withOpacity(0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      trackHeight: 3,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                    ),
                    child: Slider(
                      value: _controller.activeBrush.opacity,
                      min: 0.01,
                      max: 1.0,
                      onChanged: (v) => setState(
                          () => _controller.setBrushOpacity(v)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ─── PANEL PINCELES OVERLAY estilo Procreate ───────────────
  Widget _buildBrushPanelOverlay() {
    return Positioned(
      top: _topBarHeight + 4,
      right: 8,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _isLandscape ? 420 : 320,
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF3A3A3C),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'PINCELES',
                      style: TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 14,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showBrushPanel = false),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF8E8E93),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de pinceles
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _brushes.length,
                      itemBuilder: (context, index) {
                        final brush = _brushes[index];
                        final isActive =
                            _controller.activeBrush.name ==
                                brush.name;
                        return GestureDetector(
                          onTap: () {
                            _controller.setActiveBrush(brush);
                            setState(() => _showBrushPanel = false);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.accentRed
                                      .withOpacity(0.25)
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(10),
                              border: isActive
                                  ? Border.all(
                                      color: AppTheme.accentRed,
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Ícono tipo pincel
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.accentRed
                                            .withOpacity(0.3)
                                        : const Color(0xFF3A3A3C),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getBrushIcon(brush.type),
                                    color: isActive
                                        ? AppTheme.accentRed
                                        : const Color(0xFF8E8E93),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        brush.name,
                                        style: TextStyle(
                                          fontFamily: 'Raleway',
                                          fontSize: 14,
                                          color: isActive
                                              ? Colors.white
                                              : const Color(
                                                  0xFFE5E5EA),
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      // Preview línea del pincel
                                      const SizedBox(height: 4),
                                      CustomPaint(
                                        size: const Size(
                                            double.infinity, 12),
                                        painter: _BrushPreviewPainter(
                                          color: isActive
                                              ? AppTheme.accentRed
                                              : const Color(
                                                  0xFF8E8E93),
                                          strokeWidth:
                                              brush.size.clamp(1, 8),
                                          isDashed: brush.type ==
                                              StrokeType.dotted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  const Icon(
                                    Icons.check,
                                    color: AppTheme.accentRed,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getBrushIcon(StrokeType type) {
    switch (type) {
      case StrokeType.pen:
        return Icons.edit;
      case StrokeType.brush:
        return Icons.brush;
      case StrokeType.marker:
        return Icons.format_paint;
      case StrokeType.eraser:
        return Icons.auto_fix_high;
      case StrokeType.dotted:
        return Icons.more_horiz;
      default:
        return Icons.brush;
    }
  }

  // ─── CANVAS ────────────────────────────────────────────────
  Widget _buildCanvas() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          if (_showBrushPanel) {
            setState(() => _showBrushPanel = false);
          }
        },
        onScaleStart: (details) {
          if (_showBrushPanel) {
            setState(() => _showBrushPanel = false);
            return;
          }
          final touchOnCanvas =
              _isTouchOnCanvas(details.localFocalPoint);
          if (details.pointerCount >= 2) {
            _isScaling = true;
            _controller.endStroke();
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
          } else if (!touchOnCanvas || _zoomMode) {
            _isScaling = true;
            _controller.endStroke();
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
          } else {
            _isScaling = false;
            final canvasPoint =
                _screenToCanvas(details.localFocalPoint);
            _controller.startStroke(canvasPoint);
          }
        },
        onScaleUpdate: (details) {
          if (_showBrushPanel) return;
          if (details.pointerCount >= 2) {
            _isScaling = true;
            setState(() {
              _scale = (_startScale * details.scale)
                  .clamp(0.1, 10.0);
              final delta =
                  details.localFocalPoint - _startFocalPoint;
              _offset = _startOffset + delta;
            });
          } else if (_isScaling) {
            setState(() {
              final delta =
                  details.localFocalPoint - _startFocalPoint;
              _offset = _startOffset + delta;
            });
          } else {
            final canvasPoint =
                _screenToCanvas(details.localFocalPoint);
            _controller.continueStroke(canvasPoint);
          }
        },
        onScaleEnd: (details) {
          if (!_isScaling) _controller.endStroke();
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
                    showSymmetryLine: _controller.symmetryEnabled,
                    symmetryEnabled: _controller.symmetryEnabled,
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

  // ─── BURBUJAS ──────────────────────────────────────────────
  Widget _buildLayersBubble() {
    return GestureDetector(
      onTap: () => setState(() {
        _showLayers = !_showLayers;
        if (_showLayers) {
          _showColors = false;
          _showBrushPanel = false;
        }
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
                  : const Color(0xFF1C1C1E).withOpacity(0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showLayers
                    ? AppTheme.accentRed
                    : const Color(0xFF3A3A3C),
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
        if (_showColors) {
          _showLayers = false;
          _showBrushPanel = false;
        }
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
                  color:
                      _controller.activeColor.withOpacity(0.4),
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
          color: const Color(0xFF1C1C1E).withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF3A3A3C),
            width: 0.5,
          ),
        ),
        child: Text(
          '${(_scale * 100).round()}%',
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 10,
            color: Color(0xFF8E8E93),
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
          color: const Color(0xFF1C1C1E).withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF3A3A3C),
            width: 0.5,
          ),
        ),
        child: Icon(
          _isFullscreen
              ? Icons.fullscreen_exit
              : Icons.fullscreen,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  void _saveDesign() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2C2C2E),
        content: Row(
          children: [
            Text('💀', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text(
              'Diseño guardado',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: Colors.white,
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─── BRUSH PREVIEW PAINTER ─────────────────────────────────
class _BrushPreviewPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isDashed;

  _BrushPreviewPainter({
    required this.color,
    required this.strokeWidth,
    this.isDashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isDashed) {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(x + 6, size.height / 2),
          paint,
        );
        x += 12;
      }
    } else {
      final path = Path();
      path.moveTo(0, size.height * 0.7);
      path.cubicTo(
        size.width * 0.25, size.height * 0.2,
        size.width * 0.5, size.height * 0.9,
        size.width * 0.75, size.height * 0.3,
      );
      path.lineTo(size.width, size.height * 0.5);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
