import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/native_canvas_bridge.dart';
import '../services/gpu_brush_loader.dart';
import '../controllers/canvas_controller.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/layer_panel.dart';
import '../widgets/color_picker.dart';
import '../models/brush_model.dart';
import '../models/canvas_image_model.dart';
import '../models/stroke_model.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../models/stamp_model.dart';
import '../services/device_profile.dart';
import 'background_service_dialog.dart';
import 'package:flutter/services.dart';
import '../widgets/brush_adjust_sheet.dart';
import '../models/tsk_project_model.dart';
import '../services/storage_manager.dart';
import 'dart:convert';
import '../services/tsk_project_service.dart';
import 'package:uuid/uuid.dart';

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

class _CanvasScreenState extends State<CanvasScreen>
    with WidgetsBindingObserver {
  late CanvasController _controller;
  late List<BrushModel> _brushes;
  List<BrushModel> _importedBrushes = [];
  bool _isRefreshingBrushes = false; // pinceles .tskbrush del almacenamiento

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

  // ─── SELLOS ──────────────────────────────────────────────
  StampItem? _activeStamp;
  ui.Image? _activeStampImage;
  StampCategory? _selectedStampCategory;
  double _stampSize = 300.0;
  bool _stampMode = false;

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
  String? _projectId; // null = proyecto nuevo sin guardar
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
  // Contador de updates consecutivos con 1 solo dedo confirmado.
  // beginStroke GPU solo se envía cuando >= 2 updates confirmados → elimina phantoms
  // sin necesidad de capturar/revertir pixels (que es lento).
  int _confirmedSingleUpdates = 0;

  // Auto-save periódico cada 2 minutos
  Timer? _autoSaveTimer;

  // Tracking de espaciado para el espejo del borrador (simetría).
  // Sin esto, stampAt se llama en cada evento táctil → mucho más denso que el trazo principal.
  Offset? _mirrorLastPoint;
  double  _mirrorAccDist = 0.0;
  DateTime? _strokeStartTime; // para detectar dots accidentales al hacer pan
  int _activePointers = 0;
  bool _cancelStrokeImmediately = false;
  bool _isDrawing = false;
  Offset? _pendingStrokePoint;
  final List<Offset> _pendingPoints = [];
  Offset? _tapDownCanvasPos;
  int _lastScaleFrame = 0; // throttle zoom setState

  // ─── BRUSH PREVIEW (ValueNotifier = sin setState) ────
  final _brushPreviewNotifier = ValueNotifier<double?>(null);
  int _previewToken = 0;

  // ─── TOOLTIP ─────────────────────────────────────────────────
  String? _tooltipText;
  Offset _tooltipPosition = Offset.zero;
  DateTime? _tooltipHideAt;

  // ─── AJUSTES DEL CANVAS ──────────────────────────────────────
  bool _showCanvasSettings = false;
  double _panSensitivity = 1.0;       // 0.5 - 2.0
  double _zoomSensitivity = 1.0;      // 0.5 - 2.0
  bool _freeRotation = true;          // rotar canvas con 2 dedos
  bool _showRuler = false;
  String _rulerUnit = 'cm';           // 'cm' | 'mm' | 'inch'
  int _exportDpi = 150;               // 72 | 150 | 300
  double _maxZoom = 10.0;             // zoom máximo permitido
  bool _showCenterGuides = false;     // guías del centro del canvas
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

  // ── NATIVE ENGINE (Offscreen) ────────────────────────────────────
  late NativeCanvasBridge _bridge;
  bool _nativeReady = false;
  // DIAGNOSTIC: últimas coordenadas enviadas al bridge (para debugging posición)
  String _lastBridgeCoords = 'ninguno';
  String _lastGpuStatus = 'sin datos';
  int _eraseExportCounter = 0;  // throttle exports durante trazo
  final Set<int> _trackedPointers = {};  // IDs de punteros activos en canvas
  int _lastExportMs = 0;         // timestamp del último export
  ui.Image? _nativeCanvasImage;
  String _nativeInitError = 'unknown';
  final Map<int, int> _nativeLayerIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // lifecycle observer
    _controller = CanvasController();
    _controller.addListener(_syncLayerOpacities);
    _brushes = BrushModel.defaultBrushes();
    // Cargar pinceles importados del almacenamiento
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImportedBrushes());

    // FIX ORDEN INIT: procesar designParams ANTES de _initNativeEngine para que
    // _controller.canvasSize tenga el valor correcto cuando el motor C++ se inicia.
    // Antes: motor iniciaba con 1080x1920, luego postFrameCallback lo cambiaba a
    // 591x886 (del proyecto), causando mismatch permanente entre GPU y Dart.
    final p = widget.designParams;
    if (p != null) {
      _projectName = p['name'] as String? ?? 'Sin título';
      final bg = p['background'] as String? ?? 'transparente';
      if (bg == 'blanco') {
        _controller.backgroundColor = Colors.white;
      } else if (bg == 'negro') {
        _controller.backgroundColor = Colors.black;
      }
      // FIX: si cualquier dimensión < 1000px, el proyecto tiene valores corruptos
      // (ej: conversión accidental cm→px a 72DPI en lugar de 300DPI).
      // Forzar ambas dimensiones a 1080x1920 en ese caso.
      final wPxRaw = p['widthPx'] as int? ?? 1080;
      final hPxRaw = p['heightPx'] as int? ?? 1920;
      final bool corrupt = wPxRaw < 1000 || hPxRaw < 1000;
      final wPx = corrupt ? 1080 : wPxRaw;
      final hPx = corrupt ? 1920 : hPxRaw;
      _controller.updateCanvasSize(Size(wPx.toDouble(), hPx.toDouble()));
    }

    _initNativeEngine();   // ahora usa _controller.canvasSize ya correcto

    if (p != null) {
      // El postFrameCallback de escala/offset SÍ puede ir aquí,
      // pero setCanvasSize ya NO es necesario (motor se inicia con el tamaño correcto).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // no-op: motor ya tiene el tamaño correcto desde init
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          final screen = MediaQuery.of(context).size;
          final sideBar = _sideBarWidth;
          final topBar = _topBarHeight;
          final aW = screen.width - sideBar;
          final aH = screen.height - topBar;
          // FIX SCOPE: usar _controller.canvasSize en lugar de wPx/hPx
          // (ya fuera de scope después del refactor de initState)
          final csW = _controller.canvasSize.width;
          final csH = _controller.canvasSize.height;
          final scaleX = aW / csW;
          final scaleY = aH / csH;
          // FIX ZOOM: usar mínimo 0.35 para que el canvas sea usable.
          // El 0.85 del fit-to-screen da 24% para 1080x1920 — demasiado pequeño.
          // Con 0.35: canvas 1080*0.35=378px ancho (vs 304px disponibles → scroll leve)
          //           canvas 1920*0.35=672px alto (vs ~684px → casi cabe vertical).
          final fitScale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;
          final s = fitScale < 0.35 ? 0.35 : fitScale;
          // FIX OFFSET: clampear para que el canvas nunca quede detrás del sidebar.
          // Sin clamp: con canvas 1080px a 35% → offset.x = 56 + (355-378)/2 = 44.5dp
          // → canvas parcialmente oculto detrás del sidebar (56dp).
          final rawX = sideBar + (aW - csW * s) / 2;
          final rawY = topBar + (aH - csH * s) / 2;
          setState(() {
            _scale = s;
            _offset = Offset(
              rawX < sideBar ? sideBar.toDouble() : rawX,
              rawY < topBar  ? topBar.toDouble()  : rawY,
            );
          });
        });
      });
    }
  }
  // ── Sync listener: opacidad de capas ─────────────────────────
  double _lastSyncedOpacity = -1;
  void _syncLayerOpacities() {
    if (!_nativeReady) return;
    for (final layer in _controller.layers) {
      final nId = _nativeLayerIds[layer.id];
      if (nId == null) continue;
      // Solo enviar si cambió (evitar flood de calls)
      _bridgeCall(() => _bridge.setLayerOpacity(nId, layer.opacity));
    }
  }

  // ── Init motor nativo ──────────────────────────────────────────
  Future<void> _initNativeEngine() async {
    try {
      _bridge = NativeCanvasBridge();
      final cw = _controller.canvasSize.width.toInt();
      final ch = _controller.canvasSize.height.toInt();

      await _bridge.init(canvasW: cw, canvasH: ch, maxUndo: 20);

      for (int i = 0; i < _controller.layers.length; i++) {
        _nativeLayerIds[_controller.layers[i].id] = i;
      }
      final nativeActive = _nativeLayerIds[_controller.activeLayerId];
      if (nativeActive != null) await _bridge.setActiveLayer(nativeActive);

      // FIX 1: GPU usa fondo opaco blanco cuando el proyecto es "transparente".
      // Sin esto, exportPixels() devuelve (0,0,0,0) → RawImage transparente →
      // Scaffold gris oscuro visible en lugar del lienzo blanco.
      final _gpuBg = _controller.backgroundColor == Colors.transparent
          ? Colors.white : _controller.backgroundColor;
      final initImg = await _bridge.setBackground(_gpuBg);

      if (mounted) setState(() {
        _nativeReady = true;
        _nativeCanvasImage = initImg;
        // FIX SYNC: forzar _controller.canvasSize al tamaño real del GPU.
        // Si el proyecto tenía un tamaño corrupto (ej: 591x886 de una conversión
        // accidental de cm), el RawImage se renderizaba con esas dimensiones
        // mientras el GPU pintaba en 1080x1920 → trazo comprimido y desplazado.
        // FIX SYNC: si cualquier dimensión < 1000px → ambas corruptas → forzar 1080x1920
        final bool _sizeCorrupt = _controller.canvasSize.width < 1000
            || _controller.canvasSize.height < 1000;
        final gpuW = _sizeCorrupt ? 1080.0 : _controller.canvasSize.width;
        final gpuH = _sizeCorrupt ? 1920.0 : _controller.canvasSize.height;
        if (_controller.canvasSize.width != gpuW ||
            _controller.canvasSize.height != gpuH) {
          _controller.updateCanvasSize(Size(gpuW, gpuH));
          // Recalcular escala y offset para el nuevo tamaño
          final screen = MediaQuery.of(context).size;
          final aW = screen.width - _sideBarWidth;
          final aH = screen.height - _topBarHeight;
          final sx = aW / gpuW;
          final sy = aH / gpuH;
          final fitS = (sx < sy ? sx : sy) * 0.85;
          final s = fitS < 0.35 ? 0.35 : fitS;
          // FIX OFFSET: mismo clamp para el FIX SYNC.
          final _rawX = _sideBarWidth + (aW - gpuW * s) / 2;
          final _rawY = _topBarHeight + (aH - gpuH * s) / 2;
          _scale = s;
          _offset = Offset(
            _rawX < _sideBarWidth ? _sideBarWidth.toDouble() : _rawX,
            _rawY < _topBarHeight  ? _topBarHeight.toDouble()  : _rawY,
          );
        }
      });

      // FIX 2: setBackground puede devolver null si _toImage lanza excepción
      // silenciosa. Reintento con backoff: hasta 5 intentos con 80/160/320/640ms
      // de delay para que el motor GL complete la inicialización.
      // Sin esto: canvas oscuro al inicio hasta que el usuario dibuje.
      _retryExportCanvas(attempts: 5, delayMs: 80);
      // Auto-restaurar canvas si la app fue cerrada por el sistema
      Future.delayed(const Duration(milliseconds: 500), _autoRestoreCanvas);
      // Auto-save periódico cada 2 minutos
      _autoSaveTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _autoSaveCanvas(),
      );
      // Mostrar diálogo de segundo plano la primera vez
      Future.delayed(const Duration(seconds: 3), _checkBackgroundPermission);

      // Fase 4: cargar brush tips PNG al GPU en background
      // No bloquea el inicio — si un pincel se usa antes de que cargue
      // el motor usa el Gaussian default automáticamente.
      GpuBrushLoader.loadAll(_bridge).then((_) {
        if (mounted) setState(() {}); // repaint brush panel
      });

      debugPrint('[NativeEngine] ✅ Motor C++ Offscreen listo');
      FirebaseCrashlytics.instance.setCustomKey('renderer', 'gpu_cpp_offscreen');
    } catch (e, stack) {
      _nativeInitError = e.toString();
      debugPrint('[NativeEngine] ⚠️ Error: $_nativeInitError');
      // Reportar a Crashlytics como no-fatal (app sigue con renderer Dart)
      FirebaseCrashlytics.instance.recordError(
        e, stack,
        reason: 'NativeEngine init failed: $_nativeInitError',
        fatal: false,
      );
      FirebaseCrashlytics.instance.setCustomKey('native_error', _nativeInitError);
      FirebaseCrashlytics.instance.setCustomKey('renderer', 'cpu_dart_fallback');
      _nativeReady = false;
    }
  }

  // ── Helpers de sincronización ───────────────────────────────────

  /// Convierte layerId Dart → layerId nativo
  int _nativeLayer(int dartLayerId) =>
      _nativeLayerIds[dartLayerId] ?? 0;

  /// Llama al bridge para operaciones void.
  void _bridgeCall(Future<void> Function() fn) {
    if (_nativeReady) fn().catchError((e) {
      debugPrint('[NativeEngine] $e');
    });
  }

  /// Llama al bridge y actualiza _nativeCanvasImage con el resultado.
  void _bridgeImageCall(Future<ui.Image?> Function() fn) {
    if (!_nativeReady) return;
    fn().then((img) {
      if (img != null && mounted) setState(() => _nativeCanvasImage = img);
    }).catchError((e) {
      debugPrint('[NativeEngine] $e');
    });
  }

  /// Reintenta exportCanvas hasta [attempts] veces con delay exponencial.
  /// Necesario porque setBackground puede retornar null si el contexto GL
  /// aún no está completamente inicializado al primer intento.
  Future<void> _retryExportCanvas({required int attempts, required int delayMs}) async {
    for (int i = 0; i < attempts; i++) {
      await Future.delayed(Duration(milliseconds: delayMs * (1 << i)));
      if (!mounted || !_nativeReady) return;
      if (_nativeCanvasImage != null) return; // ya tenemos imagen válida
      final img = await _bridge.exportCanvas();
      if (img != null && mounted) {
        setState(() => _nativeCanvasImage = img);
        debugPrint('[NativeEngine] exportCanvas OK en intento ${i+1}');
        return;
      }
      debugPrint('[NativeEngine] exportCanvas intento ${i+1} falló');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _controller.removeListener(_syncLayerOpacities);
    if (_nativeReady) _bridge.destroy();
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
        if (_searchQuery.isNotEmpty) {
          return _importedBrushes.where((b) =>
              b.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }
        return _importedBrushes;
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

  // ── Auto-save al salir, auto-restore al volver ─────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App va al fondo → guardar el canvas en archivo temporal
      _autoSaveCanvas();
    } else if (state == AppLifecycleState.resumed) {
      // App vuelve al frente → re-inicializar GPU si fue destruido
      if (_nativeReady) {
        _retryExportCanvas(attempts: 3, delayMs: 200);
      }
    }
  }

  static const _kAutoSaveFile        = 'canvas_autosave.png';
  static const _kBgPermAskedKey     = 'bg_permission_asked';

  /// Muestra el diálogo de segundo plano solo la primera vez.
  Future<void> _checkBackgroundPermission() async {
    if (!mounted) return;
    // Verificar si ya pedimos permiso antes
    final prefs = await _getPrefs();
    final alreadyAsked = prefs['bg_asked'] == 'true';
    if (alreadyAsked) return;
    // Ya está ignorando optimización → no preguntar
    final alreadyIgnoring =
        await BackgroundServiceDialog.isIgnoringBatteryOptimization();
    if (alreadyIgnoring) return;
    if (!mounted) return;
    final accepted = await BackgroundServiceDialog.show(context);
    // Marcar como preguntado independiente de la respuesta
    await _savePrefs({'bg_asked': 'true'});
    if (accepted) {
      await BackgroundServiceDialog.requestIgnoreBatteryOptimization();
    }
  }

  // Prefs simples usando un archivo JSON (sin dependencia shared_preferences)
  Future<Map<String, String>> _getPrefs() async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('\${dir.path}/prefs.json');
      if (!await file.exists()) return {};
      final json = await file.readAsString();
      final map  = Map<String, dynamic>.from(
          (json.isNotEmpty ? (jsonDecode(json) as Map) : {}));
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) { return {}; }
  }

  Future<void> _savePrefs(Map<String, String> data) async {
    try {
      final dir   = await getApplicationDocumentsDirectory();
      final file  = File('\${dir.path}/prefs.json');
      final prefs = await _getPrefs();
      prefs.addAll(data);
      await file.writeAsString(jsonEncode(prefs));
    } catch (_) {}
  }

  Future<void> _autoSaveCanvas() async {
    if (!_nativeReady || !mounted) return;
    try {
      // Exportar canvas como PNG completo
      final pixels = await _bridge.exportPixels();
      if (pixels == null || pixels.isEmpty) return;
      final cw  = _controller.canvasSize.width.toInt();
      final ch  = _controller.canvasSize.height.toInt();
      // Convertir RGBA raw → PNG
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels, cw, ch, ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );
      final img  = await completer.future;
      final bd   = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd == null) return;
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('\${dir.path}/$_kAutoSaveFile');
      await file.writeAsBytes(bd.buffer.asUint8List());
      debugPrint('[AutoSave] Guardado: \${file.path}');
    } catch (e) {
      debugPrint('[AutoSave] Error: $e');
    }
  }

  Future<void> _autoRestoreCanvas() async {
    if (!_nativeReady || !mounted) return;
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_kAutoSaveFile');
      if (!await file.exists()) return;
      final pngBytes = await file.readAsBytes();
      if (pngBytes.isEmpty) return;
      // Decodificar PNG → ui.Image
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final img   = frame.image;
      if (!mounted) { img.dispose(); return; }
      // Importar como imagen en el canvas (mismo flujo que _importImageToCanvas)
      final canvasW = _controller.canvasSize.width;
      final canvasH = _controller.canvasSize.height;
      // addCanvasImage coloca la imagen centrada en el canvas
      _controller.addCanvasImage(img);
      setState(() {});
      debugPrint('[AutoSave] Canvas restaurado');
      await file.delete();
    } catch (e) {
      debugPrint('[AutoSave] Restore error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            _buildCanvas(),

            // Regla — detrás de todos los paneles UI (z-order correcto)
            if (_showRuler && !_isFullscreen && !_showLayers)
              _buildRuler(),

            if (!_isFullscreen)
              Positioned(
                left: 0,
                top: _topBarHeight,
                bottom: 0,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  child: _buildSideBar(),
                ),
              ),

            if (!_isFullscreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  child: _buildTopBar(),
                ),
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
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => LayerPanel(
                    layers: _controller.layers,
                    activeLayerId: _controller.activeLayerId,
                    onLayerSelected: (id) {
                      _controller.setActiveLayer(id);
                      final nId = _nativeLayerIds[id];
                      if (nId != null) _bridgeCall(() => _bridge.setActiveLayer(nId));
                    },
                    onLayerVisibilityToggled: (id) {
                      _controller.toggleLayerVisibility(id);
                      final nId = _nativeLayerIds[id];
                      if (nId != null) {
                        final visible = _controller.layers
                            .firstWhere((l) => l.id == id,
                                orElse: () => _controller.layers.first)
                            .isVisible;
                        _bridgeCall(() => _bridge.setLayerVisible(nId, visible));
                      }
                    },
                    onLayerDeleted: (id) {
                      final nId = _nativeLayerIds.remove(id);
                      _controller.removeLayer(id);
                      if (nId != null) _bridgeCall(() => _bridge.removeLayer(nId));
                    },
                    onLayerAdded: () async {
                      _controller.addLayer();
                      // Sincronizar nueva capa con motor nativo
                      final newLayer = _controller.layers.last;
                      if (_nativeReady) {
                        final nId = await _bridge.addLayer(name: newLayer.name);
                        _nativeLayerIds[newLayer.id] = nId;
                        await _bridge.setActiveLayer(nId);
                      }
                    },
                    onClose: () =>
                        setState(() => _showLayers = false),
                    onLayerDuplicated: (id) async {
                      _controller.duplicateLayer(id);
                      // Capa duplicada → nueva capa al final
                      final newLayer = _controller.layers.last;
                      if (_nativeReady) {
                        final nId = await _bridge.addLayer(name: newLayer.name);
                        _nativeLayerIds[newLayer.id] = nId;
                      }
                    },
                    onLayerMergedDown: (id) {
                      // Merge: combinar capas — en motor nativo se borra la de arriba
                      final srcNId = _nativeLayerIds[id];
                      _controller.mergeDownLayer(id);
                      if (srcNId != null) {
                        _nativeLayerIds.remove(id);
                        _bridgeCall(() => _bridge.removeLayer(srcNId));
                      }
                    },
                    onLayerLocked: _controller.lockLayer,
                    onLayersFlatten: () {
                      // Flatten: conservar solo la capa base
                      _controller.flattenLayers();
                      if (_nativeReady) {
                        // Eliminar todas menos la primera
                        final toRemove = Map<int, int>.from(_nativeLayerIds);
                        _nativeLayerIds.clear();
                        if (_controller.layers.isNotEmpty) {
                          final base = _controller.layers.first;
                          // Reutilizar primer nativeId
                          final firstNId = toRemove.values.isNotEmpty
                              ? toRemove.values.first : -1;
                          if (firstNId >= 0) {
                            _nativeLayerIds[base.id] = firstNId;
                            for (final nId in toRemove.values.skip(1)) {
                              _bridgeCall(() => _bridge.removeLayer(nId));
                            }
                          }
                        }
                      }
                    },
                  ),
                ), // AnimatedBuilder
                ), // Listener
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
                child: Listener(
                  behavior: HitTestBehavior.opaque,
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
                ), // AnimatedBuilder
                ), // Listener
              ),

            if (!_isFullscreen && !_showLayers)
              Positioned(
                right: 8,
                bottom: 12,
                child: _buildZoomIndicator(),
              ),

            // Tooltip overlay
            if (_tooltipText != null)
              _buildTooltipOverlay(),

            // ── DEBUG: Indicador de renderer (quitar en producción) ──
            if (!_isFullscreen)
              _buildRendererBadge(),

            // Brush size preview (ValueNotifier — sin setState)
            _buildBrushPreview(),

            if (_showCanvasSettings && !_isFullscreen)
              _buildCanvasSettingsPanel(),

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
        _btn(Icons.arrow_back_ios, tooltip: 'Inicio', onTap: () => context.go('/home')),
        _btn(Icons.undo, tooltip: 'Deshacer', onTap: () => _bridgeImageCall(() => _bridge.undo())),
        _btn(Icons.redo, tooltip: 'Rehacer', onTap: () => _bridgeImageCall(() => _bridge.redo())),
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
            tooltip: 'Simetría',
            isActive: _controller.symmetryEnabled,
            onTap: () {
              _controller.toggleSymmetry();
              _bridgeCall(() => _bridge.setSymmetry(
                _controller.symmetryEnabled,
                axis: _controller.symmetryType == SymmetryType.vertical ? 1 : 0,
              ));
            },
          ),
        ),
        const Spacer(),
        _buildBrushBtn(),
        _buildSelectionBtn(),
        _buildTransformBtn(),
        _buildSmudgeBtn(),
        _buildLayersBtn(),
        _buildColorBtn(),
        _buildProjectMenuBtn(),
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
              _btn(Icons.undo, tooltip: 'Deshacer', onTap: () => _bridgeImageCall(() => _bridge.undo())),
              _btn(Icons.redo, tooltip: 'Rehacer', onTap: () => _bridgeImageCall(() => _bridge.redo())),
              _btn(
                _zoomMode ? Icons.edit_outlined : Icons.zoom_in,
                isActive: _zoomMode,
                tooltip: 'Modo zoom',
                onTap: () =>
                    setState(() => _zoomMode = !_zoomMode),
              ),
              _btn(
                _showGrid ? Icons.grid_on : Icons.grid_off,
                isActive: _showGrid,
                tooltip: 'Cuadrícula',
                onTap: () =>
                    setState(() => _showGrid = !_showGrid),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (c, _) => _btn(
                  Icons.flip,
                  isActive: _controller.symmetryEnabled,
                  onTap: () {
                    _controller.toggleSymmetry();
                    _bridgeCall(() => _bridge.setSymmetry(
                      _controller.symmetryEnabled,
                      axis: _controller.symmetryType == SymmetryType.vertical ? 1 : 0,
                    ));
                  },
                ),
              ),
              const Spacer(),
              _btn(Icons.tune,
                  tooltip: 'Ajustes del lienzo',
                  isActive: _showCanvasSettings,
                  onTap: () => setState(() {
                    _showCanvasSettings = !_showCanvasSettings;
                    if (_showCanvasSettings) _showBrushPanel = false;
                  })),
              _btn(Icons.add_photo_alternate_outlined,
                  tooltip: 'Importar imagen',
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
              _buildProjectMenuBtn(),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTooltipOverlay() {
    final screen = MediaQuery.of(context).size;
    // Calcular posición: aparece encima del dedo, centrado, sin salirse de pantalla
    final tipW = 140.0;
    final tipH = 32.0;
    double x = (_tooltipPosition.dx - tipW / 2)
        .clamp(8.0, screen.width - tipW - 8);
    double y = (_tooltipPosition.dy - tipH - 12)
        .clamp(_topBarHeight + 4.0, screen.height - tipH - 8);
    return Positioned(
      left: x, top: y,
      width: tipW, height: tipH,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _tooltipText != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3A3A3C), width: 0.5),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            child: Text(
              _tooltipText ?? '',
              style: const TextStyle(
                fontFamily: 'Raleway',
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _triggerBrushPreview(double size) {
    _previewToken++;
    final token = _previewToken;
    _brushPreviewNotifier.value = size;
    // Auto-ocultar después de 1.2s
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _previewToken == token) {
        _brushPreviewNotifier.value = null;
      }
    });
  }

  // Ocultar preview inmediatamente (al iniciar trazo)
  void _hideBrushPreview() {
    _previewToken++;
    _brushPreviewNotifier.value = null;
  }

  Widget _buildBrushPreview() {
    return ValueListenableBuilder<double?>(
      valueListenable: _brushPreviewNotifier,
      builder: (context, size, _) {
        final visible = size != null;
        final s = size ?? 10.0;
        final radius = (s / 2).clamp(4.0, 110.0);
        final isEraser = _controller.activeBrush.type == StrokeType.eraser;
        final color = isEraser
            ? Colors.white.withOpacity(0.9)
            : _controller.activeColor.withOpacity(0.9);
        return Positioned(
          top: 0, left: 0, right: 0, bottom: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  width: (radius * 2 + 28).clamp(60.0, 260.0),
                  height: (radius * 2 + 48).clamp(60.0, 280.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: radius * 2,
                        height: radius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: Colors.white38, width: 1),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${s.round()} px',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Raleway',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Indicador de renderer activo ─────────────────────────────
  Widget _buildRendererBadge() {
    return Positioned(
      bottom: 60,
      right: 8,
      child: GestureDetector(
        onTap: () => _showRendererInfo(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _nativeReady
                ? const Color(0xFF1A7F3C).withOpacity(0.92)
                : const Color(0xFF8B4513).withOpacity(0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _nativeReady ? Colors.greenAccent : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _nativeReady ? Icons.memory : Icons.brush,
              color: Colors.white, size: 10,
            ),
            const SizedBox(width: 4),
            Text(
              _nativeReady
                  ? 'GPU C++ Offscreen | tex:${GpuBrushLoader.loadedCount}'
                  : 'CPU Dart',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontFamily: 'Raleway',
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showRendererInfo() {
    final msg = _nativeReady
        ? 'Motor C++/OpenGL ES activo\n'
          'Motor offscreen activo\n'
          'Capas nativas: ${_nativeLayerIds.length}\n'
          'Estado: RENDERIZANDO EN GPU\n'
          'Estado: OK\n'
          'sc=${_scale.toStringAsFixed(3)} off=(${_offset.dx.toStringAsFixed(0)},${_offset.dy.toStringAsFixed(0)})\n'
          'GPU status: $_lastGpuStatus\n'
          'Último beginStroke:\n$_lastBridgeCoords'
        : 'Motor Dart activo (fallback)\n'
          'Error: $_nativeInitError\n'
          '(La app funciona con renderer Dart)';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          _nativeReady ? '⚡ Motor GPU' : '🖌️ Motor CPU',
          style: const TextStyle(color: Colors.white, fontFamily: 'Raleway'),
        ),
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white70, fontFamily: 'Raleway', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
  }

  void _showTooltip(String text, Offset globalPos) {
    setState(() {
      _tooltipText = text;
      _tooltipPosition = globalPos;
      _tooltipHideAt = DateTime.now().add(const Duration(seconds: 3));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _tooltipHideAt != null &&
          DateTime.now().isAfter(_tooltipHideAt!)) {
        setState(() => _tooltipText = null);
      }
    });
  }

  Widget _btn(IconData icon, {
    VoidCallback? onTap,
    bool isActive = false,
    Color? color,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: tooltip != null
          ? (d) => _showTooltip(tooltip, d.globalPosition)
          : null,
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
      onLongPressStart: (d) => _showTooltip('Pinceles', d.globalPosition),
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
      onLongPressStart: (d) => _showTooltip('Selección', d.globalPosition),
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
      onLongPressStart: (d) => _showTooltip('Mover / Transformar', d.globalPosition),
      onTap: () => setState(() {
        if (isActive) {
          _transformMode = TransformMode.ninguno;
        } else {
          _transformMode = TransformMode.activo;
          _selectionMode = SelectionMode.ninguno;
          _smudgeMode = false;
          _showSelectionOptions = false;
          _showBrushPanel = false;
          // FIX: desactivar sello al entrar en transform mode
          _stampMode = false;
          _activeStamp = null;
          _activeStampImage = null;
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
      onLongPressStart: (d) => _showTooltip('Modo mano', d.globalPosition),
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
      onLongPressStart: (d) => _showTooltip('Capas', d.globalPosition),
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
      onLongPressStart: (d) => _showTooltip('Color', d.globalPosition),
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
                onLongPressStart: (d) => _showTooltip('Borrador', d.globalPosition),
                onTap: () => setState(() {
                  // FIX: desactivar sello y transform mode al tocar borrador
                  _stampMode = false;
                  _activeStamp = null;
                  _activeStampImage = null;
                  _transformMode = TransformMode.ninguno;
                  _selectedImageId = null;
                  _controller.selectCanvasImage(null);
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
                onLongPressStart: (d) => _showTooltip('Redimensionar lienzo', d.globalPosition),
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
                onLongPressStart: (d) => _showTooltip('Restablecer rotación', d.globalPosition),
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
                          () {
                            _controller.setBrushSize(v);
                            if (!_isScaling) _triggerBrushPreview(v);
                          }),
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
              // ─── DUREZA (todos los pinceles) ────────
              ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Container(height: 0.5, color: _borderColor),
                ),
                const SizedBox(height: 6),
                Text('DUR',
                    style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 9,
                        color: _textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(
                    '${(_controller.activeBrush.hardness * 100).round()}%',
                    style: const TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 12,
                        color: _textPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SizedBox(
                  height: _isLandscape ? 70 : 90,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.accentRed,
                        inactiveTrackColor: _borderColor,
                        thumbColor: Colors.white,
                        overlayColor: AppTheme.accentRed.withOpacity(0.15),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        trackHeight: 3,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _controller.activeBrush.hardness.clamp(0.0, 1.0),
                        min: 0.0,
                        max: 1.0,
                        onChanged: (v) => setState(
                            () => _controller.setBrushHardness(v)),
                      ),
                    ),
                  ),
                ),
                // ─── BOTONES IA ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Container(height: 0.5, color: _borderColor),
                ),
                const SizedBox(height: 6),
                Text('IA',
                    style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 9,
                        color: AppTheme.accentRed,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                // Eliminar fondo
                _EraserAIBtn(
                  icon: Icons.auto_fix_high,
                  label: 'Fondo',
                  onTap: _selectedImageId != null
                      ? () => _aiRemoveBackground()
                      : null,
                ),
                const SizedBox(height: 6),
                // Eliminar objeto
                _EraserAIBtn(
                  icon: Icons.content_cut,
                  label: 'Objeto',
                  onTap: _selectedImageId != null
                      ? () => _aiRemoveObject()
                      : null,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
       ); 
      },
    );
  }

  // ─── AI: Eliminar fondo de imagen ─────────────────────────
  Future<void> _aiRemoveBackground() async {
    if (_selectedImageId == null) return;
    final img = _controller.canvasImages
        .where((i) => i.id == _selectedImageId)
        .firstOrNull;
    if (img == null) return;

    // Mostrar loading
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1A1A1A),
      content: Row(children: const [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(color: Color(0xFFE74C3C), strokeWidth: 2)),
        SizedBox(width: 12),
        Text('Eliminando fondo con IA...', style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
      ]),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));

    try {
      // Convertir imagen a bytes para enviar a la API
      final byteData = await img.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final base64Image = base64Encode(bytes);

      // Llamar al API de Claude para obtener la máscara del fondo
      // (marcado como TODO — requiere integración con remove.bg o ML Kit)
      // Por ahora aplica borrado de fondo por threshold de color
      await _removeBackgroundByThreshold(img);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF1A1A1A),
          content: const Row(children: [
            Text('✅', style: TextStyle(fontSize: 16)),
            SizedBox(width: 10),
            Text('Fondo eliminado', style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
          ]),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        ));
      }
    }
  }

  // Eliminar fondo por threshold de color (esquinas = color de fondo)
  Future<void> _removeBackgroundByThreshold(CanvasImageModel img) async {
    final byteData = await img.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final w = img.image.width;
    final h = img.image.height;
    final pixels = byteData.buffer.asUint8List();

    // Color de fondo = promedio de las 4 esquinas
    int avgR = 0, avgG = 0, avgB = 0;
    for (final corner in [0, (w - 1) * 4, (h - 1) * w * 4, ((h - 1) * w + w - 1) * 4]) {
      if (corner + 3 < pixels.length) {
        avgR += pixels[corner];
        avgG += pixels[corner + 1];
        avgB += pixels[corner + 2];
      }
    }
    avgR ~/= 4; avgG ~/= 4; avgB ~/= 4;

    // Umbral de tolerancia
    const tolerance = 40;

    // Flood fill desde bordes para encontrar el fondo
    final visited = List<bool>.filled(w * h, false);
    final queue = <int>[];

    // Agregar todos los píxeles del borde
    for (int x = 0; x < w; x++) { queue.add(x); queue.add((h - 1) * w + x); }
    for (int y = 0; y < h; y++) { queue.add(y * w); queue.add(y * w + w - 1); }

    while (queue.isNotEmpty) {
      final idx = queue.removeLast();
      if (idx < 0 || idx >= w * h || visited[idx]) continue;
      final p = idx * 4;
      final dr = (pixels[p] - avgR).abs();
      final dg = (pixels[p + 1] - avgG).abs();
      final db = (pixels[p + 2] - avgB).abs();
      if (dr + dg + db > tolerance * 3) continue;
      visited[idx] = true;
      pixels[p + 3] = 0; // transparente
      final x = idx % w;
      final y = idx ~/ w;
      if (x > 0) queue.add(idx - 1);
      if (x < w - 1) queue.add(idx + 1);
      if (y > 0) queue.add(idx - w);
      if (y < h - 1) queue.add(idx + w);
    }

    // Reconstruir imagen
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, completer.complete);
    final newImage = await completer.future;
    _controller.replaceCanvasImage(_selectedImageId!, newImage);
  }

  Future<void> _aiRemoveObject() async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1A1A1A),
      content: const Text(
          'Pasa el borrador sobre el objeto para eliminarlo',
          style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
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
          // FIX: limitar altura al espacio disponible bajo la top bar
          height: (MediaQuery.of(context).size.height - _topBarHeight - 24)
              .clamp(280.0, MediaQuery.of(context).size.height * 0.82),
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
          // Botón refrescar pinceles importados
          if (_brushTab == BrushPanelTab.descargados)
            GestureDetector(
              onTap: () async {
                setState(() => _isRefreshingBrushes = true);
                await _loadImportedBrushes();
                if (mounted) setState(() => _isRefreshingBrushes = false);
              },
              child: Container(
                margin: const EdgeInsets.all(3),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _isRefreshingBrushes
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accentRed,
                        ))
                    : const Icon(Icons.refresh,
                        color: AppTheme.accentRed, size: 18),
              ),
            ),
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
    if (_selectedStampCategory != null) {
      return _buildStampGrid(_selectedStampCategory!);
    }
    return _buildStampCategoryGrid();
  }

  Widget _buildStampCategoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_activeStamp != null)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.interests, color: Color(0xFFE74C3C), size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text('Sello: ${_activeStamp!.name}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Raleway'))),
              GestureDetector(
                onTap: () => setState(() {
                  _activeStamp = null;
                  _activeStampImage = null;
                  _stampMode = false;
                }),
                child: const Icon(Icons.close, color: Colors.white38, size: 14),
              ),
            ]),
          ),

        if (_stampMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: Row(children: [
              const Text('TAM', style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Raleway')),
              Expanded(
                child: Slider(
                  value: _stampSize.clamp(50.0, 800.0),
                  min: 50, max: 800,
                  activeColor: const Color(0xFFE74C3C),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => setState(() => _stampSize = v),
                ),
              ),
              Text('${_stampSize.toInt()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Raleway')),
            ]),
          ),

        const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 10, 6),
          child: Text('CATEGORÍAS', style: TextStyle(
              color: Color(0xFFE74C3C), fontSize: 10,
              fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Raleway')),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
            ),
            itemCount: StampLibrary.categories.length,
            itemBuilder: (context, index) {
              final cat = StampLibrary.categories[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedStampCategory = cat),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF48484A)),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 12),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 11,
                            fontFamily: 'Raleway', fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${cat.stamps.length} sellos', style: const TextStyle(
                            color: Colors.white38, fontSize: 10, fontFamily: 'Raleway')),
                      ],
                    )),
                    const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                    const SizedBox(width: 8),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStampGrid(StampCategory category) {
    return Column(children: [
      Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _selectedStampCategory = null),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 16),
            ),
          ),
          Text('${category.emoji}  ${category.name}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'BlackOpsOne')),
          const Spacer(),
          Text('${category.stamps.length} sellos',
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Raleway')),
          const SizedBox(width: 8),
        ]),
      ),
      Container(height: 0.5, color: const Color(0xFF48484A)),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: category.stamps.length,
          itemBuilder: (context, index) {
            final stamp = category.stamps[index];
            final isActive = _activeStamp?.id == stamp.id;
            return GestureDetector(
              onTap: () => _selectStamp(stamp),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE74C3C).withOpacity(0.15) : const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF48484A),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        stamp.assetPath,
                        fit: BoxFit.contain,
                        color: isActive ? const Color(0xFFE74C3C) : Colors.white,
                        colorBlendMode: BlendMode.srcATop,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.interests_outlined, color: Colors.white24, size: 28),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(stamp.name,
                        style: TextStyle(
                            color: isActive ? const Color(0xFFE74C3C) : Colors.white54,
                            fontSize: 9, fontFamily: 'Raleway'),
                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ─── PANEL DE AJUSTES DEL CANVAS ────────────────────────────

  Widget _buildCanvasSettingsPanel() {
    final cs = _controller.canvasSize;
    return Positioned(
      top: _topBarHeight + 4,
      left: _sideBarWidth + 8,
      right: 8,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: _panelColor.withOpacity(0.97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 0.5),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20, offset: const Offset(0, 6),
            )],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                child: Row(children: [
                  const Icon(Icons.tune, color: Color(0xFFE74C3C), size: 16),
                  const SizedBox(width: 8),
                  Text('AJUSTES DEL LIENZO',
                    style: TextStyle(fontFamily: 'Raleway', fontSize: 12,
                      fontWeight: FontWeight.bold, color: _textPrimary,
                      letterSpacing: 0.8)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showCanvasSettings = false),
                    child: Icon(Icons.close, color: _textSecondary, size: 18),
                  ),
                ]),
              ),
              Divider(color: _borderColor, height: 0.5),
              // Content scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── LIENZO ──────────────────────────────
                      _settingsSection('LIENZO'),
                      const SizedBox(height: 8),
                      // Tamaño del canvas
                      Text('Tamaño', style: TextStyle(fontFamily: 'Raleway',
                        fontSize: 11, color: _textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _canvasSizeChip('Retrato', const Size(1080, 1920)),
                        _canvasSizeChip('Cuadrado', const Size(1080, 1080)),
                        _canvasSizeChip('Apaisado', const Size(1920, 1080)),
                        _canvasSizeChip('A4', const Size(794, 1123)),
                      ]),
                      const SizedBox(height: 12),
                      // Fondo
                      Text('Fondo', style: TextStyle(fontFamily: 'Raleway',
                        fontSize: 11, color: _textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        _bgColorChip('Blanco', Colors.white),
                        _bgColorChip('Negro', const Color(0xFF1A1A1A)),
                        _bgColorChip('Transparente', Colors.transparent),
                      ]),
                      const SizedBox(height: 12),
                      // DPI exportación
                      Text('DPI de exportación', style: TextStyle(fontFamily: 'Raleway',
                        fontSize: 11, color: _textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        _dpiChip(72),
                        _dpiChip(150),
                        _dpiChip(300),
                      ]),

                      const SizedBox(height: 16),
                      Divider(color: _borderColor, height: 0.5),
                      const SizedBox(height: 12),

                      // ── NAVEGACIÓN ───────────────────────────
                      _settingsSection('NAVEGACIÓN'),
                      const SizedBox(height: 8),
                      // Pan sensitivity
                      _sensitivityRow(
                        label: 'Sensibilidad de desplazamiento',
                        value: _panSensitivity,
                        min: 0.3, max: 2.0,
                        onChanged: (v) => setState(() => _panSensitivity = v),
                      ),
                      const SizedBox(height: 10),
                      // Zoom sensitivity
                      _sensitivityRow(
                        label: 'Sensibilidad de zoom',
                        value: _zoomSensitivity,
                        min: 0.3, max: 2.0,
                        onChanged: (v) => setState(() => _zoomSensitivity = v),
                      ),
                      const SizedBox(height: 10),
                      // Free rotation toggle
                      _toggleRow(
                        label: 'Rotación libre del canvas',
                        subtitle: 'Permite rotar con 2 dedos',
                        value: _freeRotation,
                        onChanged: (v) => setState(() => _freeRotation = v),
                      ),
                      const SizedBox(height: 10),
                      // Max zoom
                      Text('Zoom máximo', style: TextStyle(fontFamily: 'Raleway',
                        fontSize: 11, color: _textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        _zoomChip(5),
                        _zoomChip(10),
                        _zoomChip(15),
                        _zoomChip(20),
                      ]),

                      const SizedBox(height: 16),
                      Divider(color: _borderColor, height: 0.5),
                      const SizedBox(height: 12),

                      // ── VISUAL ───────────────────────────────
                      _settingsSection('VISUAL'),
                      const SizedBox(height: 8),
                      // Center guides
                      _toggleRow(
                        label: 'Guías del centro',
                        subtitle: 'Líneas de referencia centrales',
                        value: _showCenterGuides,
                        onChanged: (v) => setState(() => _showCenterGuides = v),
                      ),
                      const SizedBox(height: 10),
                      // Ruler
                      _toggleRow(
                        label: 'Regla',
                        subtitle: 'Muestra dimensiones del diseño',
                        value: _showRuler,
                        onChanged: (v) => setState(() => _showRuler = v),
                      ),
                      if (_showRuler) ...[
                        const SizedBox(height: 8),
                        Text('Unidad de medida', style: TextStyle(fontFamily: 'Raleway',
                          fontSize: 11, color: _textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, children: [
                          _unitChip('cm'),
                          _unitChip('mm'),
                          _unitChip('inch'),
                        ]),
                      ],
                      const SizedBox(height: 8),
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

  Widget _settingsSection(String title) => Text(title,
    style: TextStyle(fontFamily: 'Raleway', fontSize: 10,
      fontWeight: FontWeight.bold, color: AppTheme.accentRed,
      letterSpacing: 1.0));

  Widget _sensitivityRow({
    required String label, required double value,
    required double min, required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontFamily: 'Raleway',
          fontSize: 11, color: _textPrimary))),
        Text('${value.toStringAsFixed(1)}x',
          style: TextStyle(fontFamily: 'Raleway', fontSize: 11,
            color: AppTheme.accentRed, fontWeight: FontWeight.bold)),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppTheme.accentRed,
          inactiveTrackColor: _borderColor,
          thumbColor: AppTheme.accentRed,
          trackHeight: 2.0,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
    ]);
  }

  Widget _toggleRow({
    required String label, String? subtitle,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: 'Raleway',
          fontSize: 11, color: _textPrimary)),
        if (subtitle != null) Text(subtitle, style: TextStyle(fontFamily: 'Raleway',
          fontSize: 10, color: _textSecondary)),
      ])),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.accentRed,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]);
  }

  Widget _canvasSizeChip(String label, Size size) {
    final isActive = _controller.canvasSize == size;
    return GestureDetector(
      onTap: () {
        setState(() => _controller.updateCanvasSize(size));
        _bridgeCall(() => _bridge.setCanvasSize(size.width.toInt(), size.height.toInt()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentRed.withOpacity(0.15) : _cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.accentRed : _borderColor),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Raleway', fontSize: 11,
          color: isActive ? AppTheme.accentRed : _textPrimary)),
      ),
    );
  }

  Widget _bgColorChip(String label, Color color) {
    final isActive = _controller.backgroundColor == color;
    return GestureDetector(
      onTap: () { setState(() => _controller.setBackgroundColor(color)); _bridgeCall(() => _bridge.setBackground(color == Colors.transparent ? Colors.white : color)); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentRed.withOpacity(0.15) : _cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.accentRed : _borderColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12,
            decoration: BoxDecoration(
              color: color == Colors.transparent ? null : color,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(3),
              image: color == Colors.transparent ? const DecorationImage(
                image: AssetImage('assets/images/transparent_bg.png'),
                fit: BoxFit.cover,
              ) : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontFamily: 'Raleway', fontSize: 11,
            color: isActive ? AppTheme.accentRed : _textPrimary)),
        ]),
      ),
    );
  }

  Widget _dpiChip(int dpi) {
    final isActive = _exportDpi == dpi;
    return GestureDetector(
      onTap: () => setState(() => _exportDpi = dpi),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentRed.withOpacity(0.15) : _cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.accentRed : _borderColor),
        ),
        child: Text('$dpi DPI', style: TextStyle(fontFamily: 'Raleway', fontSize: 11,
          color: isActive ? AppTheme.accentRed : _textPrimary)),
      ),
    );
  }

  Widget _zoomChip(int zoom) {
    final isActive = _maxZoom == zoom.toDouble();
    return GestureDetector(
      onTap: () => setState(() => _maxZoom = zoom.toDouble()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentRed.withOpacity(0.15) : _cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.accentRed : _borderColor),
        ),
        child: Text('${zoom}x', style: TextStyle(fontFamily: 'Raleway', fontSize: 11,
          color: isActive ? AppTheme.accentRed : _textPrimary)),
      ),
    );
  }

  Widget _unitChip(String unit) {
    final isActive = _rulerUnit == unit;
    return GestureDetector(
      onTap: () => setState(() => _rulerUnit = unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentRed.withOpacity(0.15) : _cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.accentRed : _borderColor),
        ),
        child: Text(unit, style: TextStyle(fontFamily: 'Raleway', fontSize: 11,
          color: isActive ? AppTheme.accentRed : _textPrimary)),
      ),
    );
  }

  // ─── REGLA DEL CANVAS ────────────────────────────────────────

  /// Devuelve cuántos píxeles del canvas equivalen a 1 unidad de la regla
  double get _canvasPxPerUnit {
    switch (_rulerUnit) {
      case 'mm': return _exportDpi / 25.4;
      case 'inch': return _exportDpi.toDouble();
      case 'cm':
      default: return _exportDpi / 2.54;
    }
  }

  Widget _buildRuler() {
    const rulerSize = 20.0;
    final topOffset = _topBarHeight;
    final leftOffset = _sideBarWidth.toDouble();
    return Positioned(
      top: topOffset,
      left: leftOffset,
      right: 0,
      bottom: 0,
      child: Stack(children: [
        // Regla horizontal (arriba)
        Positioned(
          top: 0, left: rulerSize, right: 0, height: rulerSize,
          child: ClipRect(child: CustomPaint(
            painter: _RulerPainter(
              direction: Axis.horizontal,
              scale: _scale,
              offset: _offset.dx - leftOffset - rulerSize, // FIX: account for ruler thickness
              canvasSize: _controller.canvasSize.width,
              pxPerUnit: _canvasPxPerUnit,
              unit: _rulerUnit,
            ),
          )),
        ),
        // Regla vertical (izquierda)
        Positioned(
          top: rulerSize, left: 0, bottom: 0, width: rulerSize,
          child: ClipRect(child: CustomPaint(
            painter: _RulerPainter(
              direction: Axis.vertical,
              scale: _scale,
              offset: _offset.dy - topOffset - rulerSize, // FIX: account for ruler thickness
              canvasSize: _controller.canvasSize.height,
              pxPerUnit: _canvasPxPerUnit,
              unit: _rulerUnit,
            ),
          )),
        ),
        // Esquina
        Positioned(
          top: 0, left: 0, width: rulerSize, height: rulerSize,
          child: Container(color: const Color(0xFF2C2C2E)),
        ),
      ]),
    );
  }

  /// Funde los borrados en la imagen y limpia eraseStrokes para liberar memoria.
  /// Se llama automáticamente después de cada trazo de borrador.
  bool _isBaking = false; // prevent concurrent bakes

  void _bakeErases(String imageId) {
    if (_isBaking) return;
    final img = _controller.canvasImages
        .where((i) => i.id == imageId).firstOrNull;
    if (img == null || !img.hasErases) return;
    _isBaking = true;

    // FIX: bake a resolución NATIVA de la imagen (sin reescalar = sin blur)
    final nativeW = img.image.width;
    final nativeH = img.image.height;
    final dispW = img.size.width;
    final dispH = img.size.height;
    // Factores de escala: de coordenadas canvas a píxeles nativos
    final scaleX = nativeW / dispW;
    final scaleY = nativeH / dispH;

    final recorder = ui.PictureRecorder();
    final c = ui.Canvas(recorder,
        Rect.fromLTWH(0, 0, nativeW.toDouble(), nativeH.toDouble()));

    final srcRect = Rect.fromLTWH(0, 0, nativeW.toDouble(), nativeH.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, nativeW.toDouble(), nativeH.toDouble());

    // Dibujar imagen a 1:1 + borrados escalados
    c.saveLayer(dstRect, Paint());
    c.drawImageRect(img.image, srcRect, dstRect,
        Paint()..color = Colors.white.withOpacity(img.opacity)
               ..filterQuality = FilterQuality.none); // sin blur
    for (final erase in img.eraseStrokes) {
      _drawEraseOnCanvasNative(c, erase, img.position, scaleX, scaleY);
    }
    c.restore();

    final picture = recorder.endRecording();
    // FIX: toImageSync evita el gap async durante zoom (causa de crash GPU)
    ui.Image? bakedImage;
    try {
      bakedImage = picture.toImageSync(nativeW, nativeH);
    } catch (e) {
      debugPrint('toImageSync error: $e');
      _controller.clearEraseStrokesForced(imageId); // liberar aunque falle
      _isBaking = false;
      return;
    } finally {
      picture.dispose();
    }
    if (!mounted) {
      bakedImage.dispose();
      _isBaking = false;
      return;
    }
    _controller.replaceCanvasImageBaked(imageId, bakedImage);
    _isBaking = false;
  }

  /// Dibuja erase stroke en espacio nativo de la imagen (sin blur por reescalado)
  void _drawEraseOnCanvasNative(ui.Canvas canvas, EraseStroke erase,
      Offset imgPos, double scaleX, double scaleY) {
    if (erase.points.isEmpty) return;
    // erase.hardness = OPA slider (así lo envía canvas_screen).
    // Controla cuánto se borra por pasada: 0.05=muy suave, 1.0=borra todo.
    // FIX: antes se usaba como gradient stop → actuaba como dureza, no opacidad.
    final eraseOpacity = erase.hardness.clamp(0.05, 1.0);
    final r = erase.radius * scaleX;

    Offset toNative(Offset p) => Offset(
        (p.dx - imgPos.dx) * scaleX,
        (p.dy - imgPos.dy) * scaleY,
    );

    void stamp(Offset p) {
      final np = toNative(p);
      // dstOut con opacity parcial: borra exactamente eraseOpacity del alpha destino.
      // Coincide con el overlay en _drawEraseStroke (Colors.white.withOpacity(opacity)).
      canvas.drawCircle(np, r, Paint()
        ..blendMode = BlendMode.dstOut
        ..color = Colors.white.withOpacity(eraseOpacity)
        ..style = PaintingStyle.fill);
    }

    if (erase.points.length == 1) { stamp(erase.points.first); return; }
    stamp(erase.points.first);
    for (int i = 1; i < erase.points.length; i++) {
      stamp(erase.points[i]);
      final dist = (erase.points[i] - erase.points[i-1]).distance * scaleX;
      final steps = (dist / (r * 0.4)).ceil().clamp(1, 6);
      for (int s = 1; s < steps; s++) {
        stamp(Offset.lerp(erase.points[i-1], erase.points[i], s / steps)!);
      }
    }
  }

  /// Acopia el sello con todos los strokes del canvas que están encima.
  /// El resultado es una sola imagen movible con el sello + boceto integrados.
  Future<void> _flattenStampWithCanvas(String stampId) async {
    final imgModel = _controller.canvasImages
        .where((i) => i.id == stampId)
        .firstOrNull;
    if (imgModel == null) return;

    final layerIdx = _controller.layers
        .indexWhere((l) => l.id == imgModel.layerId);
    if (layerIdx == -1) return;

    final strokes = _controller.layers[layerIdx].strokes;
    // Strokes "encima" del sello = todos los que se dibujaron después de su insertionIndex
    final overlayIndices = <int>[];
    for (int i = imgModel.insertionIndex; i < strokes.length; i++) {
      overlayIndices.add(i);
    }

    final w = imgModel.rect.width.round().clamp(1, 4096);
    final h = imgModel.rect.height.round().clamp(1, 4096);

    // Renderizar sello + borrados + strokes encima en una imagen
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );

    // Trasladar para que el sello quede en origen (0,0)
    canvas.translate(-imgModel.position.dx, -imgModel.position.dy);

    final src = Rect.fromLTWH(
      0, 0,
      imgModel.image.width.toDouble(),
      imgModel.image.height.toDouble(),
    );

    // Dibujar sello con sus borrados
    if (!imgModel.hasErases) {
      canvas.drawImageRect(
        imgModel.image, src, imgModel.rect,
        Paint()..color = Colors.white.withOpacity(imgModel.opacity),
      );
    } else {
      canvas.saveLayer(imgModel.rect, Paint());
      canvas.drawImageRect(
        imgModel.image, src, imgModel.rect,
        Paint()..color = Colors.white.withOpacity(imgModel.opacity),
      );
      for (final erase in imgModel.eraseStrokes) {
        _drawEraseOnCanvas(canvas, erase);
      }
      canvas.restore();
    }

    // Dibujar strokes del canvas que están encima del sello
    for (final i in overlayIndices) {
      _drawStrokeOnCanvas(canvas, strokes[i]);
    }

    final picture = recorder.endRecording();
    final flatImage = await picture.toImage(w, h);

    // Actualizar controller: reemplazar sello y eliminar strokes acoplados
    _controller.flattenStamp(
      stampId,
      flatImage,
      overlayIndices,
      imgModel.layerId,
    );
    // FIX: re-seleccionar para que isSelected=true y los handles aparezcan
    _controller.selectCanvasImage(stampId);
  }

  void _drawEraseOnCanvas(ui.Canvas canvas, EraseStroke erase) {
    if (erase.points.isEmpty) return;
    final hardness = erase.hardness.clamp(0.0, 1.0);
    final r        = erase.radius;
    // Match shader: stop = hardness
    final stop     = hardness.clamp(0.0, 0.99);
    Paint erasePaint(Offset center) {
      if (stop <= 0.01) return Paint()..blendMode = BlendMode.dstOut..color = Colors.white;
      return Paint()
        ..shader = ui.Gradient.radial(center, r, [
          Colors.white, Colors.white, Colors.transparent,
        ], [0.0, stop, 1.0])
        ..blendMode = BlendMode.dstOut;
    }
    if (erase.points.length == 1) {
      canvas.drawCircle(erase.points.first, r, erasePaint(erase.points.first));
      return;
    }
    // Stamps individuales — consistente con shader GPU
    for (int i = 0; i < erase.points.length; i++) {
      canvas.drawCircle(erase.points[i], r, erasePaint(erase.points[i]));
      if (i > 0) {
        final dist  = (erase.points[i] - erase.points[i-1]).distance;
        final steps = (dist / (r * 0.3)).ceil().clamp(1, 8);
        for (int s = 1; s < steps; s++) {
          final p = Offset.lerp(erase.points[i-1], erase.points[i], s / steps)!;
          canvas.drawCircle(p, r, erasePaint(p));
        }
      }
    }
  }

  void _drawStrokeOnCanvas(ui.Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;
    final color = stroke.color.withOpacity(stroke.opacity);
    final paint = Paint()
      ..color = stroke.type == StrokeType.eraser
          ? Colors.transparent.withOpacity(0)
          : color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.type == StrokeType.eraser
          ? BlendMode.dstOut
          : BlendMode.srcOver;
    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2,
          paint..style = PaintingStyle.fill);
      return;
    }
    final path = ui.Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      final mid = Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  Future<void> _selectStamp(StampItem stamp) async {
    try {
      final data = await rootBundle.load(stamp.assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: DeviceProfile.instance.stampLoadSize,
        targetHeight: DeviceProfile.instance.stampLoadSize,
      );
      final frame = await codec.getNextFrame();
      setState(() {
        _activeStamp = stamp;
        _activeStampImage = frame.image;
        _stampMode = true;
        _showBrushPanel = false;
        // FIX: al seleccionar sello, limpiar transform mode y selección
        _transformMode = TransformMode.ninguno;
        _selectedImageId = null;
      });
      _controller.selectCanvasImage(null);
    } catch (e) {
      debugPrint('Error cargando sello: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sello "${stamp.name}" no disponible. Sube el archivo al repo.',
                style: const TextStyle(fontFamily: 'Raleway', fontSize: 12)),
            backgroundColor: const Color(0xFFE74C3C),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

  /// Spacing GPU por categoría de pincel.
  /// El spacing controla qué tan separados están los stamps:
  /// 0.03 = muy denso (línea sólida) | 0.25 = suelto (textura visible)
  // _spacingForBrush ELIMINADO — el motor C++ v3 calcula spacing dinámico
  // internamente: size * (0.04 + velocidad * 0.008). No duplicar aquí.

  /// Ancho fijo para la preview del pincel — independiente del TAM actual.
  static double _previewStrokeWidth(String id) {
    if (id.startsWith('aero_'))  return 6.0;  // aerógrafo: trazo grueso suave
    if (id.startsWith('car_'))   return 5.0;  // carboncillo: grosor medio
    if (id.startsWith('cal_'))   return 4.0;  // caligrafía: trazo variable
    if (id.startsWith('lum_'))   return 3.0;  // luminancia: trazo fino brillante
    if (id.startsWith('ret_'))   return 5.0;  // retoque: trazo suave
    if (id.startsWith('abs_'))   return 5.0;
    if (id.startsWith('tex_'))   return 5.0;
    if (id.startsWith('org_'))   return 4.0;
    if (id.startsWith('agua_'))  return 6.0;
    if (id.startsWith('ind_'))   return 4.0;
    if (id.startsWith('imp_'))   return 4.0;
    return 4.0;
  }

  Widget _buildBrushItem(BrushModel brush, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (isActive) {
          _showBrushAdjustSheet(brush);
          return;
        }
        _controller.setActiveBrush(brush);
        setState(() {
          // FIX: desactivar sello y transform mode al seleccionar pincel
          _stampMode = false;
          _activeStamp = null;
          _activeStampImage = null;
          _transformMode = TransformMode.ninguno;
          _selectedImageId = null;
          _controller.selectCanvasImage(null);
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
                  // Mostrar el PNG real de la textura como preview
                  _BrushTexturePreview(
                    brushId: brush.id,
                    brush: brush,
                    isActive: isActive,
                    strokeColor: isActive
                        ? Colors.white.withOpacity(0.9)
                        : _textSecondary,
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

  void _showBrushAdjustSheet(BrushModel brush) {
    showBrushAdjustSheet(
      context,
      brush,
      strokePreviewTitle: brush.name,
      onChanged: (updated) {
        _controller.setActiveBrush(updated);
        setState(() {});
      },
    );
  }

  Widget _buildSheetSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        SizedBox(
          width: 44,
          child: Text(label,
              style: const TextStyle(
                fontFamily: 'Raleway',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _textSecondary,
                letterSpacing: 1.2,
              )),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppTheme.accentRed,
              inactiveTrackColor: _borderColor,
              thumbColor: Colors.white,
              overlayColor: AppTheme.accentRed.withOpacity(0.2),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(displayValue,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Raleway',
                fontSize: 11,
                color: _textPrimary,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
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
              'Importa .tskbrush desde ThreeSkulls/pinceles/',
              () async {
                Navigator.pop(context);
                await _loadImportedBrushes();
                if (mounted) setState(() => _brushTab = BrushPanelTab.descargados);
              }),
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
      child: Listener(
        onPointerDown: (event) {
          // Solo contar punteros que empiezan EN el canvas.
          // Usar el ID del puntero para rastrear cuáles bajar en Up/Cancel.
          if (!_isTouchOnCanvas(event.localPosition)) return;
          _trackedPointers.add(event.pointer);
          _activePointers++;
          if (_activePointers > 1) {
            _cancelStrokeImmediately = true;
            _isDrawing = false;
            _pendingPoints.clear();
            _pendingStrokePoint = null;
            _mirrorLastPoint = null;
            _mirrorAccDist   = 0.0;
            _controller.cancelStroke();
            _confirmedSingleUpdates = 0;
            if (_nativeReady) _bridgeCall(() => _bridge.cancelStroke());
            // Limpiar erasingImageId para que onScaleUpdate no siga borrando la imagen
            if (_erasingImageId != null) {
              _controller.cancelEraseOnImage(_erasingImageId!);
              setState(() => _erasingImageId = null);
            }
          }
        },
        onPointerUp: (event) {
          // Decrementar SOLO si este puntero fue registrado en Down.
          // Evita desbalance cuando el dedo sale del canvas antes de levantarse.
          if (_trackedPointers.remove(event.pointer)) _activePointers--;
        },
        onPointerCancel: (event) {
          if (_trackedPointers.remove(event.pointer)) _activePointers--;
        },
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          // Guard: solo guardar posición si el tap está en el canvas
          if (!_isTouchOnCanvas(details.localPosition)) {
            _tapDownCanvasPos = null;
            return;
          }
          _tapDownCanvasPos = _screenToCanvas(details.localPosition);
        },
        onTap: () {
          // Guard: ignorar taps fuera del canvas (topbar, sidebar)
          if (_tapDownCanvasPos == null) return;
          if (_showBrushPanel) setState(() => _showBrushPanel = false);
          if (_showSelectionOptions) setState(() => _showSelectionOptions = false);
          if (_showColors) setState(() => _showColors = false);

          final tapPoint = _screenToCanvas(
            // onTap no tiene detalles de posición — usamos el centro de pantalla como fallback
            // En su lugar manejamos selección en onScaleStart con tap rápido
            Offset.zero,
          );

          // ── Sello: colocar con un tap ────────────────────
          if (_stampMode && _activeStampImage != null && _tapDownCanvasPos != null) {
            _controller.placeStampAtPosition(_activeStampImage!, _tapDownCanvasPos!, _stampSize);
            return;
          }

          // FIX: en transform mode, tap selecciona/deselecciona imagen
          if (_transformMode == TransformMode.activo) {
            final tapPos = _tapDownCanvasPos;
            if (tapPos != null) {
              // Si hay imagen en ese punto, seleccionarla
              final img = _controller.imageAtPoint(tapPos);
              if (img != null) {
                if (_selectedImageId != img.id) {
                  _controller.selectCanvasImage(img.id);
                  setState(() => _selectedImageId = img.id);
                }
                // Si ya estaba seleccionada, no hacer nada (mantener selección)
                return;
              }
              // Tap fuera de imagen → deseleccionar
              if (_selectedImageId != null) {
                _controller.selectCanvasImage(null);
                setState(() => _selectedImageId = null);
              }
            }
            return;
          }

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
          // FIX TOPBAR/OPACITY: ignorar toques fuera del área del canvas.
          // El GestureDetector cubre Positioned.fill (toda la pantalla).
          // Sin este guard, los toques en topbar, sliders y sidebar quedan
          // interceptados y no llegan a sus widgets.
          // Permitir 2 dedos (zoom) desde cualquier lugar de la pantalla.
          if (details.pointerCount < 2 && !_zoomMode &&
              !_isTouchOnCanvas(details.localFocalPoint)) {
            return;
          }

          // ── PRIORIDAD ABSOLUTA: 2 dedos = pan/zoom ───────
          if (details.pointerCount >= 2 || _zoomMode) {
            _controller.cancelStroke(); // FIX: cancelar (no guardar) al hacer zoom
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
              // FIX: inflate grande para que sea fácil tocar en móvil
              if (selImg.rect.inflate(80 / _scale).contains(relCp)) {
                _isDraggingImage = true;
                _lastDragCanvas = cp;
                return;
              }
            }
            _controller.selectCanvasImage(null);
            _selectedImageId = null;
            setState(() {});
            return; // FIX: no dibujar stroke al deseleccionar imagen
          }

          // ── Transform mode: tap = SOLO seleccionar (sin drag) ──
          // El drag inicia en el siguiente gesto sobre la imagen ya seleccionada
          if (_selectedImageId == null &&
              _selectionMode == SelectionMode.ninguno &&
              _transformMode == TransformMode.activo) {
            final img = _controller.imageAtPoint(cp);
            if (img != null) {
              _controller.selectCanvasImage(img.id);
              setState(() => _selectedImageId = img.id);
              return; // Solo seleccionar — NO iniciar drag todavía
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

          // Sello: manejado en onTap (tap único)

          // ── Borrador sobre sello/imagen: borra del sello directamente ──
          _strokeStartTime = DateTime.now();
          if (_controller.activeBrush.type == StrokeType.eraser) {
            final imgUnder = _controller.imageAtPoint(cp);
            if (imgUnder != null && imgUnder.layerId == _controller.activeLayerId) {
              _erasingImageId = imgUnder.id;
              // Limpiar pendingPoints para que no se envíen como stamps fantasma
              // al canvas cuando el gesto termina.
              _pendingPoints.clear();
              _pendingStrokePoint = null;
              _controller.startEraseOnImage(
                imgUnder.id, cp,
                _controller.activeBrush.size / _scale,
                // hardness field = OPA slider (fuerza del borrado)
                // El DUR (edge blur) se aplica fijo en _drawEraseStroke hasta que
                // canvas_image_model.dart tenga campo opacity separado.
                hardness: _controller.activeBrush.opacity.clamp(0.05, 1.0),
              );
              return;
            }
          }

          // ── Dibujo / Borrador sobre canvas ────────────────────────────
          // ⚠️ NO iniciar stroke aquí todavía — esperar onScaleUpdate
          // para garantizar que sea 1 solo dedo (anti puntos fantasma)
          _cancelStrokeImmediately = false;
          _isDrawing = false; // se activará en onScaleUpdate si es 1 dedo
          _pendingStrokePoint = cp; // guardar punto inicial para usarlo en update
        },
        onScaleUpdate: (details) {
          // ── PRIORIDAD ABSOLUTA: multitouch → pan/zoom, nunca stroke ──
          if (details.pointerCount >= 2 || _activePointers > 1) {
            _isDrawing = false;
            _pendingStrokePoint = null;
            _pendingPoints.clear();
            _controller.cancelStroke();
            _bridgeCall(() => _bridge.cancelStroke());
            if (!_isScaling) {
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
            // FIX: aplicar sensibilidad de zoom y zoom máximo
            final zoomDelta = (details.scale - 1.0) * _zoomSensitivity + 1.0;
            final newScale = (_startScale * zoomDelta).clamp(0.1, _maxZoom);
            // FIX: rotación libre — si está desactivada, mantener rotación actual
            final newRotation = _freeRotation
                ? _startRotation + details.rotation
                : _startRotation;
            // newOffset = screenFocal - R(newRotation) * S(newScale) * canvasFocal
            final cosR = cos(newRotation);
            final sinR = sin(newRotation);
            final cfx = _canvasFocalPoint.dx;
            final cfy = _canvasFocalPoint.dy;
            final newOffset = Offset(
              details.localFocalPoint.dx - (cfx * cosR - cfy * sinR) * newScale,
              details.localFocalPoint.dy - (cfx * sinR + cfy * cosR) * newScale,
            );
            // FIX: aplicar sensibilidad de pan
            final panDelta = newOffset - _offset;
            // Throttle: actualizar máx 60fps (evita flood de repaints)
            final frame = DateTime.now().millisecondsSinceEpoch;
            if (frame - _lastScaleFrame >= 16) { // ~60fps
              _lastScaleFrame = frame;
              setState(() {
                _scale = newScale;
                _offset = _offset + panDelta * _panSensitivity;
                _rotation = newRotation;
              });
            } else {
              // Actualizar variables sin setState — se renderizará en próximo frame
              _scale = newScale;
              _offset = _offset + panDelta * _panSensitivity;
              _rotation = newRotation;
            }
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
            // Handle 8 = rotación
            // Aplicamos AMBAS: incremental geométrica (mueve puntos) + visual (OBB)
            // Así strokes y bounding box giran simultáneamente.
            if (_activeResizeHandle == 8) {
              final center = _resizeStartBounds!.center;
              final angle = (cp - center).direction;
              final delta = angle - _selectionStartRotation;
              _selectionStartRotation = angle;
              _selectionAngle += delta;
              // Rotar puntos incrementalmente cada frame
              _controller.rotateSelected(center, delta);
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

          // ── Continuar borrado sobre imagen ───────────────
          if (_erasingImageId != null) {
            if (_cancelStrokeImmediately || _activePointers > 1) {
              // Segundo dedo detectado — abortar borrado de imagen
              _controller.cancelEraseOnImage(_erasingImageId!);
              setState(() => _erasingImageId = null);
              return;
            }
            _controller.continueEraseOnImage(_erasingImageId!, cp);
            return;
          }
          // FIX: si hay un sello bajo el cursor, no borrar el canvas allí
          // Así el canvas queda limpio cuando se mueve el sello
          if (_controller.activeBrush.type == StrokeType.eraser) {
            final imgUnder = _controller.imageAtPoint(cp);
            if (imgUnder != null && imgUnder.layerId == _controller.activeLayerId) {
              // Hay un sello aquí — redirigir al sello en lugar de canvas
              _controller.endStroke(); // terminar stroke canvas
              _erasingImageId = imgUnder.id;
              _controller.startEraseOnImage(
                imgUnder.id, cp,
                _controller.activeBrush.size / _scale,
                // hardness field = OPA slider (fuerza del borrado)
                // El DUR (edge blur) se aplica fijo en _drawEraseStroke hasta que
                // canvas_image_model.dart tenga campo opacity separado.
                hardness: _controller.activeBrush.opacity.clamp(0.05, 1.0),
              );
              return;
            }
          }

          // ── Iniciar o continuar stroke (solo 1 dedo confirmado) ──
          if (_cancelStrokeImmediately || _activePointers > 1) {
            _isDrawing = false;
            _pendingStrokePoint = null;
            _controller.cancelStroke();
            return;
          }

          if (!_isDrawing) {
            // C++ v3 tiene su propio buffer Catmull-Rom interno.
            // Iniciar stroke en el primer punto confirmado con 1 dedo.
            _pendingPoints.add(cp);
            if (_pendingPoints.length >= 1) {
              _isDrawing = true;
              _hideBrushPreview(); // ocultar size preview al dibujar
              _controller.startStroke(_pendingPoints.first);
              final _brush = _controller.activeBrush;
              final _dbgX = _pendingPoints.first.dx;
              final _dbgY = _pendingPoints.first.dy;
              _lastBridgeCoords =
                  'begin x=${_dbgX.toStringAsFixed(1)} y=${_dbgY.toStringAsFixed(1)}\n'
                  'scale=$_scale off=(${_offset.dx.toStringAsFixed(0)},${_offset.dy.toStringAsFixed(0)})\n'
                  'brushSz=${_brush.size.toStringAsFixed(2)} (canvas px)\n'
                  'DART canvasSize=${_controller.canvasSize.width.toInt()}x${_controller.canvasSize.height.toInt()}\n'
                  'scale=$_scale DPR=${MediaQuery.of(context).devicePixelRatio.toStringAsFixed(2)}';

                _confirmedSingleUpdates = 0; // reset — 1 update confirmado es suficiente
              _mirrorLastPoint = null;
              _mirrorAccDist  = 0.0;
              // Resolver textura GPU: PNG cargado > textura orgánica interna > Gaussian
              int _gpuTexId = GpuBrushLoader.shapeTexId(_brush.id);
              if (_gpuTexId < 0) {
                final id = _brush.id;
                if      (id.startsWith('aero_'))                       _gpuTexId = -10;
                else if (id.startsWith('car_'))                        _gpuTexId = -11;
                else if (id.startsWith('cal_'))                        _gpuTexId = -12;
                else if (id.startsWith('lum_'))                        _gpuTexId = -14;
                else if (id.startsWith('agua_'))                       _gpuTexId = -15;
                else if (id.startsWith('tex_') || id.startsWith('org_'))  _gpuTexId = -13;
                else if (id.startsWith('ret_') || id.startsWith('abs_') ||
                         id.startsWith('ind_') || id.startsWith('imp_')) _gpuTexId = -12;
              }
              // Nota: spacing ya NO se pasa desde Dart — el motor C++ v3 lo
              // calcula dinámicamente (0.04 × size × factor velocidad)
              // Spacing per categoría: más separado → stamps visibles → textura real
              // Aerógrafo: 0.05 (denso = suave) | Carboncillo: 0.20 (suelto = rugoso)
              // Caligrafía: 0.04 (muy denso = línea sólida) | Luminancia: 0.06
              _bridgeCall(() => _bridge.beginStroke(
                layerId:    _nativeLayer(_controller.activeLayerId),
                x: _dbgX, y: _dbgY,
                size:       _brush.size + 5.0,
                opacity:    _brush.opacity,
                hardness:   _brush.hardness,
                isEraser:   _brush.type == StrokeType.eraser,
                brushTexId: _gpuTexId,
                color:      _controller.activeColor,
              ));
              // _pendingPoints eliminado — C++ maneja buffer interno
              _pendingStrokePoint = null;
            }
          } else {
            _controller.continueStroke(cp);
            _bridgeCall(() => _bridge.addPoint(cp.dx, cp.dy));
            // ERASER + simetría: el espejo se envía explícitamente desde Dart.
            // El C++ maneja el espejo del pincel internamente, pero para el borrador
            // hay un bug conocido en el shader/blend — más confiable enviarlo desde Dart.
            if (_controller.activeBrush.type == StrokeType.eraser && _controller.symmetryEnabled) {
              _sendMirrorStamp(cp);
            }
            // Export GPU cada 5 puntos para preview en tiempo real de TODOS los pinceles.
            // El overlay Dart era impreciso vs GPU. Export directo = resultado exacto.
            // Throttle: evita exportar más de 1 vez cada 32ms (~30fps max).
            _eraseExportCounter++;
            if (_eraseExportCounter % 20 == 0) {
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - _lastExportMs >= 32) {
                _lastExportMs = now;
                _bridgeImageCall(() => _bridge.exportCanvas());
              }
            }
          }
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
            // Reset selectionAngle: los puntos ya fueron rotados incrementalmente
            setState(() {
              _isResizingHandle = false;
              _activeResizeHandle = -1;
              _resizeStartBounds = null;
              _resizeHandleStart = null;
              _selectionAngle = 0.0;
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
            if (_erasingImageId != null) {
              final idToBake = _erasingImageId!;
              _controller.endEraseOnImage(idToBake);
              setState(() => _erasingImageId = null);
              // Programar bake DESPUÉS del frame actual — evita conflicto raster
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _bakeErases(idToBake);
              });
            } else {
              _strokeStartTime = null;
              _isDrawing = false;
              if (_cancelStrokeImmediately) {
                _cancelStrokeImmediately = false;
                _pendingPoints.clear();
                _controller.cancelStroke();
                _bridgeCall(() => _bridge.cancelStroke());
              } else {
                // Delayed commit: esperar microtask para que _activePointers se actualice
                Future.microtask(() {
                  if (!mounted) return;
                  final stroke = _controller.currentStroke;
                  // Validación: descartar si 2+ dedos, stroke inválido o muy corto
                  final isValid = stroke != null &&
                      stroke.points.length > 2 &&
                      _activePointers <= 1;
                  if (isValid) {
                    _pendingPoints.clear(); // FIX PUNTOS FANTASMAS: limpiar también en path válido
                    // FIX BLINK: el overlay usa currentStroke para preview en tiempo real.
                    // Si llamamos controller.endStroke() ANTES de obtener la imagen GPU,
                    // currentStroke=null → overlay desaparece → frame en blanco antes de
                    // que llegue _nativeCanvasImage → el trazo "parpadea".
                    // Solución: bridge obtiene la imagen, LUEGO endStroke limpia el overlay.
                    final _strokeSnapshot = _controller.currentStroke;
                    // FIX SIMETRÍA: el mirror ya lo maneja StrokeEngine C++
                    // (jniSetSymmetry → renderStampAt duplicado). No hay replay Dart.
                    _confirmedSingleUpdates = 0;
                    _mirrorLastPoint = null;
                    _mirrorAccDist  = 0.0;
                    _bridge.endStroke().then((img) {
                      if (!mounted) return;
                      _controller.endStroke();
                      if (img != null) setState(() => _nativeCanvasImage = img);
                    }).catchError((_) {
                      if (mounted) _controller.endStroke();
                    });
                    // FIX DIAG: obtener g_lastError de C++ (contiene canvasSize real)
                    Future.microtask(() async {
                      try {
                        const diagCh = MethodChannel('tsk/drawing_engine');
                        final err = await diagCh.invokeMethod<String>('getLastError');
                        if (mounted && err != null) setState(() => _lastGpuStatus = err);
                      } catch (_) {}
                    });
                  } else {
                    // FIX PUNTOS FANTASMAS: limpiar _pendingPoints en TODOS los paths.
                    // Si el dedo se levanta antes de acumular 3 puntos, _pendingPoints
                    // queda con 1-2 puntos. El próximo trazo los hereda y aparecen
                    // como puntos sueltos en posiciones incorrectas (fantasmas).
                    _pendingPoints.clear();
                    _controller.cancelStroke();
                    _bridgeCall(() => _bridge.cancelStroke());
                  }
                });
              }
            }
          }
          _isScaling = false;
        },
        child: Stack(children: [
          // ── RENDERIZADO: nativo (GPU) o Dart (fallback) ────────────
          AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.identity()
                ..translate(_offset.dx, _offset.dy)
                ..rotateZ(_rotation)
                ..scale(_scale),
              // FIX ROOT: el inner Stack heredaba las constraints del padre (411×890dp),
              // haciendo que Container/RawImage/overlay se clippearan a ese tamaño.
              // Transform(scale=0.35) entonces escalaba 411×890 → 144×311dp en pantalla
              // en lugar del 1080×1920 * 0.35 = 378×672dp correcto.
              // OverflowBox: permite que SizedBox(canvasWidth×canvasHeight) ignore
              // los constraints del padre (screen size) y use sus dimensiones reales.
              // Sin esto, el inner Stack se limita a ~411×890dp y la imagen GPU se
              // distorsiona. Hit testing se controla vía _isTouchOnCanvas guards.
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: SizedBox(
                  width:  _controller.canvasSize.width,
                  height: _controller.canvasSize.height,
                  child: Stack(
                children: [

                  // ── PRIMER hijo: fondo del canvas (debajo de todo) ──────
                  // FIX: debe ser el primer hijo para que quede DEBAJO del RawImage.
                  // Sin él, los píxeles transparentes del GPU (áreas borradas o sin
                  // dibujo) muestran el _bgColor gris del Scaffold.
                  // Cuando backgroundColor == transparent → papel blanco.
                  Container(
                    width:  _controller.canvasSize.width,
                    height: _controller.canvasSize.height,
                    color: _controller.backgroundColor == Colors.transparent
                        ? Colors.white
                        : _controller.backgroundColor,
                  ),

                  // ── SEGUNDO hijo: imagen C++ (GPU canvas) ───────────────
                  if (_nativeReady && _nativeCanvasImage != null)
                    RepaintBoundary(
                      // FIX DPR: ui.Image tiene 1080px físicos. RawImage(width:1080dp)
                      // los upscalea DPR veces → stamps GPU 2.75x más grandes que el overlay.
                      // Sin width/height explícitos, Flutter usa la escala nativa del
                      // dispositivo: la imagen se muestra a tamaño natural (1px=1dp*DPR
                      // → 1px ocupa 1dp lógico). PositionedFill + fit:fill mantiene la
                      // misma área visual que el overlay CustomPaint del SizedBox.
                      child: SizedBox.expand(
                        child: RawImage(
                          image:  _nativeCanvasImage,
                          fit:    BoxFit.fill,
                        ),
                      ),
                    ),
                  // ── Overlay permanente: grid / guías / simetría / imágenes importadas ──
                  // Siempre visible sobre el RawImage. Usa CanvasOverlayPainter que no
                  // dibuja strokes (esos los maneja el GPU), solo los elementos de UI
                  // que antes vivían en CanvasPainter (solo !nativeReady).
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter: CanvasOverlayPainter(
                        controller: _controller,
                        paintVersion: _controller.paintVersion,
                        showGrid: _showGrid,
                        showCenterGuides: _showCenterGuides,
                        showSymmetryLine: _controller.symmetryEnabled,
                        currentMirrorStroke: _controller.currentMirrorStroke,
                      ),
                      size: Size(
                        _controller.canvasSize.width,
                        _controller.canvasSize.height,
                      ),
                    ),
                  ),

                  // OVERLAY ELIMINADO: el GPU exporta cada 5 puntos durante el trazo.
                  // Más fiable que el overlay Dart que nunca coincidía exactamente
                  // con el resultado GPU (diferente algoritmo de renderizado).
                  // ── Fallback: renderer Dart solo cuando GPU no está listo ──
                  // FIX: sin condición !_nativeReady, el Dart painter sobreescribía el RawImage
                  // del GPU, anulando visualmente DUR y el borrador del motor C++.
                  if (!_nativeReady)
                    CustomPaint(
                      painter: CanvasPainter(
                        layers: _controller.layers,
                        currentStroke: _controller.currentStroke,
                        currentMirrorStroke:
                            _controller.currentMirrorStroke,
                        showGrid: _showGrid,
                        showCenterGuides: _showCenterGuides,
                        showSymmetryLine:
                            _controller.symmetryEnabled,
                        symmetryEnabled:
                            _controller.symmetryEnabled,
                        activeLayerId: _controller.activeLayerId,
                        controller: _controller,
                        // FIX: mientras el motor GPU inicializa, mostrar blanco
                        // en lugar de Colors.transparent (→ checkerboard 12px
                        // → a 44% zoom parece gris oscuro uniforme).
                        backgroundColor:
                            _controller.backgroundColor == Colors.transparent
                                ? Colors.white
                                : _controller.backgroundColor,
                      ),
                      size: Size(
                        _controller.canvasSize.width,
                        _controller.canvasSize.height,
                      ),
                    ),

                  // ── Overlay de selección (CPU — sin cambios) ──────
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
                        obbBounds: _activeResizeHandle == 8
                            ? _resizeStartBounds
                            : null,
                      ),
                      size: Size(
                        _controller.canvasSize.width,
                        _controller.canvasSize.height,
                      ),
                    ),
                ],
              ),
                ), // SizedBox(canvasSize)
              ), // OverflowBox
            );
          },
        ),
        ]),
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
      onLongPressStart: (d) => _showTooltip('Restablecer zoom', d.globalPosition),
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
      onLongPressStart: (d) => _showTooltip('Pantalla completa', d.globalPosition),
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
                      // FIX: sincronizar GPU con el nuevo tamaño del canvas.
                      // Sin esta llamada, el GPU queda en el tamaño anterior
                      // y la RawImage se muestra comprimida/desalineada.
                      _bridgeCall(() => _bridge.setCanvasSize(w.toInt(), h.toInt()));
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

  /// Envía un stamp al espejo del borrador con espaciado correcto.
  /// Replica el spacing del StrokeEngine C++: size * 0.08.
  /// Sin esto stampAt se llama cada evento táctil → mucho más denso que el trazo principal.
  void _sendMirrorStamp(Offset p) {
    final cw = _controller.canvasSize.width;
    final ch = _controller.canvasSize.height;
    final isVert = _controller.symmetryType == SymmetryType.vertical;
    final mx = isVert ? p.dx : cw - p.dx;
    final my = isVert ? ch - p.dy : p.dy;
    final mirror = Offset(mx, my);
    // Spacing espejo igual al motor C++ v3: 4% del tamaño
    final spacing = (_controller.activeBrush.size + 5.0) * 0.04;

    if (_mirrorLastPoint == null) {
      _mirrorLastPoint = mirror;
      _mirrorAccDist = 0.0;
      _bridgeCall(() => _bridge.stampAt(mx, my));
      return;
    }

    final dx = mirror.dx - _mirrorLastPoint!.dx;
    final dy = mirror.dy - _mirrorLastPoint!.dy;
    final dist = sqrt(dx * dx + dy * dy);
    _mirrorAccDist += dist;

    while (_mirrorAccDist >= spacing) {
      final t = (dist - (_mirrorAccDist - spacing)) / dist.clamp(0.001, double.infinity);
      final sx = _mirrorLastPoint!.dx + dx * t;
      final sy = _mirrorLastPoint!.dy + dy * t;
      final capSx = sx; final capSy = sy;
      _bridgeCall(() => _bridge.stampAt(capSx, capSy));
      _mirrorAccDist -= spacing;
    }

    _mirrorLastPoint = mirror;
  }

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

  // ─── GUARDAR PROYECTO .tskproject ────────────────────────────────────────────

  // ── Cargar pinceles .tskbrush del almacenamiento ─────────────────────────────
  Future<void> _loadImportedBrushes() async {
    if (!StorageManager.instance.isInitialized) return;
    try {
      final paths = await StorageManager.instance.listBrushFiles();
      final loaded = <BrushModel>[];
      for (final path in paths) {
        try {
          // file bytes loaded in _parseTskBrush
          // Leer brush.json del ZIP
          // file parsed below
          // Parsear directamente con ZipDecoder de dart (archive package)
          // Por ahora cargar como BrushModel básico desde el nombre del archivo
          final fileName = path.split('/').last.replaceAll('.tskbrush', '');
          // Intentar leer brush.json del archivo ZIP
          final model = await _parseTskBrush(path, fileName);
          if (model != null) loaded.add(model);
        } catch (e) {
          debugPrint('Error loading brush $path: $e');
        }
      }
      if (mounted) setState(() => _importedBrushes = loaded);
      debugPrint('Imported brushes loaded: ${loaded.length}');
    } catch (e) {
      debugPrint('_loadImportedBrushes error: $e');
    }
  }

  Future<BrushModel?> _parseTskBrush(String path, String fallbackId) async {
    try {
      final bytes = await File(path).readAsBytes();
      // Leer ZIP manualmente buscando brush.json
      // Los primeros 4 bytes de cada entry ZIP son 50 4B 03 04
      final data = bytes;
      int pos = 0;
      while (pos < data.length - 4) {
        if (data[pos] == 0x50 && data[pos+1] == 0x4B &&
            data[pos+2] == 0x03 && data[pos+3] == 0x04) {
          // Local file header
          final nameLen = data[pos+26] | (data[pos+27] << 8);
          final extraLen = data[pos+28] | (data[pos+29] << 8);
          final compSize = data[pos+18] | (data[pos+19] << 8) |
                          (data[pos+20] << 16) | (data[pos+21] << 24);
          final name = String.fromCharCodes(data.sublist(pos+30, pos+30+nameLen));
          final dataStart = pos + 30 + nameLen + extraLen;

          if (name == 'brush.json' && dataStart + compSize <= data.length) {
            final jsonBytes = data.sublist(dataStart, dataStart + compSize);
            final json = jsonDecode(String.fromCharCodes(jsonBytes)) as Map<String, dynamic>;
            return BrushModel.fromJson(json);
          }
          pos = dataStart + compSize;
        } else {
          pos++;
        }
      }
    } catch (e) {
      debugPrint('_parseTskBrush error: $e');
    }
    // Fallback: crear modelo básico con el nombre del archivo
    return BrushModel(
      id: fallbackId,
      name: fallbackId.replaceAll('_', ' ').split(' ').map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' '),
      emoji: '🖌️',
      type: StrokeType.liner,
      category: BrushCategory.importado,
    );
  }

  Widget _buildProjectMenuBtn() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      icon: const Icon(Icons.save_outlined, color: AppTheme.accentRed, size: 22),
      tooltip: 'Proyecto',
      onSelected: (value) {
        if (value == 'save')   _saveProject();
        if (value == 'open')   _showOpenProjectDialog();
        if (value == 'export') _saveDesign();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'save',
          child: Row(children: [
            const Icon(Icons.save_outlined, color: AppTheme.accentRed, size: 18),
            const SizedBox(width: 10),
            const Text('Guardar proyecto',
                style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
          ])),
        PopupMenuItem(value: 'open',
          child: Row(children: [
            const Icon(Icons.folder_open_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            const Text('Abrir proyecto',
                style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
          ])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'export',
          child: Row(children: [
            const Icon(Icons.ios_share_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            const Text('Exportar / Compartir',
                style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
          ])),
      ],
    );
  }

  Future<void> _saveProject() async {
    // Mostrar diálogo de nombre si es proyecto nuevo
    if (_projectId == null) {
      final name = await _showProjectNameDialog(_projectName);
      if (name == null) return; // cancelado
      _projectName = name;
    }

    // Mostrar progreso
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accentRed),
      ),
    );

    try {
      // 1. Obtener píxeles del canvas del motor C++
      final pixels = _nativeReady ? await _bridge.exportPixels() : null;
      final w = _controller.canvasSize.width.toInt();
      final h = _controller.canvasSize.height.toInt();

      // 2. Generar thumbnail (escalar a 256px de ancho)
      Uint8List? thumbnail;
      if (pixels != null) {
        try {
          final buf  = await ui.ImmutableBuffer.fromUint8List(pixels);
          final desc = ui.ImageDescriptor.raw(
            buf, width: w, height: h,
            pixelFormat: ui.PixelFormat.rgba8888,
          );
          final codec = await desc.instantiateCodec(
            targetWidth: 256,
            targetHeight: (h * 256 / w).round(),
          );
          final frame    = await codec.getNextFrame();
          final thumbImg = frame.image;
          final bd = await thumbImg.toByteData(format: ui.ImageByteFormat.png);
          thumbnail = bd?.buffer.asUint8List();
        } catch (_) {}
      }

      // 3. Construir capas con píxeles
      final layers = _controller.layers.map((l) => TskLayerData(
        id:        l.id,
        name:      l.name,
        opacity:   l.opacity,
        isVisible: l.isVisible,
        isLocked:  l.isLocked,
        pixelData: (l.id == _controller.activeLayerId) ? pixels : null,
      )).toList();

      // 4. Crear o actualizar modelo de proyecto
      final project = TskProjectModel(
        id:                  _projectId ?? const Uuid().v4(),
        name:                _projectName,
        canvasWidth:         w,
        canvasHeight:        h,
        backgroundColorARGB: _controller.backgroundColor.value,
        layers:              layers,
        activeLayerId:       _controller.activeLayerId,
        activeBrushId:       _controller.activeBrush.id,
        activeBrushSize:     _controller.activeBrush.size,
        activeBrushOpacity:  _controller.activeBrush.opacity,
        activeColorARGB:     _controller.activeColor.value,
      );
      _projectId = project.id;

      // 5. Guardar
      final result = await TskProjectService.save(
        project,
        layerPixels: pixels != null
            ? {_controller.activeLayerId: pixels}
            : {},
        thumbnail: thumbnail,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // cerrar loading

      if (result == SaveResult.ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('💾 "$_projectName" guardado'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al guardar el proyecto'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      debugPrint('_saveProject error: $e');
    }
  }

  Future<String?> _showProjectNameDialog(String current) async {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Nombre del proyecto',
            style: TextStyle(color: Colors.white, fontFamily: 'BlackOpsOne')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Sin título',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accentRed)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accentRed, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? 'Sin título' : ctrl.text.trim()),
            child: const Text('Guardar', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }

  // ─── ABRIR PROYECTO ───────────────────────────────────────────────────────────

  Future<void> _showOpenProjectDialog() async {
    final projects = await TskProjectService.listProjects();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('PROYECTOS',
                style: TextStyle(
                  fontFamily: 'BlackOpsOne', fontSize: 14,
                  color: Colors.white, letterSpacing: 2,
                )),
            const SizedBox(height: 8),
            Expanded(
              child: projects.isEmpty
                  ? const Center(
                      child: Text('No hay proyectos guardados',
                          style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: sc,
                      itemCount: projects.length,
                      itemBuilder: (_, i) {
                        final p = projects[i];
                        return ListTile(
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: p.thumbnail != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(p.thumbnail!,
                                        fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.image_outlined,
                                    color: Colors.white38),
                          ),
                          title: Text(p.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Raleway',
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${p.formattedDate} · ${p.formattedSize}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () async {
                              await TskProjectService.delete(p.id);
                              Navigator.pop(ctx);
                              _showOpenProjectDialog();
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _loadProject(p.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProject(String projectId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accentRed),
      ),
    );

    try {
      final loaded = await TskProjectService.load(projectId);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (loaded.result != LoadResult.ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al abrir el proyecto'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final p = loaded.project;
      _projectId   = p.id;
      _projectName = p.name;

      // Restaurar tamaño del canvas
      _controller.updateCanvasSize(
          Size(p.canvasWidth.toDouble(), p.canvasHeight.toDouble()));

      // Restaurar fondo
      _controller.backgroundColor = Color(p.backgroundColorARGB);

      // Restaurar píxeles al motor C++ si están disponibles
      if (_nativeReady) {
        for (final layer in p.layers) {
          if (layer.pixelData != null && layer.pixelData!.isNotEmpty) {
            // Restaurar imagen de la capa al motor
            final img = await _bridge.restoreLayer(
              layerId:   layer.id,
              pixels:    layer.pixelData!,
              width:     p.canvasWidth,
              height:    p.canvasHeight,
            );
            if (img != null) setState(() {});
          }
        }
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('📂 "${p.name}" abierto'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      debugPrint('_loadProject error: $e');
    }
  }

  void _saveDesign() {
    _showExportDialog();
  }

  // ─── EXPORTAR DISEÑO ──────────────────────────────────────
  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ExportBottomSheet(
        onExport: (format, transparent, targetApp) async {
          Navigator.pop(ctx);
          await _exportCanvas(
              format: format,
              transparent: transparent,
              targetApp: targetApp);
        },
      ),
    );
  }

  Future<void> _exportCanvas({
    required String format, // 'png' | 'jpg'
    required bool transparent,
    String? targetApp, // 'gallery' | 'whatsapp' | 'instagram' | 'facebook' | 'share'
  }) async {
    // Mostrar loading
    _showExportLoading();

    try {
      final w = _controller.canvasSize.width.toInt();
      final h = _controller.canvasSize.height.toInt();

      // Renderizar el canvas a imagen usando el painter
      final recorder = ui.PictureRecorder();
      final exportCanvas = ui.Canvas(recorder);

      // Fondo
      if (!transparent || format == 'jpg') {
        exportCanvas.drawRect(
          ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Paint()..color = _controller.backgroundColor == Colors.transparent
              ? Colors.white
              : _controller.backgroundColor,
        );
      }

      ui.Image image;

      // ── Fase 2: exportar desde motor nativo cuando está disponible ──
      if (_nativeReady) {
        final pixels = await _bridge.exportPixels();
        if (pixels != null && pixels.isNotEmpty) {
          // Recibimos RGBA raw del motor C++
          final codec = await ui.ImmutableBuffer.fromUint8List(pixels);
          final descriptor = await ui.ImageDescriptor.raw(
            codec,
            width: w, height: h,
            pixelFormat: ui.PixelFormat.rgba8888,
          );
          final frameCodec = await descriptor.instantiateCodec();
          final frame = await frameCodec.getNextFrame();
          image = frame.image;
        } else {
          // Fallback si exportPixels falla
          final painter = CanvasPainter(
            layers: _controller.layers, controller: _controller,
            backgroundColor: transparent && format == 'png' ? Colors.transparent
                : (_controller.backgroundColor == Colors.transparent ? Colors.white : _controller.backgroundColor),
            currentStroke: null, currentMirrorStroke: null,
            activeLayerId: _controller.activeLayerId,
            showGrid: false, symmetryEnabled: false, showSymmetryLine: false,
          );
          painter.paint(exportCanvas, Size(w.toDouble(), h.toDouble()));
          final picture = recorder.endRecording();
          image = await picture.toImage(w, h);
        }
      } else {
        // ── Fallback: renderer Dart ──────────────────────────────────
        final painter = CanvasPainter(
          layers: _controller.layers, controller: _controller,
          backgroundColor: transparent && format == 'png' ? Colors.transparent
              : (_controller.backgroundColor == Colors.transparent ? Colors.white : _controller.backgroundColor),
          currentStroke: null, currentMirrorStroke: null,
          activeLayerId: _controller.activeLayerId,
          showGrid: false, symmetryEnabled: false, showSymmetryLine: false,
        );
        painter.paint(exportCanvas, Size(w.toDouble(), h.toDouble()));
        final picture = recorder.endRecording();
        image = await picture.toImage(w, h);
      }
      final byteData = await image.toByteData(
        format: format == 'png'
            ? ui.ImageByteFormat.png
            : ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) throw Exception('Error al renderizar imagen');

      Uint8List bytes;
      if (format == 'png') {
        bytes = byteData.buffer.asUint8List();
      } else {
        // Convertir RGBA a JPG usando canvas
        final codec = await ui.instantiateImageCodec(
          byteData.buffer.asUint8List(),
          targetWidth: w,
          targetHeight: h,
        );
        final frame = await codec.getNextFrame();
        final jpgData = await frame.image.toByteData(
            format: ui.ImageByteFormat.png); // usamos PNG y avisamos
        bytes = jpgData!.buffer.asUint8List();
      }

      // Guardar en directorio temporal y compartir
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'three_skulls_$timestamp.$format';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // cerrar loading

      if (targetApp == 'gallery') {
        // Guardar directo en galería
        await Gal.putImage(file.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFF1A1A1A),
            content: const Row(children: [
              Text('✅', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Text('Guardado en galería',
                  style: TextStyle(color: Colors.white, fontFamily: 'Raleway')),
            ]),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else {
        // Compartir via share sheet (muestra todas las apps)
        // Para apps específicas, Android filtra automáticamente si están instaladas
        final xFile = XFile(file.path,
            mimeType: format == 'png' ? 'image/png' : 'image/jpeg');
        
        if (targetApp == 'whatsapp') {
          await Share.shareXFiles([xFile],
              subject: 'Three Skulls Tattoo',
              sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100));
        } else if (targetApp == 'instagram') {
          await Share.shareXFiles([xFile],
              subject: 'Three Skulls Tattoo — diseño de tatuaje');
        } else {
          // Share general — muestra todas las apps
          await Share.shareXFiles([xFile],
              subject: 'Three Skulls Tattoo — $fileName');
        }
      }

    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade900,
        content: Text('Error al exportar: $e',
            style: const TextStyle(color: Colors.white)),
      ));
    }
  }

  void _showExportLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          color: Color(0xFF1A1A1A),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFE74C3C)),
                SizedBox(height: 16),
                Text('Exportando...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
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
            // FIX: borrar selección en GPU (eraseRegion) + Dart
            if (_nativeReady && _finalizedStart != null && _finalizedEnd != null) {
              final nId = _nativeLayer(_controller.activeLayerId);
              if (nId != null) {
                final r = Rect.fromPoints(_finalizedStart!, _finalizedEnd!);
                _bridgeImageCall(() => _bridge.eraseRegion(
                  nId, r.left, r.top, r.width, r.height));
              }
            }
            _controller.deleteSelected();
            setState(() => _clearSelectionState());
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                  // Acoplar: fusiona sello + strokes encima en una sola imagen
                  _selectionAction(Icons.merge_type, 'Acoplar', () {
                    _flattenStampWithCanvas(imgId);
                  }),
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
                    setState(() {
                      _selectedImageId = null;
                      // FIX: limpiar transform mode al eliminar sello
                      _transformMode = TransformMode.ninguno;
                    });
                  }, isDestructive: true),
                  // Listo
                  _selectionAction(Icons.check, 'Listo', () {
                    _controller.selectCanvasImage(null);
                    setState(() => _selectedImageId = null);
                  }),
                  ],
                ),
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


/// Preview que muestra el PNG real de la textura del pincel.
/// Si la textura no está disponible, cae al trazo Dart por categoría.
class _BrushTexturePreview extends StatefulWidget {
  final String brushId;
  final BrushModel brush;
  final bool isActive;
  final Color strokeColor;

  const _BrushTexturePreview({
    required this.brushId,
    required this.brush,
    required this.isActive,
    required this.strokeColor,
  });

  @override
  State<_BrushTexturePreview> createState() => _BrushTexturePreviewState();
}

class _BrushTexturePreviewState extends State<_BrushTexturePreview> {
  ui.Image? _tip;

  static String? _shapePath(String brushId) {
    final num = int.tryParse(brushId.split('_').last) ?? 1;
    final n = num.toString().padLeft(2, '0');
    if (brushId.startsWith('aero_') || brushId.startsWith('aers_'))
      return 'assets/Brushes/aerosoles/aers_${n}_shape.png';
    if (brushId.startsWith('cal_'))
      return 'assets/Brushes/caligrafia/cali_${n}_shape.png';
    if (brushId.startsWith('carb_') || brushId.startsWith('car_'))
      return 'assets/Brushes/carboncillo/carb_${n}_shape.png';
    if (brushId.startsWith('lum_'))
      return 'assets/Brushes/luminancia/lumi_${n}_shape.png';
    if (brushId.startsWith('ret_'))
      return 'assets/Brushes/retoque/ret_${n}_shape.png';
    return null;
  }

  @override
  void initState() {
    super.initState();
    // PNG tips no se usan en preview — fallback por categoría se ve mejor
  }

  Future<void> _loadTip() async {
    final path = _shapePath(widget.brushId);
    if (path == null) return;
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 128,
        targetHeight: 128,
      );
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _tip = frame.image);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        size: const Size(double.infinity, 28),
        painter: _BrushStrokePreviewPainter(
          tip: _tip,
          color: widget.strokeColor,
          brush: widget.brush,
        ),
      ),
    );
  }
}

