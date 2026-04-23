import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Puente entre Flutter y el motor C++/OpenGL a través de MethodChannel.
///
/// Uso:
/// ```dart
/// final bridge = NativeCanvasBridge();
/// final textureId = await bridge.init(canvasW: 1080, canvasH: 1920);
/// // Mostrar en UI:
/// Texture(textureId: textureId)
/// // Dibujar:
/// bridge.beginStroke(...)
/// bridge.addPoint(...)
/// bridge.endStroke()
/// ```
class NativeCanvasBridge {
  static const _ch = MethodChannel('tsk/drawing_engine');

  // textureId devuelto por init() — usar con Texture(textureId: id)
  int? textureId;
  bool _ready = false;
  bool get isReady => _ready;

  // ── Inicializar motor ──────────────────────────────────────────────

  Future<int> init({
    int canvasW    = 1080,
    int canvasH    = 1920,
    int maxUndo    = 20,
  }) async {
    final id = await _ch.invokeMethod<int>('init', {
      'canvasW': canvasW,
      'canvasH': canvasH,
      'maxUndo': maxUndo,
    });
    // id == -1 significa que el motor C++ falló pero reportó correctamente
    if (id == null || id < 0) {
      throw Exception('NativeCanvasBridge: motor C++ no disponible (id=$id)');
    }
    textureId = id;
    _ready = true;
    return id;
  }

  Future<void> destroy() async {
    await _ch.invokeMethod('destroy');
    _ready = false;
    textureId = null;
  }

  // ── Stroke lifecycle ───────────────────────────────────────────────

  /// Inicia un trazo. Llamar en onPointerDown.
  Future<void> beginStroke({
    required int    layerId,
    required double x,
    required double y,
    double pressure = 1.0,
    // Brush params
    required double size,
    required double opacity,
    required double hardness,
    double  spacing    = 0.1,
    bool    isEraser   = false,
    int     brushTexId = -1,
    required Color color,
  }) async {
    if (!_ready) return;
    await _ch.invokeMethod('beginStroke', {
      'layerId'    : layerId,
      'x'          : x,
      'y'          : y,
      'pressure'   : pressure,
      'size'       : size,
      'opacity'    : opacity,
      'hardness'   : hardness,
      'spacing'    : spacing,
      'isEraser'   : isEraser,
      'brushTexId' : brushTexId,
      'colorARGB'  : color.value,
    });
  }

  /// Agregar punto al trazo activo. Llamar en onPointerMove.
  Future<void> addPoint(double x, double y, {double pressure = 1.0}) async {
    if (!_ready) return;
    await _ch.invokeMethod('addPoint', {
      'x': x, 'y': y, 'pressure': pressure,
    });
  }

  /// Terminar trazo. Llamar en onPointerUp.
  Future<void> endStroke() async {
    if (!_ready) return;
    await _ch.invokeMethod('endStroke');
  }

  /// Cancelar trazo. Llamar si se detecta multitouch.
  Future<void> cancelStroke() async {
    if (!_ready) return;
    await _ch.invokeMethod('cancelStroke');
  }

  // ── Historial ──────────────────────────────────────────────────────

  Future<void> undo() => _ch.invokeMethod('undo');
  Future<void> redo() => _ch.invokeMethod('redo');
  Future<bool> canUndo() async => await _ch.invokeMethod<bool>('canUndo') ?? false;
  Future<bool> canRedo() async => await _ch.invokeMethod<bool>('canRedo') ?? false;

  // ── Capas ──────────────────────────────────────────────────────────

  Future<int> addLayer({String name = ''}) async =>
      await _ch.invokeMethod<int>('addLayer', {'name': name}) ?? -1;

  Future<void> removeLayer(int id) =>
      _ch.invokeMethod('removeLayer', {'id': id});

  Future<void> setActiveLayer(int id) =>
      _ch.invokeMethod('setActiveLayer', {'id': id});

  Future<void> setLayerOpacity(int id, double opacity) =>
      _ch.invokeMethod('setLayerOpacity', {'id': id, 'opacity': opacity});

  Future<void> setLayerVisible(int id, bool visible) =>
      _ch.invokeMethod('setLayerVisible', {'id': id, 'visible': visible});

  Future<void> clearLayer(int id) =>
      _ch.invokeMethod('clearLayer', {'id': id});

  // ── Canvas ─────────────────────────────────────────────────────────

  Future<void> setBackground(Color color) =>
      _ch.invokeMethod('setBackground', {'colorARGB': color.value});

  Future<void> setCanvasSize(int w, int h) =>
      _ch.invokeMethod('setCanvasSize', {'w': w, 'h': h});

  // ── Export ─────────────────────────────────────────────────────────

  /// Devuelve los píxeles RGBA del canvas compuesto.
  /// Error del último intento de init (para diagnóstico)
  Future<String> getLastError() async {
    try {
      return await _ch.invokeMethod<String>('getLastError') ?? 'no_error';
    } catch (e) {
      return 'bridge_error: $e';
    }
  }

  Future<Uint8List?> exportPixels() async {
    final bytes = await _ch.invokeMethod<Uint8List>('exportPixels');
    return bytes;
  }

  // ── Brush textures ─────────────────────────────────────────────────

  /// Carga una imagen PNG como textura de pincel.
  /// Devuelve un ID para usar en beginStroke(brushTexId: id).
  Future<int> loadBrushTexture(Uint8List rgbaData, int w, int h) async =>
      await _ch.invokeMethod<int>('loadBrushTexture', {
        'data': rgbaData, 'w': w, 'h': h,
      }) ?? -1;

  Future<void> unloadBrushTexture(int id) =>
      _ch.invokeMethod('unloadBrushTexture', {'id': id});
}
