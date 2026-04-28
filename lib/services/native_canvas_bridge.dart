import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Puente Flutter ↔ motor C++ offscreen.
/// El motor renderiza en FBO → exporta RGBA → Flutter crea ui.Image.
class NativeCanvasBridge {
  static const _ch = MethodChannel('tsk/drawing_engine');

  bool _ready = false;
  bool get isReady => _ready;

  int _canvasW = 1080;
  int _canvasH = 1920;

  // ── Init ──────────────────────────────────────────────────────────

  Future<bool> init({int canvasW = 1080, int canvasH = 1920, int maxUndo = 20}) async {
    _canvasW = canvasW;
    _canvasH = canvasH;
    final ok = await _ch.invokeMethod<bool>('init', {
      'canvasW': canvasW, 'canvasH': canvasH, 'maxUndo': maxUndo,
    }) ?? false;
    if (!ok) {
      String err = 'unknown';
      try { err = await _ch.invokeMethod<String>('getLastError') ?? err; } catch (_) {}
      throw Exception('NativeCanvasBridge init failed: $err');
    }
    _ready = true;
    return true;
  }

  Future<void> destroy() async { await _ch.invokeMethod('destroy'); _ready = false; }

  // ── Stroke ────────────────────────────────────────────────────────

  Future<void> beginStroke({
    required int layerId, required double x, required double y,
    double pressure = 1.0, required double size, required double opacity,
    required double hardness, double spacing = 0.1,
    bool isEraser = false, int brushTexId = -1, required Color color,
  }) async {
    if (!_ready) return;
    await _ch.invokeMethod('beginStroke', {
      'layerId': layerId, 'x': x, 'y': y, 'pressure': pressure,
      'size': size, 'opacity': opacity, 'hardness': hardness,
      'spacing': spacing, 'isEraser': isEraser,
      'brushTexId': brushTexId, 'colorARGB': color.value,
    });
  }

  Future<void> addPoint(double x, double y, {double pressure = 1.0}) async {
    if (!_ready) return;
    await _ch.invokeMethod('addPoint', {'x': x, 'y': y, 'pressure': pressure});
  }

  /// Termina el trazo y devuelve la imagen del canvas.
  Future<ui.Image?> endStroke() async {
    if (!_ready) return null;
    final bytes = await _ch.invokeMethod<Uint8List>('endStrokeAndExport');
    if (bytes != null && bytes.isNotEmpty) return _toImage(bytes);
    // FIX: si endStrokeAndExport devuelve null (EGL context issue),
    // esperar un frame y hacer exportCanvas como fallback.
    await Future.delayed(const Duration(milliseconds: 32));
    if (!_ready) return null;
    final fallback = await _ch.invokeMethod<Uint8List>('exportCanvas');
    return _toImage(fallback);
  }

  Future<void> cancelStroke() async {
    if (!_ready) return;
    await _ch.invokeMethod('cancelStroke');
  }

  /// Exporta el canvas sin modificar historial.
  Future<ui.Image?> exportCanvas() async {
    if (!_ready) return null;
    final bytes = await _ch.invokeMethod<Uint8List>('exportCanvas');
    return _toImage(bytes);
  }

  // ── Historial ─────────────────────────────────────────────────────

  Future<ui.Image?> undo() async {
    if (!_ready) return null;
    return _toImage(await _ch.invokeMethod<Uint8List>('undo'));
  }

  Future<ui.Image?> redo() async {
    if (!_ready) return null;
    return _toImage(await _ch.invokeMethod<Uint8List>('redo'));
  }

  Future<bool> canUndo() async => await _ch.invokeMethod<bool>('canUndo') ?? false;
  Future<bool> canRedo() async => await _ch.invokeMethod<bool>('canRedo') ?? false;

  // ── Capas ─────────────────────────────────────────────────────────

  Future<int>  addLayer({String name = ''}) async =>
      await _ch.invokeMethod<int>('addLayer', {'name': name}) ?? -1;
  Future<void> removeLayer(int id)   => _ch.invokeMethod('removeLayer',   {'id': id});
  Future<void> setActiveLayer(int id)=> _ch.invokeMethod('setActiveLayer',{'id': id});
  Future<void> setLayerOpacity(int id, double o) =>
      _ch.invokeMethod('setLayerOpacity', {'id': id, 'opacity': o});
  Future<void> setLayerVisible(int id, bool v) =>
      _ch.invokeMethod('setLayerVisible', {'id': id, 'visible': v});
  Future<ui.Image?> clearLayer(int id) async =>
      _toImage(await _ch.invokeMethod<Uint8List>('clearLayer', {'id': id}));

  // ── Canvas ────────────────────────────────────────────────────────

  Future<ui.Image?> setBackground(Color color) async =>
      _toImage(await _ch.invokeMethod<Uint8List>('setBackground', {'colorARGB': color.value}));
  /// Borra un rectángulo de píxeles en la capa (GPU, coordenadas canvas Y=0 arriba).
  Future<ui.Image?> eraseRegion(int layerId, double x, double y, double w, double h) async {
    if (!_ready) return null;
    final bytes = await _ch.invokeMethod<Uint8List>('eraseRegion',
        {'layerId': layerId, 'x': x, 'y': y, 'w': w, 'h': h});
    return _toImage(bytes);
  }

  Future<void> setCanvasSize(int w, int h) async {
    // FIX: actualizar _canvasW/_canvasH para que _toImage use las dimensiones
    // correctas. Sin esto, la imagen GPU se decodifica con el tamaño anterior
    // → imagen comprimida/distorsionada después de cambiar el canvas.
    _canvasW = w;
    _canvasH = h;
    await _ch.invokeMethod('setCanvasSize', {'w': w, 'h': h});
  }

  // ── Export raw ────────────────────────────────────────────────────

  Future<Uint8List?> exportPixels() async =>
      _ch.invokeMethod<Uint8List>('exportCanvas');

  // ── Brush textures ────────────────────────────────────────────────

  Future<int> loadBrushTexture(Uint8List data, int w, int h) async =>
      await _ch.invokeMethod<int>('loadBrushTexture', {'data': data, 'w': w, 'h': h}) ?? -1;
  Future<void> unloadBrushTexture(int id) =>
      _ch.invokeMethod('unloadBrushTexture', {'id': id});

  // ── RGBA → ui.Image ──────────────────────────────────────────────

  Future<ui.Image?> _toImage(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
      final desc = ui.ImageDescriptor.raw(
        buf, width: _canvasW, height: _canvasH,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await desc.instantiateCodec();
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) { return null; }
  }
}