class _BrushStrokePreviewPainter extends CustomPainter {
  final ui.Image? tip;
  final Color color;
  final BrushModel brush;

  _BrushStrokePreviewPainter({
    required this.tip,
    required this.color,
    required this.brush,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.02, h * 0.78);
    path.cubicTo(w * 0.25, h * 0.05, w * 0.55, h * 0.95, w * 0.80, h * 0.15);
    path.lineTo(w * 0.98, h * 0.45);

    if (tip != null) {
      _stampAlongPath(canvas, path, size);
    } else {
      _drawFallback(canvas, path, size);
    }
  }

  void _stampAlongPath(Canvas canvas, Path path, Size size) {
    final tipSize = size.height * 1.5;
    final spacing = (tipSize * 0.28).clamp(1.0, double.infinity);
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcATop)
      ..filterQuality = FilterQuality.medium;

    for (final metric in path.computeMetrics()) {
      double pos = 0;
      while (pos <= metric.length) {
        final tangent = metric.getTangentForOffset(pos);
        if (tangent != null) {
          final dst = Rect.fromCenter(
              center: tangent.position, width: tipSize, height: tipSize);
          final src = Rect.fromLTWH(
              0, 0, tip!.width.toDouble(), tip!.height.toDouble());
          canvas.drawImageRect(tip!, src, dst, paint);
        }
        pos += spacing;
      }
    }
  }

  void _drawFallback(Canvas canvas, Path path, Size size) {
    final id = brush.id;
    final sw = size.height * 0.35;

    if (brush.type == StrokeType.dotwork) {
      final p = Paint()..color = color..style = PaintingStyle.fill;
      double x = 3;
      while (x < size.width - 3) {
        canvas.drawCircle(Offset(x, size.height / 2), sw / 2, p);
        x += sw * 2.8;
      }
      return;
    }

    if (id.startsWith('aero_')) {
      for (double r = sw * 2; r >= 1; r -= 2) {
        canvas.drawPath(path, Paint()
          ..color = color.withOpacity(0.07)
          ..strokeWidth = r
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
      }
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = sw * 0.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke);
    } else if (id.startsWith('cal_')) {
      final metric = path.computeMetrics().first;
      const segs = 20;
      for (int i = 0; i < segs; i++) {
        final seg = metric.extractPath(
            (i / segs) * metric.length,
            ((i + 1) / segs) * metric.length);
        final p = sin((i / segs) * pi);
        canvas.drawPath(seg, Paint()
          ..color = color
          ..strokeWidth = sw * (0.2 + p * 0.9)
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
      }
    } else if (id.startsWith('lum_')) {
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity(0.15)
        ..strokeWidth = sw * 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..style = PaintingStyle.stroke);
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity(0.9)
        ..strokeWidth = sw * 0.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke);
    } else {
      canvas.drawPath(path, Paint()
        ..color = color
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_BrushStrokePreviewPainter old) =>
      old.tip != tip || old.color != color || old.brush.id != brush.id;
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
  /// Bounds fijos capturados al inicio de la rotación (OBB).
  /// Si no es null, se usa en lugar de selectedBounds para evitar
  /// que el bounding box se expanda durante el giro.
  final Rect? obbBounds;

  _SelectionOverlayPainter({
    required this.mode,
    required this.points,
    required this.dragStart,
    required this.dragCurrent,
    required this.selectedBounds,
    required this.selectedIndices,
    required this.finalizedMode,
    this.selectionAngle = 0.0,
    this.obbBounds,
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
    // Si hay obbBounds (durante rotación): usar el OBB fijo para
    // que el bbox mantenga tamaño y solo gire, sin expandirse.
    final displayBounds = obbBounds ?? selectedBounds;
    if (displayBounds != null && selectedIndices.isNotEmpty) {
      final bounds = displayBounds.inflate(10);
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
      old.selectionAngle != selectionAngle ||
      old.obbBounds != obbBounds;
}

// ─── Export Bottom Sheet ──────────────────────────────────────
class _ExportBottomSheet extends StatefulWidget {
  final void Function(String format, bool transparent, String targetApp) onExport;

  const _ExportBottomSheet({required this.onExport});

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  String _format = 'png';
  bool _transparent = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Título
          const Row(children: [
            Icon(Icons.file_download_outlined, color: Color(0xFFE74C3C), size: 22),
            SizedBox(width: 10),
            Text('EXPORTAR DISEÑO', style: TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w900, letterSpacing: 2,
                fontFamily: 'BlackOpsOne')),
          ]),
          const SizedBox(height: 24),

          // Formato
          const Text('FORMATO', style: TextStyle(
              color: Color(0xFFE74C3C), fontSize: 10,
              fontWeight: FontWeight.bold, letterSpacing: 3)),
          const SizedBox(height: 10),
          Row(children: [
            _FormatChip(label: 'PNG', subtitle: 'Mejor calidad',
                icon: Icons.image_outlined, selected: _format == 'png',
                onTap: () => setState(() => _format = 'png')),
            const SizedBox(width: 12),
            _FormatChip(label: 'JPG', subtitle: 'Menor tamaño',
                icon: Icons.photo_outlined, selected: _format == 'jpg',
                onTap: () => setState(() {
                  _format = 'jpg';
                  _transparent = false;
                })),
          ]),

          // Fondo transparente
          if (_format == 'png') ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _transparent = !_transparent),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _transparent
                      ? const Color(0xFFE74C3C) : Colors.white12),
                ),
                child: Row(children: [
                  Icon(_transparent ? Icons.check_box : Icons.check_box_outline_blank,
                      color: _transparent ? const Color(0xFFE74C3C) : Colors.white38,
                      size: 20),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fondo transparente', style: TextStyle(
                            color: Colors.white, fontSize: 13, fontFamily: 'Raleway')),
                        Text('Sin fondo blanco (solo PNG)', style: TextStyle(
                            color: Colors.white38, fontSize: 11, fontFamily: 'Raleway')),
                      ]),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── COMPARTIR EN REDES ──────────────────────────
          const Text('COMPARTIR EN', style: TextStyle(
              color: Color(0xFFE74C3C), fontSize: 10,
              fontWeight: FontWeight.bold, letterSpacing: 3)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SocialBtn(
                label: 'Galería',
                color: const Color(0xFF4CAF50),
                icon: Icons.photo_library_outlined,
                onTap: () => widget.onExport(_format, _transparent, 'gallery'),
              ),
              _SocialBtn(
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                svgPath: 'whatsapp',
                onTap: () => widget.onExport(_format, _transparent, 'whatsapp'),
              ),
              _SocialBtn(
                label: 'Instagram',
                color: const Color(0xFFE1306C),
                svgPath: 'instagram',
                onTap: () => widget.onExport(_format, _transparent, 'instagram'),
              ),
              _SocialBtn(
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                svgPath: 'facebook',
                onTap: () => widget.onExport(_format, _transparent, 'share'),
              ),
              _SocialBtn(
                label: 'Pinterest',
                color: const Color(0xFFE60023),
                svgPath: 'pinterest',
                onTap: () => widget.onExport(_format, _transparent, 'share'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Botón compartir general
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => widget.onExport(_format, _transparent, 'share'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE74C3C), Color(0xFFFF6B35)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.share, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('COMPARTIR ${_format.toUpperCase()}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Botón de red social
class _SocialBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final String? svgPath;
  final VoidCallback onTap;

  const _SocialBtn({
    required this.label,
    required this.color,
    this.icon,
    this.svgPath,
    required this.onTap,
  });

  IconData get _socialIcon {
    switch (svgPath) {
      case 'whatsapp': return Icons.chat;
      case 'instagram': return Icons.camera_alt_outlined;
      case 'facebook': return Icons.facebook;
      case 'pinterest': return Icons.push_pin_outlined;
      default: return Icons.share;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Icon(icon ?? _socialIcon, color: color, size: 24),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(
            color: Colors.white54, fontSize: 10, fontFamily: 'Raleway')),
      ]),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({required this.label, required this.subtitle,
      required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE74C3C).withOpacity(0.15)
                : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? const Color(0xFFE74C3C) : Colors.white12,
                width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Icon(icon, color: selected ? const Color(0xFFE74C3C) : Colors.white38,
                size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
                color: selected ? const Color(0xFFE74C3C) : Colors.white,
                fontSize: 16, fontWeight: FontWeight.bold,
                fontFamily: 'BlackOpsOne')),
            Text(subtitle, style: const TextStyle(
                color: Colors.white38, fontSize: 11, fontFamily: 'Raleway')),
          ]),
        ),
      ),
    );
  }
}


