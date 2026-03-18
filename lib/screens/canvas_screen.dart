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

  static const double _sideBarWidth = 56.0;
  static const double _topBarHeight = 52.0;
  static const double _layerPanelWidth = 220.0;

  // Colores estilo Procreate
  static const Color _bgColor = Color(0xFF3A3A3C);
  static const Color _panelColor = Color(0xFF1C1C1E);
  static const Color _cardColor = Color(0xFF2C2C2E);
  static const Color _borderColor = Color(0xFF48484A);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF8E8E93);

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
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Canvas
            _buildCanvas(),

            // Sidebar izquierda TAM/OPA
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

            // Panel pinceles overlay
            if (_showBrushPanel && !_isFullscreen)
              _buildBrushPanelOverlay(),

            // Botón fullscreen
            if (!_showBrushPanel)
              Positioned(
                top: _isFullscreen ? 8 : 60,
                left: _isFullscreen ? 8 : _sideBarWidth + 8,
                child: _buildFullscreenButton(),
              ),

            // Indicador zoom mode
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

  // ─── TOPBAR estilo Procreate ───────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: _topBarHeight,
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(
          bottom: BorderSide(color: _borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Izquierda: back + undo/redo + zoom
          _buildTopBtn(
            icon: Icons.arrow_back_ios,
            onTap: () => context.go('/home'),
          ),
          _buildTopBtn(
            icon: Icons.undo,
            onTap: () => _controller.undo(),
          ),
          _buildTopBtn(
            icon: Icons.redo,
            onTap: () => _controller.redo(),
          ),
          _buildTopBtn(
            icon: _zoomMode ? Icons.edit_outlined : Icons.zoom_in,
            isActive: _zoomMode,
            onTap: () => setState(() => _zoomMode = !_zoomMode),
          ),
          const Spacer(),
          // Centro
          const Text(
            'NUEVO DISEÑO',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 13,
              color: _textPrimary,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          // Derecha: grid + simetría + pinceles + guardar
          _buildTopBtn(
            icon: _showGrid ? Icons.grid_on : Icons.grid_off,
            isActive: _showGrid,
            onTap: () => setState(() => _showGrid = !_showGrid),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => _buildTopBtn(
              icon: Icons.flip,
              isActive: _controller.symmetryEnabled,
              onTap: _controller.toggleSymmetry,
            ),
          ),
          // Botón pinceles — destacado
          _buildBrushTopButton(),
          _buildTopBtn(
            icon: Icons.save_outlined,
            color: AppTheme.accentRed,
            onTap: _saveDesign,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTopBtn({
    required IconData icon,
    VoidCallback? onTap,
    bool isActive = false,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: AppTheme.accentRed, width: 1)
              : null,
        ),
        child: Icon(
          icon,
          color: color ??
              (isActive ? AppTheme.accentRed : _textPrimary),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildBrushTopButton() {
    return GestureDetector(
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
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: _showBrushPanel
                  ? AppTheme.accentRed.withOpacity(0.15)
                  : _cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _showBrushPanel
                    ? AppTheme.accentRed
                    : _borderColor,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.brush,
                  color: _showBrushPanel
                      ? AppTheme.accentRed
                      : _textPrimary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  _controller.activeBrush.name.split(' ').first,
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: _showBrushPanel
                        ? AppTheme.accentRed
                        : _textSecondary,
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
// ─── SIDEBAR TAM/OPA estilo Procreate ─────────────────────
  Widget _buildSideBar() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: _sideBarWidth,
          decoration: BoxDecoration(
            color: _panelColor.withOpacity(0.95),
            border: Border(
              right: BorderSide(color: _borderColor, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // TAM label + valor
              Text(
                'TAM',
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 9,
                  color: _textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_controller.activeBrush.size.round()}',
                style: const TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 13,
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Slider TAM vertical
              Expanded(
                flex: 4,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: _borderColor,
                      thumbColor: Colors.white,
                      overlayColor: AppTheme.accentRed.withOpacity(0.15),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                      ),
                      trackHeight: 4,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      value: _controller.activeBrush.size.clamp(1, 100),
                      min: 1,
                      max: 100,
                      onChanged: (v) =>
                          setState(() => _controller.setBrushSize(v)),
                    ),
                  ),
                ),
              ),
              // Divisor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 0.5,
                  color: _borderColor,
                ),
              ),
              const SizedBox(height: 8),
              // OPA label + valor
              Text(
                'OPA',
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 9,
                  color: _textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(_controller.activeBrush.opacity * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 13,
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Slider OPA vertical
              Expanded(
                flex: 4,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: _borderColor,
                      thumbColor: Colors.white,
                      overlayColor: AppTheme.accentRed.withOpacity(0.15),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                      ),
                      trackHeight: 4,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      value: _controller.activeBrush.opacity.clamp(0.01, 1.0),
                      min: 0.01,
                      max: 1.0,
                      onChanged: (v) =>
                          setState(() => _controller.setBrushOpacity(v)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ─── PANEL PINCELES estilo Procreate ──────────────────────
  Widget _buildBrushPanelOverlay() {
    return Positioned(
      top: _topBarHeight + 4,
      right: 68,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _isLandscape ? 380 : 300,
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _borderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'BIBLIOTECA DE AGUJAS',
                      style: TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 13,
                        color: _textPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showBrushPanel = false),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _borderColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: _textSecondary,
                          size: 16,
                        ),
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
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _brushes.length,
                      itemBuilder: (context, index) {
                        final brush = _brushes[index];
                        final isActive =
                            _controller.activeBrush.name == brush.name;
                        return _buildBrushItem(brush, isActive);
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

  Widget _buildBrushItem(BrushModel brush, bool isActive) {
    return GestureDetector(
      onTap: () {
        _controller.setActiveBrush(brush);
        setState(() => _showBrushPanel = false);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0A84FF).withOpacity(0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Ícono
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.2)
                    : _borderColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  brush.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Nombre + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brush.name,
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 14,
                      color: isActive ? Colors.white : _textPrimary,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Preview línea
                  CustomPaint(
                    size: const Size(double.infinity, 14),
                    painter: _BrushLinePainter(
                      color: isActive
                          ? Colors.white.withOpacity(0.9)
                          : _textSecondary,
                      strokeWidth: brush.size.clamp(1, 8),
                      isDotwork: brush.type == StrokeType.dotwork,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getBrushIcon(StrokeType type) {
    switch (type) {
      case StrokeType.liner:
        return Icons.edit;
      case StrokeType.shader:
        return Icons.brush;
      case StrokeType.fill:
        return Icons.format_paint;
      case StrokeType.eraser:
        return Icons.auto_fix_high;
      case StrokeType.dotwork:
        return Icons.more_horiz;
    }
  }

  // ─── CANVAS ───────────────────────────────────────────────
  Widget _buildCanvas() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          if (_showBrushPanel) setState(() => _showBrushPanel = false);
        },
        onScaleStart: (details) {
          if (_showBrushPanel) {
            setState(() => _showBrushPanel = false);
            return;
          }
          final touchOnCanvas = _isTouchOnCanvas(details.localFocalPoint);
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
            _controller.startStroke(_screenToCanvas(details.localFocalPoint));
          }
        },
        onScaleUpdate: (details) {
          if (_showBrushPanel) return;
          if (details.pointerCount >= 2) {
            _isScaling = true;
            setState(() {
              _scale = (_startScale * details.scale).clamp(0.1, 10.0);
              _offset = _startOffset + (details.localFocalPoint - _startFocalPoint);
            });
          } else if (_isScaling) {
            setState(() {
              _offset = _startOffset + (details.localFocalPoint - _startFocalPoint);
            });
          } else {
            _controller.continueStroke(_screenToCanvas(details.localFocalPoint));
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
                    currentMirrorStroke: _controller.currentMirrorStroke,
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

  // ─── BURBUJAS ─────────────────────────────────────────────
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
                  : _panelColor.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showLayers ? AppTheme.accentRed : _borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.layers_outlined, color: Colors.white, size: 20),
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showColors ? Colors.white : Colors.white.withOpacity(0.3),
                width: _showColors ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _controller.activeColor.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
      onTap: () => setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
        _startScale = 1.0;
        _startOffset = Offset.zero;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _panelColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: Text(
          '${(_scale * 100).round()}%',
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 11,
            color: _textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return GestureDetector(
      onTap: () => setState(() => _isFullscreen = !_isFullscreen),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _panelColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: Icon(
          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          color: _textPrimary,
          size: 20,
        ),
      ),
    );
  }

  void _saveDesign() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _cardColor,
        content: const Row(
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
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── BRUSH LINE PAINTER ───────────────────────────────────
class _BrushLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isDotwork;

  _BrushLinePainter({
    required this.color,
    required this.strokeWidth,
    this.isDotwork = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isDotwork) {
      paint.style = PaintingStyle.fill;
      double x = 2;
      while (x < size.width - 2) {
        canvas.drawCircle(
          Offset(x, size.height / 2),
          strokeWidth / 2,
          paint,
        );
        x += strokeWidth * 2.5;
      }
      return;
    }

    final path = Path();
    path.moveTo(0, size.height * 0.75);
    path.cubicTo(
      size.width * 0.2, size.height * 0.1,
      size.width * 0.5, size.height * 0.95,
      size.width * 0.8, size.height * 0.2,
    );
    path.lineTo(size.width, size.height * 0.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
