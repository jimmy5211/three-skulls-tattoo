import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/layer_panel.dart';
import '../widgets/color_picker.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';

// Secciones del panel de pinceles
enum BrushPanelTab { todos, descargados, creados, sellos }
enum SelloTab { creados, descargados }

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
  bool _eraserMode = false;

  // Subventanas panel pinceles
  BrushPanelTab _brushTab = BrushPanelTab.todos;
  SelloTab _selloTab = SelloTab.creados;

  double _scale = 1.0;
  double _startScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  bool _isScaling = false;

  static const double _sideBarWidth = 56.0;
  static const double _layerPanelWidth = 220.0;

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

  bool get _isLandscape =>
      mounted &&
      MediaQuery.of(context).orientation == Orientation.landscape;

  double get _topBarHeight => _isLandscape ? 52.0 : 96.0;

  Offset _screenToCanvas(Offset p) => Offset(
        (p.dx - _offset.dx) / _scale,
        (p.dy - _offset.dy) / _scale,
      );

  bool _isTouchOnCanvas(Offset point) {
    final sw = MediaQuery.of(context).size.width;
    final canvasLeft = _sideBarWidth;
    final canvasRight =
        _showLayers ? sw - _layerPanelWidth : sw;
    final canvasTop = _isFullscreen ? 0.0 : _topBarHeight;
    return point.dx > canvasLeft &&
        point.dx < canvasRight &&
        point.dy > canvasTop;
  }

  // Filtrar pinceles según tab activo
  List<BrushModel> get _filteredBrushes {
    switch (_brushTab) {
      case BrushPanelTab.todos:
        return _brushes;
      case BrushPanelTab.descargados:
        return []; // futuro
      case BrushPanelTab.creados:
        return []; // futuro
      case BrushPanelTab.sellos:
        return []; // futuro
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.updateCanvasSize(MediaQuery.of(context).size);
    });

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            _buildCanvas(),

            if (!_isFullscreen)
              Positioned(
                left: 0,
                top: _topBarHeight,
                bottom: 0,
                child: _buildSideBar(),
              ),

            if (!_isFullscreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),

            if (!_isFullscreen)
              Positioned(
                right: 8,
                top: _topBarHeight + 8,
                child: _buildLayersBubble(),
              ),

            if (_showLayers && !_isFullscreen)
              Positioned(
                right: 0,
                top: _topBarHeight,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => LayerPanel(
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
                  ),
                ),
              ),

            if (!_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 50,
                child: _buildColorBubble(),
              ),

            if (_showColors && !_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 110,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => ColorPicker(
                    activeColor: _controller.activeColor,
                    onColorSelected: _controller.setActiveColor,
                  ),
                ),
              ),

            if (!_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 12,
                child: _buildZoomIndicator(),
              ),

            if (_showBrushPanel && !_isFullscreen)
              _buildBrushPanelOverlay(),

            if (!_showBrushPanel)
              Positioned(
                top: _isFullscreen ? 8 : _topBarHeight + 8,
                left: _isFullscreen ? 8 : _sideBarWidth + 8,
                child: _buildFullscreenButton(),
              ),
          ],
        ),
      ),
    );
  }

  // ─── TOPBAR ───────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: _topBarHeight,
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(
          bottom: BorderSide(color: _borderColor, width: 0.5),
        ),
      ),
      child: _isLandscape
          ? _buildTopBarSingleRow()
          : _buildTopBarTwoRows(),
    );
  }

  Widget _buildTopBarSingleRow() {
    return Row(
      children: [
        const SizedBox(width: 4),
        _btn(Icons.arrow_back_ios, onTap: () => context.go('/home')),
        _btn(Icons.undo, onTap: _controller.undo),
        _btn(Icons.redo, onTap: _controller.redo),
        _btn(
          _zoomMode ? Icons.edit_outlined : Icons.zoom_in,
          isActive: _zoomMode,
          onTap: () => setState(() => _zoomMode = !_zoomMode),
        ),
        _btn(
          _showGrid ? Icons.grid_on : Icons.grid_off,
          isActive: _showGrid,
          onTap: () => setState(() => _showGrid = !_showGrid),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (c, _) => _btn(
            Icons.flip,
            isActive: _controller.symmetryEnabled,
            onTap: _controller.toggleSymmetry,
          ),
        ),
        const Spacer(),
        _buildBrushBtn(),
        _buildEraserBtn(),
        _buildLayersBtn(),
        _buildColorBtn(),
        _btn(Icons.save_outlined,
            color: AppTheme.accentRed, onTap: _saveDesign),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTopBarTwoRows() {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 4),
              _btn(Icons.arrow_back_ios,
                  onTap: () => context.go('/home')),
              _btn(Icons.undo, onTap: _controller.undo),
              _btn(Icons.redo, onTap: _controller.redo),
              _btn(
                _zoomMode ? Icons.edit_outlined : Icons.zoom_in,
                isActive: _zoomMode,
                onTap: () =>
                    setState(() => _zoomMode = !_zoomMode),
              ),
              _btn(
                _showGrid ? Icons.grid_on : Icons.grid_off,
                isActive: _showGrid,
                onTap: () =>
                    setState(() => _showGrid = !_showGrid),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (c, _) => _btn(
                  Icons.flip,
                  isActive: _controller.symmetryEnabled,
                  onTap: _controller.toggleSymmetry,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Container(height: 0.5, color: _borderColor),
        SizedBox(
          height: 47,
          child: Row(
            children: [
              const SizedBox(width: 4),
              _buildBrushBtn(),
              const SizedBox(width: 4),
              _buildEraserBtn(),
              const Spacer(),
              _buildLayersBtn(),
              _buildColorBtn(),
              _btn(Icons.save_outlined,
                  color: AppTheme.accentRed, onTap: _saveDesign),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(IconData icon, {
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
        child: Icon(icon,
            color: color ??
                (isActive ? AppTheme.accentRed : _textPrimary),
            size: 20),
      ),
    );
  }

  Widget _buildBrushBtn() {
    return GestureDetector(
      onTap: () => setState(() {
        _showBrushPanel = !_showBrushPanel;
        if (_showBrushPanel) {
          _showColors = false;
          _showLayers = false;
          _eraserMode = false;
        }
      }),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (c, _) => Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: (_showBrushPanel && !_eraserMode)
                ? AppTheme.accentRed.withOpacity(0.15)
                : _cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (_showBrushPanel && !_eraserMode)
                  ? AppTheme.accentRed
                  : _borderColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.brush,
                  color: (_showBrushPanel && !_eraserMode)
                      ? AppTheme.accentRed
                      : _textPrimary,
                  size: 18),
              const SizedBox(width: 5),
              Text(
                _controller.activeBrush.name.split(' ').first,
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 11,
                  color: (_showBrushPanel && !_eraserMode)
                      ? AppTheme.accentRed
                      : _textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEraserBtn() {
    return GestureDetector(
      onTap: () {
        setState(() => _eraserMode = !_eraserMode);
        if (_eraserMode) {
          final eraser = _brushes.firstWhere(
            (b) => b.type == StrokeType.eraser,
            orElse: () => _brushes.last,
          );
          _controller.setActiveBrush(eraser);
        } else {
          final liner = _brushes.firstWhere(
            (b) => b.type == StrokeType.liner,
            orElse: () => _brushes.first,
          );
          _controller.setActiveBrush(liner);
        }
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _eraserMode
              ? AppTheme.accentRed.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: _eraserMode
              ? Border.all(color: AppTheme.accentRed, width: 1)
              : null,
        ),
        child: Icon(Icons.auto_fix_high,
            color:
                _eraserMode ? AppTheme.accentRed : _textPrimary,
            size: 20),
      ),
    );
  }

  Widget _buildLayersBtn() {
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
        builder: (c, _) => Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _showLayers
                ? AppTheme.accentRed.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: _showLayers
                ? Border.all(color: AppTheme.accentRed, width: 1)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.layers_outlined,
                  color: _showLayers
                      ? AppTheme.accentRed
                      : _textPrimary,
                  size: 20),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _showLayers
                        ? AppTheme.accentRed
                        : _borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${_controller.layers.length}',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorBtn() {
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
        builder: (c, _) => Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _controller.activeColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: _showColors
                  ? Colors.white
                  : Colors.white.withOpacity(0.4),
              width: _showColors ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _controller.activeColor.withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
// ─── SIDEBAR TAM/OPA compacto ─────────────────────────────
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TAM
              Text('TAM',
                  style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 9,
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text('${_controller.activeBrush.size.round()}',
                  style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 12,
                      color: _textPrimary,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: _borderColor,
                      thumbColor: Colors.white,
                      overlayColor:
                          AppTheme.accentRed.withOpacity(0.15),
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      trackHeight: 3,
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _controller.activeBrush.size
                          .clamp(1, 100),
                      min: 1,
                      max: 100,
                      onChanged: (v) => setState(
                          () => _controller.setBrushSize(v)),
                    ),
                  ),
                ),
              ),
              // Divisor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(height: 0.5, color: _borderColor),
              ),
              const SizedBox(height: 8),
              // OPA
              Text('OPA',
                  style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 9,
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(
                  '${(_controller.activeBrush.opacity * 100).round()}%',
                  style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 12,
                      color: _textPrimary,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: _borderColor,
                      thumbColor: Colors.white,
                      overlayColor:
                          AppTheme.accentRed.withOpacity(0.15),
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      trackHeight: 3,
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _controller.activeBrush.opacity
                          .clamp(0.01, 1.0),
                      min: 0.01,
                      max: 1.0,
                      onChanged: (v) => setState(
                          () => _controller.setBrushOpacity(v)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── PANEL PINCELES con tabs y opciones ───────────────────
  Widget _buildBrushPanelOverlay() {
    return Positioned(
      top: _topBarHeight + 4,
      right: 8,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _isLandscape ? 360 : 300,
          height: MediaQuery.of(context).size.height * 0.75,
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
              _buildBrushPanelHeader(),
              // Tabs
              _buildBrushTabs(),
              // Contenido según tab
              Expanded(
                child: _brushTab == BrushPanelTab.sellos
                    ? _buildSelloContent()
                    : _buildBrushList(_filteredBrushes),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrushPanelHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
              fontSize: 11,
              color: _textPrimary,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          // Botón ... opciones
          GestureDetector(
            onTap: () => _showBrushOptions(),
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _borderColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.more_horiz,
                  color: _textSecondary, size: 18),
            ),
          ),
          // Botón cerrar
          GestureDetector(
            onTap: () => setState(() => _showBrushPanel = false),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _borderColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close,
                  color: _textSecondary, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrushTabs() {
    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTab('Todos', BrushPanelTab.todos),
          _buildTab('Descargados', BrushPanelTab.descargados),
          _buildTab('Creados', BrushPanelTab.creados),
          _buildTab('Sellos', BrushPanelTab.sellos),
        ],
      ),
    );
  }

  Widget _buildTab(String label, BrushPanelTab tab) {
    final isActive = _brushTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _brushTab = tab),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? _cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 10,
                color: isActive ? _textPrimary : _textSecondary,
                fontWeight: isActive
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrushList(List<BrushModel> brushes) {
    if (brushes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.brush_outlined,
                color: _textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              'No hay pinceles aquí',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Toca ··· para agregar',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 11,
                color: _textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: brushes.length,
          itemBuilder: (context, index) {
            final brush = brushes[index];
            final isActive =
                _controller.activeBrush.name == brush.name;
            return _buildBrushItem(brush, isActive);
          },
        );
      },
    );
  }

  Widget _buildSelloContent() {
    return Column(
      children: [
        // Sub-tabs sellos
        Container(
          height: 34,
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          decoration: BoxDecoration(
            color: _panelColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildSelloTab('Creados', SelloTab.creados),
              _buildSelloTab('Descargados', SelloTab.descargados),
            ],
          ),
        ),
        // Lista vacía por ahora
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.interests_outlined,
                    color: _textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  'No hay sellos aquí',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toca ··· para agregar',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: _textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelloTab(String label, SelloTab tab) {
    final isActive = _selloTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selloTab = tab),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? _cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 11,
                color: isActive ? _textPrimary : _textSecondary,
                fontWeight: isActive
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrushItem(BrushModel brush, bool isActive) {
    return GestureDetector(
      onTap: () {
        _controller.setActiveBrush(brush);
        setState(() {
          _showBrushPanel = false;
          _eraserMode = brush.type == StrokeType.eraser;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0A84FF).withOpacity(0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.2)
                    : _borderColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(brush.emoji,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brush.name,
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 13,
                      color: isActive
                          ? Colors.white
                          : _textPrimary,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CustomPaint(
                    size: const Size(double.infinity, 12),
                    painter: _BrushLinePainter(
                      color: isActive
                          ? Colors.white.withOpacity(0.9)
                          : _textSecondary,
                      strokeWidth: brush.size.clamp(1, 8),
                      isDotwork:
                          brush.type == StrokeType.dotwork,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle,
                  color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _showBrushOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'OPCIONES DE PINCELES',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 13,
              color: _textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildOptionRow(
              Icons.add_circle_outline, 'Crear pincel',
              'Diseña tu propio pincel', () {
            Navigator.pop(context);
          }),
          _buildOptionRow(
              Icons.download_outlined, 'Importar pincel',
              'Importa archivo .brush de Procreate', () {
            Navigator.pop(context);
          }),
          _buildOptionRow(
              Icons.edit_outlined, 'Modificar pincel',
              'Edita el pincel seleccionado', () {
            Navigator.pop(context);
          }),
          _buildOptionRow(
              Icons.push_pin_outlined, 'Fijar pincel',
              'Fija un pincel descargado o creado', () {
            Navigator.pop(context);
          }),
          _buildOptionRow(
              Icons.sort, 'Organizar orden',
              'Reorganiza tus pinceles', () {
            Navigator.pop(context);
          }),
          _buildOptionRow(
              Icons.delete_outline, 'Eliminar pincel',
              'Elimina de acceso rápido', () {
            Navigator.pop(context);
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionRow(
      IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: _borderColor.withOpacity(0.5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: _textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 14,
                          color: _textPrimary,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 11,
                          color: _textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: _textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  // ─── CANVAS ───────────────────────────────────────────────
  Widget _buildCanvas() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          if (_showBrushPanel)
            setState(() => _showBrushPanel = false);
        },
        onScaleStart: (details) {
          if (_showBrushPanel) {
            setState(() => _showBrushPanel = false);
            return;
          }
          final onCanvas =
              _isTouchOnCanvas(details.localFocalPoint);
          if (details.pointerCount >= 2) {
            _isScaling = true;
            _controller.endStroke();
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
          } else if (!onCanvas || _zoomMode) {
            _isScaling = true;
            _controller.endStroke();
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
          } else {
            _isScaling = false;
            _controller.startStroke(
                _screenToCanvas(details.localFocalPoint));
          }
        },
        onScaleUpdate: (details) {
          if (_showBrushPanel) return;
          if (details.pointerCount >= 2) {
            _isScaling = true;
            setState(() {
              _scale = (_startScale * details.scale)
                  .clamp(0.1, 10.0);
              _offset = _startOffset +
                  (details.localFocalPoint - _startFocalPoint);
            });
          } else if (_isScaling) {
            setState(() {
              _offset = _startOffset +
                  (details.localFocalPoint - _startFocalPoint);
            });
          } else {
            _controller.continueStroke(
                _screenToCanvas(details.localFocalPoint));
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
                    showSymmetryLine:
                        _controller.symmetryEnabled,
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

  // ─── WIDGETS FLOTANTES ────────────────────────────────────
  Widget _buildLayersBubble() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => setState(() {
            _showLayers = !_showLayers;
            if (_showLayers) {
              _showColors = false;
              _showBrushPanel = false;
            }
          }),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _showLayers
                  ? AppTheme.accentRed
                  : _panelColor.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showLayers
                    ? AppTheme.accentRed
                    : _borderColor,
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
                const Icon(Icons.layers_outlined,
                    color: Colors.white, size: 20),
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
          ),
        );
      },
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
                color: _showColors
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                width: _showColors ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _controller.activeColor.withOpacity(0.5),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
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
      onTap: () =>
          setState(() => _isFullscreen = !_isFullscreen),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _panelColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: Icon(
          _isFullscreen
              ? Icons.fullscreen_exit
              : Icons.fullscreen,
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
            Text('Diseño guardado',
                style: TextStyle(
                    fontFamily: 'Raleway', color: Colors.white)),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
