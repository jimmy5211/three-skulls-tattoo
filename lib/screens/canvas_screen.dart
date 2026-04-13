import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/layer_panel.dart';
import '../widgets/color_picker.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';
import 'package:flutter/rendering.dart';

enum BrushPanelTab { todos, descargados, creados, sellos }
enum SelloTab { creados, descargados }
enum SelectionMode { ninguno, automatico, libre, rectangular, elipse }
enum TransformMode { ninguno, activo }

class CanvasScreen extends StatefulWidget {
  final Map<String, dynamic>? designParams;
  const CanvasScreen({super.key, this.designParams});

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
  bool _showSelectionOptions = false;

  SelectionMode _selectionMode = SelectionMode.ninguno;
  TransformMode _transformMode = TransformMode.ninguno;
  bool _smudgeMode = false;

  BrushPanelTab _brushTab = BrushPanelTab.todos;
  SelloTab _selloTab = SelloTab.creados;
  BrushCategory? _selectedCategory;
  String _searchQuery = '';
  final ScrollController _brushScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  double _scale = 1.0;
  double _startScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  String _projectName = 'Sin título';
  bool _isScaling = false;
  double _rotation = 0.0;
  double _startRotation = 0.0;

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

    final p = widget.designParams;
    if (p != null) {
      _projectName = p['name'] as String? ?? 'Sin título';
      final bg = p['background'] as String? ?? 'transparente';
      if (bg == 'blanco') {
        _controller.backgroundColor = Colors.white;
      } else if (bg == 'negro') {
        _controller.backgroundColor = Colors.black;
      }
    }
  }

  @override
  void dispose() {
    _brushScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isLandscape =>
      mounted &&
      MediaQuery.of(context).orientation == Orientation.landscape;

  double get _topBarHeight => _isLandscape ? 52.0 : 96.0;

  Offset _screenToCanvas(Offset p) {
  final matrix = Matrix4.identity()
    ..translate(_offset.dx, _offset.dy)
    ..rotateZ(_rotation)
    ..scale(_scale);
  final inverse = Matrix4.inverted(matrix);
  return MatrixUtils.transformPoint(inverse, p);
  }

  bool _isTouchOnCanvas(Offset point) {
    final sw = MediaQuery.of(context).size.width;
    final canvasLeft = _sideBarWidth;
    final canvasRight = _showLayers ? sw - _layerPanelWidth : sw;
    final canvasTop = _isFullscreen ? 0.0 : _topBarHeight;
    return point.dx > canvasLeft &&
        point.dx < canvasRight &&
        point.dy > canvasTop;
  }

  List<BrushModel> get _filteredBrushes {
    switch (_brushTab) {
      case BrushPanelTab.todos:
        return _brushes;
      case BrushPanelTab.descargados:
        return [];
      case BrushPanelTab.creados:
        return [];
      case BrushPanelTab.sellos:
        return [];
    }
  }

  bool get _anyToolActive =>
      _selectionMode != SelectionMode.ninguno ||
      _transformMode != TransformMode.ninguno ||
      _smudgeMode;

  void _deactivateAllTools() {
    setState(() {
      _selectionMode = SelectionMode.ninguno;
      _transformMode = TransformMode.ninguno;
      _smudgeMode = false;
      _showSelectionOptions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
  final size = MediaQuery.of(context).size;
  _controller.updateScreenSize(size);
  // Centrar lienzo al iniciar
  if (_offset == Offset.zero) {
    final p = widget.designParams;
    if (p != null) {
      final orientation = p['orientation'] as String? ?? 'vertical';
      if (orientation == 'horizontal') {
        setState(() {
          _rotation = 1.5708; // 90 grados en radianes
        });
      }
    }
  }
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
    right: _isLandscape ? 70 : 8,
    top: _isLandscape ? _topBarHeight + 8 : null,
    bottom: _isLandscape ? null : 110,
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

            if (_showSelectionOptions && !_isFullscreen)
              _buildSelectionOptionsPanel(),

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
        _buildSelectionBtn(),
        _buildTransformBtn(),
        _buildSmudgeBtn(),
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
              _buildSelectionBtn(),
              _buildTransformBtn(),
              _buildSmudgeBtn(),
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
          _showSelectionOptions = false;
        }
      }),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (c, _) => Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.symmetric(horizontal: 2),
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
              Icon(Icons.brush,
                  color: _showBrushPanel
                      ? AppTheme.accentRed
                      : _textPrimary,
                  size: 18),
              const SizedBox(width: 5),
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
        ),
      ),
    );
  }

  // ─── BOTÓN SELECCIÓN ──────────────────────────────────────
  Widget _buildSelectionBtn() {
    final isActive = _selectionMode != SelectionMode.ninguno;
    return GestureDetector(
      onTap: () => setState(() {
        _showSelectionOptions = !_showSelectionOptions;
        if (_showSelectionOptions) {
          _showBrushPanel = false;
          _showColors = false;
          _transformMode = TransformMode.ninguno;
          _smudgeMode = false;
        } else {
          _selectionMode = SelectionMode.ninguno;
        }
      }),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive || _showSelectionOptions
              ? AppTheme.accentRed.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive || _showSelectionOptions
              ? Border.all(color: AppTheme.accentRed, width: 1)
              : null,
        ),
        child: Icon(
          Icons.select_all,
          color: isActive || _showSelectionOptions
              ? AppTheme.accentRed
              : _textPrimary,
          size: 20,
        ),
      ),
    );
  }

  // ─── BOTÓN TRANSFORMAR ────────────────────────────────────
  Widget _buildTransformBtn() {
    final isActive = _transformMode == TransformMode.activo;
    return GestureDetector(
      onTap: () => setState(() {
        if (isActive) {
          _transformMode = TransformMode.ninguno;
        } else {
          _transformMode = TransformMode.activo;
          _selectionMode = SelectionMode.ninguno;
          _smudgeMode = false;
          _showSelectionOptions = false;
          _showBrushPanel = false;
        }
      }),
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
          Icons.open_with,
          color: isActive ? AppTheme.accentRed : _textPrimary,
          size: 20,
        ),
      ),
    );
  }

  // ─── BOTÓN SMUDGE ─────────────────────────────────────────
  Widget _buildSmudgeBtn() {
    return GestureDetector(
      onTap: () => setState(() {
        _smudgeMode = !_smudgeMode;
        if (_smudgeMode) {
          _selectionMode = SelectionMode.ninguno;
          _transformMode = TransformMode.ninguno;
          _showSelectionOptions = false;
          _showBrushPanel = false;
        }
      }),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _smudgeMode
              ? AppTheme.accentRed.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: _smudgeMode
              ? Border.all(color: AppTheme.accentRed, width: 1)
              : null,
        ),
        child: Icon(
          Icons.back_hand_outlined,
          color: _smudgeMode ? AppTheme.accentRed : _textPrimary,
          size: 20,
        ),
      ),
    );
  }

  // ─── PANEL OPCIONES SELECCIÓN ─────────────────────────────
  Widget _buildSelectionOptionsPanel() {
    return Positioned(
      top: _topBarHeight + 4,
      left: _sideBarWidth + 8,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: _borderColor, width: 0.5),
                  ),
                ),
                child: const Text(
                  'SELECCIÓN',
                  style: TextStyle(
                    fontFamily: 'BlackOpsOne',
                    fontSize: 11,
                    color: _textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _buildSelectionOption(Icons.auto_fix_high,
                  'Automático', SelectionMode.automatico),
              _buildSelectionOption(
                  Icons.gesture, 'Forma libre', SelectionMode.libre),
              _buildSelectionOption(Icons.crop_square,
                  'Rectangular', SelectionMode.rectangular),
              _buildSelectionOption(Icons.circle_outlined,
                  'Elipse', SelectionMode.elipse),
              Container(
                height: 0.5,
                color: _borderColor,
                margin:
                    const EdgeInsets.symmetric(horizontal: 10),
              ),
              GestureDetector(
                onTap: () => _showSelectionSettings(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_outlined,
                          color: _textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Ajustes',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionOption(
      IconData icon, String label, SelectionMode mode) {
    final isActive = _selectionMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _selectionMode =
            isActive ? SelectionMode.ninguno : mode;
        _showSelectionOptions = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentRed.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive
                    ? AppTheme.accentRed
                    : _textPrimary,
                size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 13,
                color: isActive
                    ? AppTheme.accentRed
                    : _textPrimary,
                fontWeight: isActive
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Icon(Icons.check,
                  color: AppTheme.accentRed, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  void _showSelectionSettings() {
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
            'AJUSTES DE SELECCIÓN',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 13,
              color: _textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingRow(Icons.blur_on, 'Suavizado de bordes',
              'Suaviza los bordes de la selección'),
          _buildSettingRow(Icons.invert_colors,
              'Invertir selección',
              'Selecciona lo no seleccionado'),
          _buildSettingRow(Icons.expand_outlined, 'Expandir',
              'Amplía el área seleccionada'),
          _buildSettingRow(Icons.compress, 'Contraer',
              'Reduce el área seleccionada'),
          _buildSettingRow(
              Icons.content_copy_outlined,
              'Copiar selección',
              'Copia el área seleccionada'),
          _buildSettingRow(Icons.cut_outlined,
              'Cortar selección',
              'Corta el área seleccionada'),
          _buildSettingRow(Icons.delete_outline,
              'Limpiar selección',
              'Elimina el contenido seleccionado'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
      IconData icon, String title, String subtitle) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: _borderColor.withOpacity(0.5),
                width: 0.5),
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

  Widget _buildLayersBtn() {
    return GestureDetector(
      onTap: () => setState(() {
        _showLayers = !_showLayers;
        if (_showLayers) {
          _showColors = false;
          _showBrushPanel = false;
          _showSelectionOptions = false;
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
                ? Border.all(
                    color: AppTheme.accentRed, width: 1)
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
          _showSelectionOptions = false;
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
                color:
                    _controller.activeColor.withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SIDEBAR ──────────────────────────────────────────────
  Widget _buildSideBar() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isEraser =
            _controller.activeBrush.type == StrokeType.eraser;
        return Container(
          width: _sideBarWidth,
          decoration: BoxDecoration(
            color: _panelColor.withOpacity(0.95),
            border: Border(
              right:
                  BorderSide(color: _borderColor, width: 0.5),
            ),
          ),
          child: SingleChildScrollView(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.end,
             mainAxisSize: MainAxisSize.min,
             children: [
              // ─── BORRADOR ───────────────────────
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() {
                  if (isEraser) {
                    final normal = _brushes.firstWhere(
                      (b) => b.type != StrokeType.eraser,
                      orElse: () => _brushes.first,
                    );
                    _controller.setActiveBrush(normal);
                  } else {
                    final eraser = _brushes.firstWhere(
                      (b) => b.type == StrokeType.eraser,
                      orElse: () => BrushModel(
                        id: 'eraser',
                        name: 'Borrador',
                        emoji: '🧹',
                        size: _controller.activeBrush.size,
                        opacity: 1.0,
                        type: StrokeType.eraser,
                        category: BrushCategory.todos,
                      ),
                    );
                    _controller.setActiveBrush(eraser);
                  }
                }),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isEraser
                        ? AppTheme.accentRed.withOpacity(0.15)
                        : _cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isEraser
                          ? AppTheme.accentRed
                          : _borderColor,
                      width: isEraser ? 1.5 : 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_fix_normal,
                    color: isEraser
                        ? AppTheme.accentRed
                        : _textSecondary,
                    size: 20,
                  ),
                ),
              ),
              // ─── RESIZE CANVAS ──────────────────
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showResizeCanvasDialog(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _borderColor, width: 0.5),
                  ),
                  child: Icon(Icons.crop,
                      color: _textSecondary, size: 20),
                ),
              ),
              // ─── RESET ROTACIÓN ─────────────────
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () =>
                    setState(() => _rotation = 0.0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _rotation != 0.0
                        ? AppTheme.accentRed.withOpacity(0.15)
                        : _cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _rotation != 0.0
                          ? AppTheme.accentRed
                          : _borderColor,
                      width: _rotation != 0.0 ? 1.5 : 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.screen_rotation_outlined,
                    color: _rotation != 0.0
                        ? AppTheme.accentRed
                        : _textSecondary,
                    size: 18,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                child: Container(
                    height: 0.5, color: _borderColor),
              ),
              // ─── TAM ────────────────────────────
              Text('TAM',
                  style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 9,
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(
                  '${_controller.activeBrush.size.round()}',
                  style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 12,
                      color: _textPrimary,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: _isLandscape ? 70 : 110,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: _borderColor,
                      thumbColor: Colors.white,
                      overlayColor:
                          AppTheme.accentRed.withOpacity(0.15),
                      thumbShape:
                          const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                      trackHeight: 3,
                      overlayShape:
                          const RoundSliderOverlayShape(
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
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10),
                child: Container(
                    height: 0.5, color: _borderColor),
              ),
              const SizedBox(height: 8),
              // ─── OPA ────────────────────────────
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
                height: _isLandscape ? 70 : 110,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.accentRed,
                      inactiveTrackColor: _borderColor,
                      thumbColor: Colors.white,
                      overlayColor:
                          AppTheme.accentRed.withOpacity(0.15),
                      thumbShape:
                          const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                      trackHeight: 3,
                      overlayShape:
                          const RoundSliderOverlayShape(
                              overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _controller.activeBrush.opacity
                          .clamp(0.01, 1.0),
                      min: 0.01,
                      max: 1.0,
                      onChanged: (v) => setState(
                          () =>
                              _controller.setBrushOpacity(v)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
       ); 
      },
    );
  }

  // ─── BRUSH PANEL ──────────────────────────────────────────
  Widget _buildBrushPanelOverlay() {
    return Positioned(
      top: _topBarHeight + 4,
      right: 8,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _isLandscape ? 360 : 300,
          height: MediaQuery.of(context).size.height * 0.82,
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
              _buildBrushPanelHeader(),
              if (_selectedCategory != null)
                Expanded(child: _buildCategoryView())
              else ...[
                _buildBrushTabs(),
                Expanded(
                  child: _brushTab == BrushPanelTab.sellos
                      ? _buildSelloContent()
                      : _brushTab == BrushPanelTab.todos
                          ? _buildTodosContent()
                          : _buildBrushList(_filteredBrushes),
                ),
              ],
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
          bottom:
              BorderSide(color: _borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (_selectedCategory != null)
            GestureDetector(
              onTap: () =>
                  setState(() => _selectedCategory = null),
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _borderColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back_ios,
                    color: _textSecondary, size: 14),
              ),
            ),
          Expanded(
            child: Text(
              _selectedCategory != null
                  ? BrushModel.categoryName(
                          _selectedCategory!)
                      .toUpperCase()
                  : 'BIBLIOTECA DE AGUJAS',
              style: const TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 11,
                color: _textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (_selectedCategory == null)
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
          GestureDetector(
            onTap: () => setState(() {
              _showBrushPanel = false;
              _selectedCategory = null;
              _searchQuery = '';
              _searchController.clear();
            }),
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

  Widget _buildCategoryView() {
    final categoryBrushes = _brushes
        .where((b) => b.category == _selectedCategory)
        .toList();
    return _buildBrushListWithScroll(categoryBrushes);
  }

  Widget _buildTodosContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _panelColor,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: _borderColor, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.search,
                  color: _textSecondary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 13,
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar pinceles...',
                    hintStyle: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            vertical: 8),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                  child: Icon(Icons.close,
                      color: _textSecondary, size: 14),
                ),
            ],
          ),
        ),
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildSearchResults()
              : _buildCategoryGrid(),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final categories = BrushCategory.values
        .where((c) => c != BrushCategory.todos)
        .toList();
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final count =
            _brushes.where((b) => b.category == cat).length;
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedCategory = cat),
          child: Container(
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _borderColor, width: 0.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Text(BrushModel.categoryEmoji(cat),
                    style:
                        const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        BrushModel.categoryName(cat),
                        style: const TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 11,
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$count pinceles',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 9,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: _textSecondary, size: 14),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final query = _searchQuery.toLowerCase();
    final results = _brushes
        .where((b) =>
            b.name.toLowerCase().contains(query) ||
            BrushModel.categoryName(b.category)
                .toLowerCase()
                .contains(query))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                color: _textSecondary, size: 36),
            const SizedBox(height: 12),
            Text(
              'Sin resultados para\n"$_searchQuery"',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 13,
                color: _textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return _buildBrushListWithScroll(results);
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
        onTap: () => setState(() {
          _brushTab = tab;
          _selectedCategory = null;
          _searchQuery = '';
          _searchController.clear();
        }),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive
                ? _cardColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 10,
                color: isActive
                    ? _textPrimary
                    : _textSecondary,
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
    return _buildBrushListWithScroll(brushes);
  }

  Widget _buildBrushListWithScroll(List<BrushModel> brushes) {
    final activeIndex = brushes.indexWhere(
        (b) => b.name == _controller.activeBrush.name);

    if (activeIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_brushScrollController.hasClients) {
          const itemHeight = 68.0;
          final targetOffset =
              (activeIndex * itemHeight).clamp(
                  0.0,
                  _brushScrollController
                      .position.maxScrollExtent);
          _brushScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    if (brushes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.brush_outlined,
                color: _textSecondary, size: 40),
            const SizedBox(height: 12),
            Text('No hay pinceles aquí',
                style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 13,
                    color: _textSecondary)),
            const SizedBox(height: 6),
            Text('Toca ··· para agregar',
                style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color:
                        _textSecondary.withOpacity(0.6))),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.builder(
          controller: _brushScrollController,
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
              _buildSelloTab(
                  'Descargados', SelloTab.descargados),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.interests_outlined,
                    color: _textSecondary, size: 40),
                const SizedBox(height: 12),
                Text('No hay sellos aquí',
                    style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 13,
                        color: _textSecondary)),
                const SizedBox(height: 6),
                Text('Toca ··· para agregar',
                    style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 11,
                        color: _textSecondary
                            .withOpacity(0.6))),
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
            color: isActive
                ? _cardColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 11,
                color: isActive
                    ? _textPrimary
                    : _textSecondary,
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
          _selectedCategory = null;
          _searchQuery = '';
          _searchController.clear();
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
                    style:
                        const TextStyle(fontSize: 16)),
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
                      strokeWidth:
                          brush.size.clamp(1, 8),
                      isDotwork: brush.type ==
                          StrokeType.dotwork,
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
            margin:
                const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('OPCIONES DE PINCELES',
              style: TextStyle(
                  fontFamily: 'BlackOpsOne',
                  fontSize: 13,
                  color: _textPrimary,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _buildOptionRow(Icons.add_circle_outline,
              'Crear pincel', 'Diseña tu propio pincel',
              () => Navigator.pop(context)),
          _buildOptionRow(
              Icons.download_outlined,
              'Importar pincel',
              'Importa archivo .brush de Procreate',
              () => Navigator.pop(context)),
          _buildOptionRow(
              Icons.edit_outlined,
              'Modificar pincel',
              'Edita el pincel seleccionado',
              () => Navigator.pop(context)),
          _buildOptionRow(
              Icons.push_pin_outlined,
              'Fijar pincel',
              'Fija un pincel descargado o creado',
              () => Navigator.pop(context)),
          _buildOptionRow(Icons.sort, 'Organizar orden',
              'Reorganiza tus pinceles',
              () => Navigator.pop(context)),
          _buildOptionRow(
              Icons.delete_outline,
              'Eliminar pincel',
              'Elimina de acceso rápido',
              () => Navigator.pop(context)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionRow(IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: _borderColor.withOpacity(0.5),
                width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: _textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
          if (_showSelectionOptions)
            setState(
                () => _showSelectionOptions = false);
        },
        onScaleStart: (details) {
          if (_showBrushPanel) {
            setState(() => _showBrushPanel = false);
            return;
          }
          if (_showSelectionOptions) {
            setState(
                () => _showSelectionOptions = false);
            return;
          }
          // FIX: 2 dedos o modo zoom activan pan/zoom/rotación
          // desde cualquier punto de la pantalla
          if (details.pointerCount >= 2 || _zoomMode) {
            _isScaling = true;
            _controller.endStroke();
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
            _startRotation = _rotation;
          } else {
            final onCanvas =
                _isTouchOnCanvas(details.localFocalPoint);
            if (onCanvas) {
              _isScaling = false;
              _controller.startStroke(
                  _screenToCanvas(
                      details.localFocalPoint));
            } else {
              _isScaling = true;
              _controller.endStroke();
              _startScale = _scale;
              _startOffset = _offset;
              _startFocalPoint = details.localFocalPoint;
              _startRotation = _rotation;
            }
          }
        },
        onScaleUpdate: (details) {
          if (_showBrushPanel || _showSelectionOptions)
            return;
          if (_isScaling) {
            setState(() {
              if (details.pointerCount >= 2) {
                // FIX: zoom y rotación con 2 dedos
                _scale =
                    (_startScale * details.scale)
                        .clamp(0.1, 10.0);
                _rotation =
                    _startRotation + details.rotation;
              }
              // Pan disponible siempre que _isScaling
              _offset = _startOffset +
                  (details.localFocalPoint -
                      _startFocalPoint);
            });
          } else {
            _controller.continueStroke(
                _screenToCanvas(
                    details.localFocalPoint));
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
                  ..rotateZ(_rotation)
                  ..scale(_scale),
                child: CustomPaint(
                  painter: CanvasPainter(
                    layers: _controller.layers,
                    currentStroke:
                        _controller.currentStroke,
                    currentMirrorStroke:
                        _controller.currentMirrorStroke,
                    showGrid: _showGrid,
                    showSymmetryLine:
                        _controller.symmetryEnabled,
                    symmetryEnabled:
                        _controller.symmetryEnabled,
                    activeLayerId:
                        _controller.activeLayerId,
                    controller: _controller,
                    backgroundColor:
                        _controller.backgroundColor,
                  ),
                  size: Size(
                    _controller.canvasSize.width,
                    _controller.canvasSize.height,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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
              _showSelectionOptions = false;
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
          _showSelectionOptions = false;
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
                  color: _controller.activeColor
                      .withOpacity(0.5),
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
        _rotation = 0.0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _panelColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: _borderColor, width: 0.5),
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
          border:
              Border.all(color: _borderColor, width: 0.5),
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

  void _showResizeCanvasDialog() {
    final wController = TextEditingController(
        text:
            _controller.canvasSize.width.round().toString());
    final hController = TextEditingController(
        text:
            _controller.canvasSize.height.round().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Cambiar tamaño',
            style: TextStyle(
                fontFamily: 'BlackOpsOne',
                color: Colors.white,
                fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontFamily: 'Raleway',
                  color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Ancho (px)',
                labelStyle: TextStyle(
                    fontFamily: 'Raleway',
                    color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: Color(0xFF48484A)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontFamily: 'Raleway',
                  color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Alto (px)',
                labelStyle: TextStyle(
                    fontFamily: 'Raleway',
                    color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: Color(0xFF48484A)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(
                    color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () {
              final w =
                  double.tryParse(wController.text);
              final h =
                  double.tryParse(hController.text);
              if (w != null &&
                  h != null &&
                  w > 0 &&
                  h > 0) {
                setState(() {
                  // FIX: invalidar cache al cambiar tamaño
                  _controller.updateCanvasSize(
                      Size(w, h));
                  _controller.invalidateAllCache();
                  _scale = 1.0;
                  _offset = Offset.zero;
                  _rotation = 0.0;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Aplicar',
                style: TextStyle(
                    color: AppTheme.accentRed,
                    fontWeight: FontWeight.bold)),
          ),
        ],
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
                    fontFamily: 'Raleway',
                    color: Colors.white)),
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

// FIX: Borde rojo tenue visible cuando fondo es transparente
class _CanvasBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x55C0392B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}
