import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../controllers/canvas_controller.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/layer_panel.dart';
import '../widgets/color_picker.dart';
import '../models/brush_model.dart';
import '../models/canvas_image_model.dart';
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

  // ─── SELECCIÓN ───────────────────────────────────────────
  List<Offset> _selectionPoints = [];
  Offset? _selectionDragStart;
  Offset? _selectionDragCurrent;
  bool _isDraggingSelection = false;
  Offset? _selectionMoveStart;

  // Forma persistida después de soltar
  List<Offset> _finalizedSelectionPoints = [];
  Offset? _finalizedStart;
  Offset? _finalizedEnd;
  SelectionMode _finalizedMode = SelectionMode.ninguno;

  // ─── IMAGEN EN CANVAS ────────────────────────────────────
  String? _selectedImageId;
  bool _isDraggingImage = false;
  Offset? _lastDragCanvas;

  // ─── RESIZE / ROTATE DE IMAGEN ───────────────────────────
  bool _isResizingImage = false;
  bool _isRotatingImage = false;
  int _activeImageHandle = -1;     // 0=TL 1=TR 2=BL 3=BR 4=ROT
  Offset? _lastResizeCanvas;
  double _imageRotationStartAngle = 0.0;
  Offset? _imageRotationCenter;

  // ─── RESIZE DE SELECCIÓN ─────────────────────────────────
  bool _isResizingHandle = false;
  int _activeResizeHandle = -1;    // 0-7 = handles, 8 = rotación
  Rect? _resizeStartBounds;
  Offset? _resizeHandleStart;
  double _selectionStartRotation = 0.0;
  double _selectionAngle = 0.0;  // ángulo acumulado de la selección

  // ─── BORRADOR EN IMAGEN ──────────────────────────────────
  String? _erasingImageId;
  // Punto del CANVAS bajo el focal point al inicio del gesto (en coords canvas)
  Offset _canvasFocalPoint = Offset.zero;

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
      final wPx = p['widthPx'] as int? ?? 1080;
      final hPx = p['heightPx'] as int? ?? 1920;
      _controller.updateCanvasSize(Size(wPx.toDouble(), hPx.toDouble()));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          final screen = MediaQuery.of(context).size;
          final sideBar = _sideBarWidth;
          final topBar = _topBarHeight;
          final aW = screen.width - sideBar;
          final aH = screen.height - topBar;
          final scaleX = aW / wPx;
          final scaleY = aH / hPx;
          final s = (scaleX < scaleY ? scaleX : scaleY) * 0.85;
          setState(() {
            _scale = s;
            _offset = Offset(
              sideBar + (aW - wPx * s) / 2,
              topBar + (aH - hPx * s) / 2,
            );
          });
        });
      });
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

  /// Convierte punto pantalla a canvas con transform explícito
  /// (sin usar el estado actual — para usar valores guardados al inicio del gesto)
  Offset _screenToCanvasWithTransform(
      Offset screenPoint, Offset offset, double rotation, double scale) {
    final matrix = Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..rotateZ(rotation)
      ..scale(scale);
    final inverse = Matrix4.inverted(matrix);
    return MatrixUtils.transformPoint(inverse, screenPoint);
  }

  /// Convierte un delta de pantalla a delta de canvas (con rotación actual)
  Offset _screenDeltaToCanvas(Offset screenDelta) {
    final cosR = cos(_rotation);
    final sinR = sin(_rotation);
    return Offset(
      (screenDelta.dx * cosR + screenDelta.dy * sinR) / _scale,
      (-screenDelta.dx * sinR + screenDelta.dy * cosR) / _scale,
    );
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
                    onColorSelected: (color) {
                      _controller.setActiveColor(color);
                      // Si hay selección activa, aplicar color
                      if (_selectionMode != SelectionMode.ninguno &&
                          _controller.hasSelection) {
                        _controller.colorSelected(color);
                      }
                    },
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

            // Action bar de selección
            if (_selectionMode != SelectionMode.ninguno &&
                (_controller.hasSelection || _controller.hasClipboard) &&
                !_isFullscreen)
              Positioned(
                bottom: 60,
                left: _sideBarWidth + 8,
                right: 8,
                child: _buildSelectionActionBar(),
              ),

            // Control bar de imagen seleccionada
            if (_selectedImageId != null && !_isFullscreen)
              Positioned(
                bottom: 60,
                left: _sideBarWidth + 8,
                right: 8,
                child: _buildImageControlBar(),
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
              _btn(Icons.add_photo_alternate_outlined,
                  onTap: _showImportImageSheet),
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
      builder: (ctx) => Column(
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
          _buildSettingRow(Icons.invert_colors,
              'Invertir selección',
              'Selecciona lo no seleccionado', () {
            Navigator.pop(ctx);
            _invertSelection();
          }),
          _buildSettingRow(Icons.expand_outlined, 'Expandir',
              'Amplía el área seleccionada', () {
            Navigator.pop(ctx);
            _expandSelection(50.0);
          }),
          _buildSettingRow(Icons.compress, 'Contraer',
              'Reduce el área seleccionada', () {
            Navigator.pop(ctx);
            _expandSelection(-50.0);
          }),
          _buildSettingRow(
              Icons.content_copy_outlined,
              'Copiar selección',
              'Copia el área seleccionada', () {
            Navigator.pop(ctx);
            _controller.copySelected();
          }),
          _buildSettingRow(Icons.cut_outlined,
              'Cortar selección',
              'Corta el área seleccionada', () {
            Navigator.pop(ctx);
            _controller.cutSelected();
            setState(() => _clearSelectionState());
          }),
          _buildSettingRow(Icons.delete_outline,
              'Limpiar selección',
              'Elimina el contenido seleccionado', () {
            Navigator.pop(ctx);
            _controller.deleteSelected();
            setState(() => _clearSelectionState());
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _invertSelection() {
    final layerIdx = _controller.layers
        .indexWhere((l) => l.id == _controller.activeLayerId);
    if (layerIdx == -1) return;
    final total = _controller.layers[layerIdx].strokes.length;
    final currentSet =
        Set<int>.from(_controller.selectedStrokeIndices);
    final inverted = [
      for (int i = 0; i < total; i++)
        if (!currentSet.contains(i)) i
    ];
    setState(() {
      _controller.selectedStrokeIndices = inverted;
      _controller.notifyListeners();
    });
  }

  void _expandSelection(double delta) {
    if (_finalizedStart == null || _finalizedEnd == null) return;
    final rect = Rect.fromPoints(_finalizedStart!, _finalizedEnd!);
    final expanded = rect.inflate(delta / _scale);
    setState(() {
      _finalizedStart = expanded.topLeft;
      _finalizedEnd = expanded.bottomRight;
    });
    if (_finalizedMode == SelectionMode.rectangular) {
      _controller.selectStrokesInRect(expanded);
    } else if (_finalizedMode == SelectionMode.elipse) {
      _controller.selectStrokesInEllipse(expanded);
    }
  }

  Widget _buildSettingRow(
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
  void _finalizeSelection() {
    final start = _selectionDragStart;
    final current = _selectionDragCurrent;
    switch (_selectionMode) {
      case SelectionMode.rectangular:
        if (start != null && current != null) {
          _controller.selectStrokesInRect(
              Rect.fromPoints(start, current));
          _finalizedMode = SelectionMode.rectangular;
          _finalizedStart = start;
          _finalizedEnd = current;
        }
        break;
      case SelectionMode.elipse:
        if (start != null && current != null) {
          _controller.selectStrokesInEllipse(
              Rect.fromPoints(start, current));
          _finalizedMode = SelectionMode.elipse;
          _finalizedStart = start;
          _finalizedEnd = current;
        }
        break;
      case SelectionMode.libre:
        if (_selectionPoints.length >= 3) {
          final path = Path()
            ..addPolygon(_selectionPoints, true);
          _controller.selectStrokesInPath(path);
          _finalizedMode = SelectionMode.libre;
          _finalizedSelectionPoints = List.from(_selectionPoints);
        }
        break;
      case SelectionMode.automatico:
        if (start != null) {
          _controller.selectStrokesNear(start, 80.0 / _scale);
          _finalizedMode = SelectionMode.automatico;
          _finalizedStart = start;
          _finalizedEnd = start;
        }
        break;
      default:
        break;
    }
    setState(() {
      _selectionPoints = [];
      _selectionDragStart = null;
      _selectionDragCurrent = null;
    });
  }

  void _clearSelectionState() {
    _controller.clearSelection();
    _finalizedMode = SelectionMode.ninguno;
    _finalizedStart = null;
    _finalizedEnd = null;
    _finalizedSelectionPoints = [];
    _selectionPoints = [];
    _selectionDragStart = null;
    _selectionDragCurrent = null;
    _selectionAngle = 0.0;
  }

  Widget _buildCanvas() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showBrushPanel) setState(() => _showBrushPanel = false);
          if (_showSelectionOptions) setState(() => _showSelectionOptions = false);
          if (_showColors) setState(() => _showColors = false);

          final tapPoint = _screenToCanvas(
            // onTap no tiene detalles de posición — usamos el centro de pantalla como fallback
            // En su lugar manejamos selección en onScaleStart con tap rápido
            Offset.zero,
          );

          if (_selectedImageId != null) {
            setState(() {
              _controller.selectCanvasImage(null);
              _selectedImageId = null;
            });
            return;
          }
          if (_selectionMode != SelectionMode.ninguno) {
            setState(() => _clearSelectionState());
          }
        },
        onScaleStart: (details) {
          // ── PRIORIDAD ABSOLUTA: 2 dedos = pan/zoom ───────
          if (details.pointerCount >= 2 || _zoomMode) {
            _controller.endStroke();
            _isDraggingImage = false;
            _isDraggingSelection = false;
            _isResizingHandle = false;
            _isResizingImage = false;
            _erasingImageId = null;
            _isScaling = true;
            _startScale = _scale;
            _startOffset = _offset;
            _startFocalPoint = details.localFocalPoint;
            _startRotation = _rotation;
            // Punto canvas bajo el focal (usa matriz completa con rotación)
            _canvasFocalPoint = _screenToCanvasWithTransform(
              _startFocalPoint, _startOffset, _startRotation, _startScale);
            return;
          }

          if (_showBrushPanel) _showBrushPanel = false;
          if (_showSelectionOptions) _showSelectionOptions = false;
          _isScaling = false;
          final cp = _screenToCanvas(details.localFocalPoint);

          // ── Imagen YA seleccionada: handles o drag ────────
          if (_selectedImageId != null &&
              _selectionMode == SelectionMode.ninguno) {
            final selImg = _controller.canvasImages
                .where((i) => i.id == _selectedImageId)
                .firstOrNull;
            if (selImg != null) {
              // Usar posiciones de handles en mundo rotado (desde el painter)
              // Hit area GRANDE (invisible) para fácil toque con el dedo
              final handles = _imageHandlesWorld(selImg);
              final hitRadius = 36.0 / _scale; // hit area grande, visual sigue siendo 10px
              for (int i = 0; i < handles.length; i++) {
                if ((handles[i] - cp).distance < hitRadius) {
                  if (i == 4) {
                    // Handle de ROTACIÓN
                    _isRotatingImage = true;
                    _imageRotationCenter = selImg.center;
                    _imageRotationStartAngle =
                        (cp - selImg.center).direction - selImg.rotation;
                    _activeImageHandle = 4;
                  } else {
                    _isResizingImage = true;
                    _activeImageHandle = i;
                    _lastResizeCanvas = cp;
                  }
                  return;
                }
              }
              // Hit area de drag: dentro de la imagen (con rotación)
              final relCp = _rotatePointAround(cp, selImg.center, -selImg.rotation);
              if (selImg.rect.inflate(10 / _scale).contains(relCp)) {
                _isDraggingImage = true;
                _lastDragCanvas = cp;
                return;
              }
            }
            _controller.selectCanvasImage(null);
            _selectedImageId = null;
            setState(() {});
          }

          // ── Transform mode: tap en imagen = seleccionar ──
          if (_selectedImageId == null &&
              _selectionMode == SelectionMode.ninguno &&
              _transformMode == TransformMode.activo) {
            final img = _controller.imageAtPoint(cp);
            if (img != null) {
              _controller.selectCanvasImage(img.id);
              setState(() => _selectedImageId = img.id);
              return;
            }
          }

          // ── Handles de selección (con rotación) ──────────
          if (_selectionMode != SelectionMode.ninguno &&
              _controller.hasSelection) {
            final rawBounds = _controller.selectionBounds;
            final bounds = rawBounds?.inflate(10);
            if (bounds != null && rawBounds != null) {
              final bCenter = bounds.center;
              // Rotar el punto de toque inversamente para comparar en espacio local
              final cpLocal = _rotatePointAround(cp, bCenter, -_selectionAngle);

              // Handle de rotación (rojo)
              final rotHandle = bounds.topCenter - const Offset(0, 36);
              if ((rotHandle - cpLocal).distance < 20.0 / _scale) {
                _controller.saveSelectionMoveToHistory();
                _isResizingHandle = true;
                _activeResizeHandle = 8;
                _resizeStartBounds = rawBounds;
                _resizeHandleStart = cp;
                _selectionStartRotation = (cp - bCenter).direction;
                return;
              }
              // 8 handles de resize — hit area 20px en espacio local
              final handles = [
                bounds.topLeft,
                bounds.topCenter,
                bounds.topRight,
                Offset(bounds.left, bounds.center.dy),
                Offset(bounds.right, bounds.center.dy),
                bounds.bottomLeft,
                bounds.bottomCenter,
                bounds.bottomRight,
              ];
              final hitRadius = 20.0 / _scale;
              for (int i = 0; i < handles.length; i++) {
                if ((handles[i] - cpLocal).distance < hitRadius) {
                  _controller.saveSelectionMoveToHistory();
                  _isResizingHandle = true;
                  _activeResizeHandle = i;
                  _resizeStartBounds = rawBounds;
                  _resizeHandleStart = cp;
                  return;
                }
              }
            }
          }

          // ── Modo selección ───────────────────────────────
          if (_selectionMode != SelectionMode.ninguno) {
            final bounds = _controller.selectionBounds;
            if (bounds != null && _controller.hasSelection) {
              // Rotar punto inversamente para detectar si está dentro
              final cpLocal = _rotatePointAround(cp, bounds.center, -_selectionAngle);
              if (bounds.inflate(40 / _scale).contains(cpLocal)) {
                _controller.saveSelectionMoveToHistory();
                _isDraggingSelection = true;
                _selectionMoveStart = cp;
                return;
              }
            }
            _controller.clearSelection();
            _isDraggingSelection = false;
            _isResizingHandle = false;
            _selectionPoints = [cp];
            _selectionDragStart = cp;
            _selectionDragCurrent = cp;
            _finalizedMode = SelectionMode.ninguno;
            return;
          }

          // ── Dibujo / Borrador ────────────────────────────
          // El borrador borra strokes E imágenes de la capa activa
          // gracias al saveLayer+BlendMode.clear en el painter
          _controller.startStroke(cp);
        },
        onScaleUpdate: (details) {
          // ── PRIORIDAD: 2 dedos siempre pan/zoom ──────────
          if (details.pointerCount >= 2) {
            if (!_isScaling) {
              _controller.endStroke();
              _isDraggingImage = false;
              _isDraggingSelection = false;
              _isResizingHandle = false;
              _isResizingImage = false;
              _isScaling = true;
              _startScale = _scale;
              _startOffset = _offset;
              _startFocalPoint = details.localFocalPoint;
              _startRotation = _rotation;
              _canvasFocalPoint = _screenToCanvasWithTransform(
                _startFocalPoint, _startOffset, _startRotation, _startScale);
              return;
            }

            // ── 2 dedos sobre imagen seleccionada: rotar imagen ──
            if (_selectedImageId != null && !_isScaling) {
              // Si acaba de empezar el gesto de 2 dedos sobre imagen → rotar imagen
              final imgList = _controller.canvasImages
                  .where((i) => i.id == _selectedImageId);
              if (imgList.isNotEmpty) {
                final img = imgList.first;
                final relFocal = _screenToCanvasWithTransform(
                    _startFocalPoint, _startOffset, _startRotation, _startScale);
                if (img.rect.inflate(20 / _startScale).contains(
                    _rotatePointAround(relFocal, img.center, -img.rotation))) {
                  // Rotar imagen con 2 dedos en lugar de pan/zoom del canvas
                  final newImgRot = img.rotation + details.rotation;
                  _controller.setCanvasImageRotation(_selectedImageId!, newImgRot);
                  // También escalar imagen con pinch
                  if (details.scale != 1.0) {
                    final newW = (img.size.width * details.scale).clamp(20.0, _controller.canvasSize.width);
                    final newH = (img.size.height * details.scale).clamp(20.0, _controller.canvasSize.height);
                    final newPos = Offset(
                      img.center.dx - newW / 2,
                      img.center.dy - newH / 2,
                    );
                    _controller.setCanvasImageRect(_selectedImageId!,
                        Rect.fromLTWH(newPos.dx, newPos.dy, newW, newH));
                  }
                  return;
                }
              }
            }

            // ── Fórmula correcta pan/zoom CON ROTACIÓN ──────
            // El punto canvas bajo los dedos siempre se queda fijo
            // Funciona correctamente aunque el lienzo esté rotado
            final newScale = (_startScale * details.scale).clamp(0.1, 10.0);
            final newRotation = _startRotation + details.rotation;
            // newOffset = screenFocal - R(newRotation) * S(newScale) * canvasFocal
            final cosR = cos(newRotation);
            final sinR = sin(newRotation);
            final cfx = _canvasFocalPoint.dx;
            final cfy = _canvasFocalPoint.dy;
            final newOffset = Offset(
              details.localFocalPoint.dx - (cfx * cosR - cfy * sinR) * newScale,
              details.localFocalPoint.dy - (cfx * sinR + cfy * cosR) * newScale,
            );
            setState(() {
              _scale = newScale;
              _offset = newOffset;
              _rotation = newRotation;
            });
            return;
          }

          if (_isScaling && _zoomMode) {
            // Zoom mode 1 dedo: solo pan
            final cosR = cos(_rotation);
            final sinR = sin(_rotation);
            final cfx = _canvasFocalPoint.dx;
            final cfy = _canvasFocalPoint.dy;
            final newOffset = Offset(
              details.localFocalPoint.dx - (cfx * cosR - cfy * sinR) * _scale,
              details.localFocalPoint.dy - (cfx * sinR + cfy * cosR) * _scale,
            );
            setState(() => _offset = newOffset);
            return;
          }

          if (_showBrushPanel || _showSelectionOptions) return;

          final cp = _screenToCanvas(details.localFocalPoint);

          // ── Rotar imagen ──────────────────────────────────
          if (_isRotatingImage && _imageRotationCenter != null && _selectedImageId != null) {
            final angle = (cp - _imageRotationCenter!).direction;
            final newRotation = angle - _imageRotationStartAngle;
            _controller.setCanvasImageRotation(_selectedImageId!, newRotation);
            return;
          }

          // ── Mover imagen ──────────────────────────────────
          if (_isDraggingImage && _lastDragCanvas != null && _selectedImageId != null) {
            final delta = cp - _lastDragCanvas!;
            _lastDragCanvas = cp;
            final img = _controller.canvasImages
                .where((i) => i.id == _selectedImageId).firstOrNull;
            if (img != null) {
              _controller.setCanvasImagePosition(
                  _selectedImageId!, img.position + delta);
            }
            return;
          }

          // ── Resize de imagen ─────────────────────────────
          if (_isResizingImage && _lastResizeCanvas != null && _selectedImageId != null) {
            final worldDelta = cp - _lastResizeCanvas!;
            _lastResizeCanvas = cp;
            final imgList = _controller.canvasImages.where((i) => i.id == _selectedImageId);
            if (imgList.isNotEmpty) {
              final img = imgList.first;
              // FIX: rotar delta al espacio local de la imagen (fix distorsion en rotadas)
              final r = -img.rotation;
              final localDelta = img.rotation == 0.0 ? worldDelta : Offset(
                worldDelta.dx * cos(r) - worldDelta.dy * sin(r),
                worldDelta.dx * sin(r) + worldDelta.dy * cos(r),
              );
              final cur = img.rect;
              Rect newRect;
              switch (_activeImageHandle) {
                case 0: newRect = Rect.fromLTRB(cur.left + localDelta.dx, cur.top + localDelta.dy, cur.right, cur.bottom); break;
                case 1: newRect = Rect.fromLTRB(cur.left, cur.top + localDelta.dy, cur.right + localDelta.dx, cur.bottom); break;
                case 2: newRect = Rect.fromLTRB(cur.left + localDelta.dx, cur.top, cur.right, cur.bottom + localDelta.dy); break;
                default: newRect = Rect.fromLTRB(cur.left, cur.top, cur.right + localDelta.dx, cur.bottom + localDelta.dy); break;
              }
              if (newRect.width > 20 && newRect.height > 20) {
                _controller.setCanvasImageRect(_selectedImageId!, newRect);
              }
            }
            return;
          }

          // ── Resize handle de selección ────────────────────
          if (_isResizingHandle && _resizeStartBounds != null && _resizeHandleStart != null) {
            // Handle 8 = rotación visual (no destructiva)
            // Solo actualizamos _selectionAngle para la vista.
            // Los puntos se rotan geométricamente al soltar (onScaleEnd).
            if (_activeResizeHandle == 8) {
              final center = _resizeStartBounds!.center;
              final angle = (cp - center).direction;
              final delta = angle - _selectionStartRotation;
              _selectionStartRotation = angle;
              _selectionAngle += delta;
              setState(() {});
              return;
            }

            final startBounds = _resizeStartBounds!;
            final worldDelta = cp - _resizeHandleStart!;

            // ⚠️ FIX: rotar el delta al espacio local de la selección
            // Si la selección está rotada, el delta mundo no corresponde
            // al eje de las bounds → strokes se encogen incorrectamente
            final localDelta = _selectionAngle == 0.0
                ? worldDelta
                : Offset(
                    worldDelta.dx * cos(-_selectionAngle) -
                        worldDelta.dy * sin(-_selectionAngle),
                    worldDelta.dx * sin(-_selectionAngle) +
                        worldDelta.dy * cos(-_selectionAngle),
                  );

            Rect newBounds;
            switch (_activeResizeHandle) {
              case 0: newBounds = Rect.fromLTRB(startBounds.left + localDelta.dx, startBounds.top + localDelta.dy, startBounds.right, startBounds.bottom); break; // TL
              case 1: newBounds = Rect.fromLTRB(startBounds.left, startBounds.top + localDelta.dy, startBounds.right, startBounds.bottom); break; // TC
              case 2: newBounds = Rect.fromLTRB(startBounds.left, startBounds.top + localDelta.dy, startBounds.right + localDelta.dx, startBounds.bottom); break; // TR
              case 3: newBounds = Rect.fromLTRB(startBounds.left + localDelta.dx, startBounds.top, startBounds.right, startBounds.bottom); break; // ML
              case 4: newBounds = Rect.fromLTRB(startBounds.left, startBounds.top, startBounds.right + localDelta.dx, startBounds.bottom); break; // MR
              case 5: newBounds = Rect.fromLTRB(startBounds.left + localDelta.dx, startBounds.top, startBounds.right, startBounds.bottom + localDelta.dy); break; // BL
              case 6: newBounds = Rect.fromLTRB(startBounds.left, startBounds.top, startBounds.right, startBounds.bottom + localDelta.dy); break; // BC
              default: newBounds = Rect.fromLTRB(startBounds.left, startBounds.top, startBounds.right + localDelta.dx, startBounds.bottom + localDelta.dy); break; // BR
            }

            if (newBounds.width > 5 && newBounds.height > 5) {
              final scaleX = newBounds.width / startBounds.width;
              final scaleY = newBounds.height / startBounds.height;
              // Escalar alrededor del centro rotado para no desplazar
              final center = _rotatePointAround(
                  startBounds.center, startBounds.center, _selectionAngle);
              _controller.scaleSelectedStrokes(center, scaleX, scaleY);
              _resizeStartBounds = _controller.selectionBounds;
              _resizeHandleStart = cp;
            }
            return;
          }

          // ── Modo selección ────────────────────────────────
          if (_selectionMode != SelectionMode.ninguno) {
            if (_isDraggingSelection && _selectionMoveStart != null) {
              final delta = cp - _selectionMoveStart!;
              _controller.moveSelected(delta);
              _selectionMoveStart = cp;
            } else {
              setState(() {
                _selectionDragCurrent = cp;
                if (_selectionMode == SelectionMode.libre) {
                  _selectionPoints.add(cp);
                }
              });
            }
            return;
          }

          // ── Continuar stroke / borrador ──────────────────
          _controller.continueStroke(cp);
        },
        onScaleEnd: (details) {
          if (_isScaling) { _isScaling = false; return; }
          if (_isDraggingImage) {
            _isDraggingImage = false;
            _lastDragCanvas = null;
            return;
          }
          if (_isRotatingImage) {
            _isRotatingImage = false;
            _imageRotationCenter = null;
            _activeImageHandle = -1;
            return;
          }
          if (_isResizingImage) {
            _isResizingImage = false;
            _activeImageHandle = -1;
            _lastResizeCanvas = null;
            return;
          }
          if (_isResizingHandle) {
            // Handle 8 = rotación: al soltar, aplicar la rotación total a los puntos
            if (_activeResizeHandle == 8 &&
                _resizeStartBounds != null &&
                _selectionAngle != 0.0) {
              _controller.saveSelectionMoveToHistory();
              _controller.rotateSelected(
                _resizeStartBounds!.center,
                _selectionAngle,
              );
              _selectionAngle = 0.0; // reset visual tras aplicar
            }
            setState(() {
              _isResizingHandle = false;
              _activeResizeHandle = -1;
              _resizeStartBounds = null;
              _resizeHandleStart = null;
            });
            return;
          }
          if (_selectionMode != SelectionMode.ninguno) {
            if (_isDraggingSelection) {
              setState(() { _isDraggingSelection = false; _selectionMoveStart = null; });
            } else {
              _finalizeSelection();
            }
          } else {
            _controller.endStroke();
          }
          _isScaling = false;
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.identity()
                ..translate(_offset.dx, _offset.dy)
                ..rotateZ(_rotation)
                ..scale(_scale),
              child: Stack(
                children: [
                  CustomPaint(
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
                      controller: _controller,
                      backgroundColor:
                          _controller.backgroundColor,
                    ),
                    size: Size(
                      _controller.canvasSize.width,
                      _controller.canvasSize.height,
                    ),
                  ),
                  // Overlay de selección
                  if (_selectionMode != SelectionMode.ninguno)
                    CustomPaint(
                      painter: _SelectionOverlayPainter(
                        mode: _selectionMode,
                        points: _selectionPoints.isNotEmpty
                            ? _selectionPoints
                            : _finalizedSelectionPoints,
                        dragStart: _selectionDragStart ?? _finalizedStart,
                        dragCurrent: _selectionDragCurrent ?? _finalizedEnd,
                        selectedBounds: _controller.selectionBounds,
                        selectedIndices:
                            _controller.selectedStrokeIndices,
                        finalizedMode: _finalizedMode,
                        selectionAngle: _selectionAngle,
                      ),
                      size: Size(
                        _controller.canvasSize.width,
                        _controller.canvasSize.height,
                      ),
                    ),
                ],
              ),
            );
          },
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
        final cW = _controller.canvasSize.width;
        final cH = _controller.canvasSize.height;
        final screen = MediaQuery.of(context).size;
        final aW = screen.width - _sideBarWidth;
        final aH = screen.height - _topBarHeight;
        final scaleX = aW / cW;
        final scaleY = aH / cH;
        _scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;
        _offset = Offset(
          _sideBarWidth + (aW - cW * _scale) / 2,
          _topBarHeight + (aH - cH * _scale) / 2,
        );
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

  // Conversiones a/desde px a 300 DPI
  static const double _dpi = 300.0;
  static const Map<String, double> _unitToPx = {
    'px':   1.0,
    'mm':   _dpi / 25.4,
    'cm':   _dpi / 2.54,
    'inch': _dpi,
  };

  double _pxToUnit(double px, String unit) =>
      px / (_unitToPx[unit] ?? 1.0);

  double _unitToPxValue(double val, String unit) =>
      val * (_unitToPx[unit] ?? 1.0);

  String _formatUnitValue(double val, String unit) {
    if (unit == 'px') return val.round().toString();
    return val.toStringAsFixed(2);
  }

  void _showResizeCanvasDialog() {
    String selectedUnit = 'px';

    final wPx = _controller.canvasSize.width;
    final hPx = _controller.canvasSize.height;

    final wController = TextEditingController(
        text: _formatUnitValue(_pxToUnit(wPx, selectedUnit), selectedUnit));
    final hController = TextEditingController(
        text: _formatUnitValue(_pxToUnit(hPx, selectedUnit), selectedUnit));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          void changeUnit(String newUnit) {
            final wVal = double.tryParse(wController.text) ?? 0;
            final hVal = double.tryParse(hController.text) ?? 0;
            // Convertir valores actuales a px y luego a nueva unidad
            final wInPx = _unitToPxValue(wVal, selectedUnit);
            final hInPx = _unitToPxValue(hVal, selectedUnit);
            setStateDialog(() {
              selectedUnit = newUnit;
              wController.text = _formatUnitValue(_pxToUnit(wInPx, newUnit), newUnit);
              hController.text = _formatUnitValue(_pxToUnit(hInPx, newUnit), newUnit);
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF2C2C2E),
            title: const Text('Cambiar tamaño',
                style: TextStyle(
                    fontFamily: 'BlackOpsOne',
                    color: Colors.white,
                    fontSize: 15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector de unidad
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['px', 'mm', 'cm', 'inch'].map((unit) {
                    final isSelected = unit == selectedUnit;
                    return GestureDetector(
                      onTap: () => changeUnit(unit),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentRed
                              : const Color(0xFF3A3A3C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accentRed
                                : const Color(0xFF48484A),
                          ),
                        ),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF8E8E93),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: wController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontFamily: 'Raleway', color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ancho ($selectedUnit)',
                    labelStyle: const TextStyle(
                        fontFamily: 'Raleway',
                        color: Color(0xFF8E8E93)),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF48484A)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontFamily: 'Raleway', color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Alto ($selectedUnit)',
                    labelStyle: const TextStyle(
                        fontFamily: 'Raleway',
                        color: Color(0xFF8E8E93)),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF48484A)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '300 DPI',
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Color(0xFF8E8E93))),
              ),
              TextButton(
                onPressed: () {
                  final wVal = double.tryParse(wController.text);
                  final hVal = double.tryParse(hController.text);
                  if (wVal != null && hVal != null && wVal > 0 && hVal > 0) {
                    final w = _unitToPxValue(wVal, selectedUnit);
                    final h = _unitToPxValue(hVal, selectedUnit);
                    setState(() {
                      _controller.updateCanvasSize(Size(w, h));
                      _controller.invalidateAllCache();
                      final screen = MediaQuery.of(context).size;
                      final aW2 = screen.width - _sideBarWidth;
                      final aH2 = screen.height - _topBarHeight;
                      final scaleX = aW2 / w;
                      final scaleY = aH2 / h;
                      _scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;
                      _offset = Offset(
                        _sideBarWidth + (aW2 - w * _scale) / 2,
                        _topBarHeight + (aH2 - h * _scale) / 2,
                      );
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
          );
        },
      ),
    );
  }

  // ─── IMPORTAR IMAGEN ─────────────────────────────────────

  void _showImportImageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('AGREGAR IMAGEN',
              style: TextStyle(
                  fontFamily: 'BlackOpsOne',
                  fontSize: 13,
                  color: _textPrimary,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _importOption(
            icon: Icons.photo_library_outlined,
            title: 'Galería del celular',
            subtitle: 'Importa una foto o imagen guardada',
            onTap: () {
              Navigator.pop(ctx);
              _importFromGallery();
            },
          ),
          _importOption(
            icon: Icons.palette_outlined,
            title: 'Diseños de la app',
            subtitle: 'Usa un diseño creado en Three Skulls',
            onTap: () {
              Navigator.pop(ctx);
              // TODO: navegar a galería de diseños
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _cardColor,
                  content: const Text('Próximamente',
                      style: TextStyle(fontFamily: 'Raleway', color: Colors.white)),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          _importOption(
            icon: Icons.auto_awesome_outlined,
            title: 'Imagen de IA',
            subtitle: 'Genera una imagen con inteligencia artificial',
            onTap: () {
              Navigator.pop(ctx);
              // TODO: navegar a pantalla de IA
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _cardColor,
                  content: const Text('Próximamente',
                      style: TextStyle(fontFamily: 'Raleway', color: Colors.white)),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _importOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: _borderColor.withOpacity(0.4), width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
              ),
              child: Icon(icon, color: AppTheme.accentRed, size: 22),
            ),
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
            Icon(Icons.chevron_right, color: _textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _loadImageFile(picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _cardColor,
            content: Text('Error al importar: $e',
                style: const TextStyle(
                    fontFamily: 'Raleway', color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  dynamic _getImagePicker() => null; // obsoleto, no usar

  Future<void> _loadImageFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (mounted) {
      _controller.addCanvasImage(image);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardColor,
          content: const Row(children: [
            Text('🖼️', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Text('Imagen agregada al canvas',
                style: TextStyle(
                    fontFamily: 'Raleway', color: Colors.white)),
          ]),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Handles de imagen en coordenadas mundo (respeta rotación)
  List<Offset> _imageHandlesWorld(CanvasImageModel img) {
    final cx = img.center.dx;
    final cy = img.center.dy;
    final cosR = cos(img.rotation);
    final sinR = sin(img.rotation);

    Offset rot(Offset p) {
      final dx = p.dx - cx;
      final dy = p.dy - cy;
      return Offset(cx + dx * cosR - dy * sinR, cy + dx * sinR + dy * cosR);
    }

    return [
      rot(img.rect.topLeft),      // 0 TL
      rot(img.rect.topRight),     // 1 TR
      rot(img.rect.bottomLeft),   // 2 BL
      rot(img.rect.bottomRight),  // 3 BR
      rot(img.rect.topCenter - const Offset(0, 36)), // 4 ROT
    ];
  }

  /// Rota un punto alrededor de un centro
  Offset _rotatePointAround(Offset point, Offset center, double angle) {
    final cosA = cos(angle);
    final sinA = sin(angle);
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    return Offset(
      center.dx + dx * cosA - dy * sinA,
      center.dy + dx * sinA + dy * cosA,
    );
  }

  /// Retorna las 4 esquinas + handle rotación de la imagen en coords mundo
  List<Offset> _imageHandlePositions(Rect rect) => [
    rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight,
  ];

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

  Widget _buildSelectionActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _panelColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _selectionAction(Icons.content_cut, 'Cortar', () {
            _controller.cutSelected();
            setState(() {});
          }),
          _selectionAction(Icons.content_copy, 'Copiar', () {
            _controller.copySelected();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: _cardColor,
                content: const Text('Copiado',
                    style: TextStyle(
                        fontFamily: 'Raleway', color: Colors.white)),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }),
          _selectionAction(Icons.content_paste, 'Pegar', () {
            _controller.paste();
            setState(() {});
          }, enabled: _controller.hasClipboard),
          _selectionAction(Icons.delete_outline, 'Borrar', () {
            _controller.deleteSelected();
            setState(() {});
          }, isDestructive: true),
          _selectionAction(Icons.color_lens_outlined, 'Color', () {
            setState(() => _showColors = !_showColors);
          }, isActive: _showColors),
          _selectionAction(Icons.deselect, 'Desel.', () {
            setState(() => _clearSelectionState());
          }),
        ],
      ),
    );
  }

  Widget _selectionAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool enabled = true,
    bool isDestructive = false,
    bool isActive = false,
  }) {
    final color = !enabled
        ? _textSecondary.withOpacity(0.3)
        : isDestructive
            ? AppTheme.accentRed
            : isActive
                ? AppTheme.accentRed
                : _textPrimary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 9,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageControlBar() {
    final imgId = _selectedImageId;
    if (imgId == null) return const SizedBox.shrink();

    // AnimatedBuilder para que el bar se actualice cuando cambia el controller
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final imgList = _controller.canvasImages.where((i) => i.id == imgId);
        if (imgList.isEmpty) return const SizedBox.shrink();
        final img = imgList.first;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _panelColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8, offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Ajustar: centra y escala al 60% del canvas
                  _selectionAction(Icons.zoom_out_map, 'Ajustar', () {
                    final cs = _controller.canvasSize;
                    final ar = img.image.width / img.image.height;
                    final w = cs.width * 0.6;
                    final h = w / ar;
                    _controller.setCanvasImageRect(imgId,
                      Rect.fromLTWH((cs.width - w) / 2, (cs.height - h) / 2, w, h));
                  }),
                  // Deshacer último borrado
                  _selectionAction(Icons.undo, 'Deshacer', () {
                    _controller.undoLastEraseOnImage(imgId);
                  }, enabled: img.eraseStrokes.isNotEmpty),
                  // Restaurar imagen original
                  _selectionAction(Icons.history, 'Restaurar', () {
                    _controller.clearErasesOnImage(imgId);
                  }, enabled: img.hasErases),
                  // Voltear horizontal
                  _selectionAction(Icons.flip, 'Voltear H', () {
                    _controller.toggleFlipX(imgId);
                  }, isActive: img.flipX),
                  // Voltear vertical
                  _selectionAction(Icons.flip_camera_android, 'Voltear V', () {
                    _controller.toggleFlipY(imgId);
                  }, isActive: img.flipY),
                  // Eliminar
                  _selectionAction(Icons.delete_outline, 'Eliminar', () {
                    _controller.removeCanvasImage(imgId);
                    setState(() => _selectedImageId = null);
                  }, isDestructive: true),
                  // Listo
                  _selectionAction(Icons.check, 'Listo', () {
                    _controller.selectCanvasImage(null);
                    setState(() => _selectedImageId = null);
                  }),
                ],
              ),
              const SizedBox(height: 8),
              // Slider de opacidad
              Row(
                children: [
                  const Text('OPA',
                      style: TextStyle(fontFamily: 'Raleway', fontSize: 9,
                          color: Color(0xFF8E8E93))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.accentRed,
                        inactiveTrackColor: _borderColor,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: img.opacity.clamp(0.1, 1.0),
                        min: 0.1, max: 1.0,
                        onChanged: (v) {
                          img.opacity = v;
                          _controller.notifyListeners();
                        },
                      ),
                    ),
                  ),
                  Text('${(img.opacity * 100).round()}%',
                      style: const TextStyle(fontFamily: 'Raleway',
                          fontSize: 10, color: Colors.white)),
                ],
              ),
            ],
          ),
        );
      },
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
        ..color = this.color
        ..strokeWidth = this.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

    if (this.isDotwork){
      paint.style = PaintingStyle.fill;
      double x = 2;
      while (x < size.width - 2) {
        canvas.drawCircle(
          Offset(x, size.height / 2),
          this.strokeWidth / 2,
          paint,
        );
        x += this.strokeWidth * 2.5;
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

// ─── SELECTION OVERLAY PAINTER ───────────────────────────────
class _SelectionOverlayPainter extends CustomPainter {
  final SelectionMode mode;
  final List<Offset> points;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final Rect? selectedBounds;
  final List<int> selectedIndices;
  final SelectionMode finalizedMode;
  final double selectionAngle;

  _SelectionOverlayPainter({
    required this.mode,
    required this.points,
    required this.dragStart,
    required this.dragCurrent,
    required this.selectedBounds,
    required this.selectedIndices,
    required this.finalizedMode,
    this.selectionAngle = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0x334A90E2)
      ..style = PaintingStyle.fill;

    // Puntos azules con borde blanco para mayor visibilidad
    final dashPaint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Dibujar forma en progreso
    if (dragStart != null && dragCurrent != null) {
      final rect = Rect.fromPoints(dragStart!, dragCurrent!);
      switch (mode) {
        case SelectionMode.rectangular:
          canvas.drawRect(rect, fillPaint);
          _drawDashedRect(canvas, rect, strokePaint);
          break;
        case SelectionMode.elipse:
          canvas.drawOval(rect, fillPaint);
          _drawDashedOval(canvas, rect, strokePaint);
          break;
        case SelectionMode.libre:
          if (points.length >= 2) {
            final path = Path()..addPolygon(points, false);
            canvas.drawPath(path, fillPaint);
            canvas.drawPath(path, strokePaint);
          }
          break;
        case SelectionMode.automatico:
          canvas.drawCircle(dragStart!, 80, fillPaint);
          canvas.drawCircle(dragStart!, 80, strokePaint);
          break;
        default:
          break;
      }
    }

    // Dibujar bounding box de selección finalizada (ROTADO)
    if (selectedBounds != null && selectedIndices.isNotEmpty) {
      final bounds = selectedBounds!.inflate(10);
      final cx = bounds.center.dx;
      final cy = bounds.center.dy;

      // Aplicar rotación del bounding box
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(selectionAngle);
      canvas.translate(-cx, -cy);

      _drawDashedRect(canvas, bounds, dashPaint);

      final handlePaint = Paint()
        ..color = const Color(0xFF4A90E2)
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // 8 handles — visual 8px, hit area manejado en screen (36px)
      const hr = 8.0;
      final handles = [
        bounds.topLeft,
        bounds.topCenter,
        bounds.topRight,
        Offset(bounds.left, bounds.center.dy),
        Offset(bounds.right, bounds.center.dy),
        bounds.bottomLeft,
        bounds.bottomCenter,
        bounds.bottomRight,
      ];
      for (final h in handles) {
        canvas.drawCircle(h, hr, handlePaint);
        canvas.drawCircle(h, hr, handleBorder);
      }

      // Handle de rotación (rojo, arriba del centro)
      final rotHandle = bounds.topCenter - const Offset(0, 36);
      canvas.drawLine(bounds.topCenter, rotHandle,
          Paint()..color = Colors.white..strokeWidth = 1.5);
      canvas.drawCircle(rotHandle, 10,
          Paint()..color = const Color(0xFFE74C3C)..style = PaintingStyle.fill);
      canvas.drawCircle(rotHandle, 10, handleBorder);

      canvas.restore();
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDottedPath(canvas, Path()..addRect(rect), paint);
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    _drawDottedPath(canvas, Path()..addOval(rect), paint);
  }

  // Dibuja puntos equidistantes a lo largo de un path
  void _drawDottedPath(Canvas canvas, Path path, Paint basePaint) {
    const dotRadius = 3.0;
    const spacing = 14.0; // espacio entre centros de puntos

    final dotPaint = Paint()
      ..color = basePaint.color
      ..style = PaintingStyle.fill;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist <= metric.length) {
        final tangent = metric.getTangentForOffset(dist);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, dotRadius, dotPaint);
        }
        dist += spacing;
      }
    }
  }

  // Mantener _drawDashedPath para compatibilidad
  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    _drawDottedPath(canvas, path, paint);
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter old) =>
      old.points != points ||
      old.dragStart != dragStart ||
      old.dragCurrent != dragCurrent ||
      old.selectedBounds != selectedBounds ||
      old.selectedIndices != selectedIndices ||
      old.finalizedMode != finalizedMode ||
      old.selectionAngle != selectionAngle;
}