// ─── Botón IA para el borrador ───────────────────────────────
class _EraserAIBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _EraserAIBtn({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFE74C3C).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? const Color(0xFFE74C3C).withOpacity(0.5)
                : Colors.white12,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: enabled ? const Color(0xFFE74C3C) : Colors.white24,
              size: 18),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white24,
                  fontSize: 9,
                  fontFamily: 'Raleway')),
        ]),
      ),
    );
  }
}


// ─── RULER PAINTER ────────────────────────────────────────────────────────────

class _RulerPainter extends CustomPainter {
  final Axis direction;
  final double scale;
  final double offset;
  final double canvasSize;
  final double pxPerUnit;   // canvas px per base unit (cm/inch)
  final String unit;        // 'cm' | 'mm' | 'inch'

  const _RulerPainter({
    required this.direction,
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.pxPerUnit,
    required this.unit,
  });

  // ── Niveles adaptativos por unidad ──────────────────────────
  // Cada entrada: (divisor de la unidad base, etiqueta, esMinor)
  // cm: base=1cm. Subdivisiones: mm=0.1, 5mm=0.5
  // inch: base=1in. Subdivisiones: 1/8=0.125, 1/4=0.25, 1/2=0.5
  // mm: base=1mm. Subdivisiones: 0.5mm=0.5

