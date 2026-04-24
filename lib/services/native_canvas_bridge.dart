import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Puente entre Flutter y el motor C++/OpenGL a través de MethodChannel.
class NativeCanvasBridge {
  static const _ch = MethodChannel('tsk/drawing_engine');

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

    if (id == null || id < 0) {
      // FIX: obtener detalle del error antes de lanzar excepción
      // Así el dialog muestra el paso exacto donde falló el motor
      String errDetail = 'no_detail';
      try {
        errDetail = await _ch.invokeMethod<String>('getLastError') ?? 'null_response';
      } catch (e) {
        errDetail = 'getLastError_failed: $e';
      }
      throw Exception(
        'NativeCanvasBridge: motor C++ no disponible (id=$id) | detail=$errDetail'
      );
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

  Future<void> beginStroke({
    required int    layerId,
    required double x,
    required double y,
    double pressure = 1.0,
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

  Future<void> addPoint(double x, double y, {double pressure = 1.0}) async {
    if (!_ready) return;
    await _ch.invokeMethod('addPoint', {
      'x': x, 'y': y, 'pressure': pressure,
    });
  }

  Future<void> endStroke() async {
    if (!_ready) return;
    await _ch.invokeMethod('endStroke');
  }

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

  Future<Uint8List?> exportPixels() async {
    final bytes = await _ch.invokeMethod<Uint8List>('exportPixels');
    return bytes;
  }

  // ── Brush textures ─────────────────────────────────────────────────

  Future<int> loadBrushTexture(Uint8List rgbaData, int w, int h) async =>
      await _ch.invokeMethod<int>('loadBrushTexture', {
        'data': rgbaData, 'w': w, 'h': h,
      }) ?? -1;

  Future<void> unloadBrushTexture(int id) =>
      _ch.invokeMethod('unloadBrushTexture', {'id': id});
}