  static const _cmLevels = [
    (1.0,   true,  false),  // 1 cm — label
    (0.5,   false, true),   // 5 mm — mid tick
    (0.1,   false, true),   // 1 mm — minor tick
  ];
  static const _inchLevels = [
    (1.0,   true,  false),  // 1 inch — label
    (0.5,   false, true),   // 1/2 — mid tick
    (0.25,  false, true),   // 1/4 — minor tick
    (0.125, false, true),   // 1/8 — tiny tick
  ];
  static const _mmLevels = [
    (1.0,   true,  false),  // 1 mm — label
    (0.5,   false, true),   // 0.5 mm — minor tick
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF2C2C2E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final screenPxPerUnit = pxPerUnit * scale;
    if (screenPxPerUnit <= 0) return;

    final isH = direction == Axis.horizontal;
    final totalSize = isH ? size.width : size.height;
    final rulerThickness = isH ? size.height : size.width;

    final majorPaint = Paint()..color = const Color(0xFF8E8E93)..strokeWidth = 0.5;
    final minorPaint = Paint()..color = const Color(0xFF555558)..strokeWidth = 0.5;
    final edgePaint  = Paint()..color = const Color(0xFFE74C3C)..strokeWidth = 1.0;

    final labelStyle = const TextStyle(
      color: Color(0xFF8E8E93), fontSize: 7, fontFamily: 'Raleway');
    final subLabelStyle = const TextStyle(
      color: Color(0xFF666669), fontSize: 6, fontFamily: 'Raleway');

    // Choose levels based on unit
    final levels = unit == 'inch' ? _inchLevels
                 : unit == 'mm'   ? _mmLevels
                 :                  _cmLevels;

    // Minimum screen px per tick to show that level
    const minPxToShow = 6.0;

    for (final (divisor, showLabel, isMinor) in levels) {
      final screenPxPerTick = screenPxPerUnit * divisor;
      if (screenPxPerTick < minPxToShow) continue; // too dense, skip

      final tickPaint = isMinor ? minorPaint : majorPaint;
      final tickH = isMinor
          ? rulerThickness * 0.25
          : (showLabel ? rulerThickness * 0.6 : rulerThickness * 0.4);

      final firstPos = ((-offset) / screenPxPerTick).floor() * screenPxPerTick + offset;
      double pos = firstPos;

      while (pos < totalSize + screenPxPerTick) {
        final unitVal = (pos - offset) / screenPxPerUnit;
        if (unitVal < -0.001) { pos += screenPxPerTick; continue; }
        if (unitVal * pxPerUnit > canvasSize + 0.5) { pos += screenPxPerTick; continue; }

        if (isH) {
          canvas.drawLine(
            Offset(pos, rulerThickness),
            Offset(pos, rulerThickness - tickH),
            tickPaint,
          );
          if (showLabel && screenPxPerTick >= 20) {
            _drawLabel(canvas, _formatVal(unitVal, divisor), pos + 2, 1, labelStyle);
          } else if (!showLabel && isMinor && screenPxPerTick >= 30) {
            // Sub-labels for mm when zoomed in
            final subVal = _subLabel(unitVal, divisor);
            if (subVal != null) {
              _drawLabel(canvas, subVal, pos + 1, rulerThickness * 0.15, subLabelStyle);
            }
          }
        } else {
          canvas.drawLine(
            Offset(rulerThickness, pos),
            Offset(rulerThickness - tickH, pos),
            tickPaint,
          );
          if (showLabel && screenPxPerTick >= 20) {
            _drawLabelV(canvas, _formatVal(unitVal, divisor), 1, pos + 2, labelStyle);
          }
        }
        pos += screenPxPerTick;
      }
    }

    // Canvas edge markers (red)
    final canvasStart = offset;
    final canvasEnd   = offset + canvasSize * scale;
    if (isH) {
      if (canvasStart >= 0 && canvasStart <= totalSize)
        canvas.drawLine(Offset(canvasStart, 0), Offset(canvasStart, rulerThickness), edgePaint);
      if (canvasEnd >= 0 && canvasEnd <= totalSize)
        canvas.drawLine(Offset(canvasEnd, 0), Offset(canvasEnd, rulerThickness), edgePaint);
    } else {
      if (canvasStart >= 0 && canvasStart <= totalSize)
        canvas.drawLine(Offset(0, canvasStart), Offset(rulerThickness, canvasStart), edgePaint);
      if (canvasEnd >= 0 && canvasEnd <= totalSize)
        canvas.drawLine(Offset(0, canvasEnd), Offset(rulerThickness, canvasEnd), edgePaint);
    }
  }

  String _formatVal(double val, double divisor) {
    if (val < 0.001) return '0';
    if (divisor >= 1.0) return val.round().toString();
    // Sub-unit: show decimal
    final decimals = divisor < 0.15 ? 2 : 1;
    return val.toStringAsFixed(decimals);
  }

  /// For sub-ticks between major ticks, show mm value if unit is cm
  String? _subLabel(double val, double divisor) {
    if (unit != 'cm') return null;
    // divisor 0.1 = 1mm — show mm number
    if ((divisor - 0.1).abs() < 0.01) {
      final mm = (val * 10).round() % 10;
      if (mm == 0) return null; // already labeled as cm
      return '$mm';
    }
    return null;
  }

  void _drawLabel(Canvas canvas, String text, double x, double y, TextStyle style) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x, y));
  }

  void _drawLabelV(Canvas canvas, String text, double x, double y, TextStyle style) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)..layout();
    canvas.save();
    canvas.translate(x, y + tp.width);
    canvas.rotate(-3.14159 / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
    old.scale != scale || old.offset != offset || old.unit != unit;
}
