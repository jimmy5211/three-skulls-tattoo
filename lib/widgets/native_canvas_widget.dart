import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_canvas_bridge.dart';

/// Widget que muestra el canvas renderizado por el motor C++/OpenGL.
///
/// Usa [Texture] de Flutter para recibir los frames del motor nativo
/// sin copiar datos entre CPU y GPU.
///
/// Características:
/// - Captura touch con Listener para máxima precisión (sin delay del GestureDetector)
/// - Soporte para presión de stylus (MotionEvent.getPressure)
/// - 2+ dedos → cancelar stroke y usar para pan/zoom (manejado externamente)
///
/// Ejemplo:
/// ```dart
/// NativeCanvasWidget(
///   bridge: _bridge,
///   canvasW: 1080, canvasH: 1920,
///   brushColor: Colors.black,
///   brushSize: 20.0,
///   brushOpacity: 1.0,
///   brushHardness: 0.8,
///   isEraser: false,
///   activeLayerId: 0,
/// )
/// ```
class NativeCanvasWidget extends StatefulWidget {
  final NativeCanvasBridge bridge;
  final int    canvasW;
  final int    canvasH;
  final Color  brushColor;
  final double brushSize;
  final double brushOpacity;
  final double brushHardness;
  final double brushSpacing;
  final bool   isEraser;
  final int    activeLayerId;
  final int    brushTexId;

  /// Callbacks para integrar con el UI principal
  final VoidCallback?    onStrokeEnd;
  final VoidCallback?    onUndoStateChanged;

  const NativeCanvasWidget({
    super.key,
    required this.bridge,
    required this.canvasW,
    required this.canvasH,
    this.brushColor    = Colors.black,
    this.brushSize     = 20.0,
    this.brushOpacity  = 1.0,
    this.brushHardness = 0.8,
    this.brushSpacing  = 0.1,
    this.isEraser      = false,
    this.activeLayerId = 0,
    this.brushTexId    = -1,
    this.onStrokeEnd,
    this.onUndoStateChanged,
  });

  @override
  State<NativeCanvasWidget> createState() => _NativeCanvasWidgetState();
}

class _NativeCanvasWidgetState extends State<NativeCanvasWidget> {
  int _activePointers = 0;
  bool _drawing       = false;
  bool _cancelPending = false;

  // Dimensiones del widget en pantalla (para coordenadas relativas)
  double _widgetW = 1.0;
  double _widgetH = 1.0;

  @override
  Widget build(BuildContext context) {
    if (!widget.bridge.isReady || widget.bridge.textureId == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.red),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _widgetW = constraints.maxWidth;
        _widgetH = constraints.maxHeight;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown:   _onPointerDown,
          onPointerMove:   _onPointerMove,
          onPointerUp:     _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: RepaintBoundary(
            child: Texture(textureId: widget.bridge.textureId!),
          ),
        );
      },
    );
  }

  // ── Conversión de coordenadas ──────────────────────────────────────
  // El widget puede ser más pequeño que el canvas nativo (por zoom de Flutter).
  // Convertimos las coordenadas del widget a coordenadas del canvas.

  Offset _toCanvas(Offset screenPos) {
    return Offset(
      screenPos.dx / _widgetW * widget.canvasW,
      screenPos.dy / _widgetH * widget.canvasH,
    );
  }

  // ── Touch handlers ─────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    _activePointers++;

    // Segundo dedo → cancelar stroke inmediatamente
    if (_activePointers > 1) {
      if (_drawing) {
        widget.bridge.cancelStroke();
        _drawing = false;
      }
      _cancelPending = true;
      return;
    }

    _cancelPending = false;
    final cp = _toCanvas(e.localPosition);
    final pressure = e.pressure.clamp(0.0, 1.0);

    widget.bridge.beginStroke(
      layerId    : widget.activeLayerId,
      x          : cp.dx,
      y          : cp.dy,
      pressure   : pressure,
      size       : widget.brushSize,
      opacity    : widget.brushOpacity,
      hardness   : widget.brushHardness,
      spacing    : widget.brushSpacing,
      isEraser   : widget.isEraser,
      brushTexId : widget.brushTexId,
      color      : widget.brushColor,
    );
    _drawing = true;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_cancelPending || !_drawing || _activePointers > 1) return;
    final cp       = _toCanvas(e.localPosition);
    final pressure = e.pressure.clamp(0.0, 1.0);
    widget.bridge.addPoint(cp.dx, cp.dy, pressure: pressure);
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers = (_activePointers - 1).clamp(0, 99);

    if (_drawing) {
      widget.bridge.endStroke();
      _drawing = false;
      widget.onStrokeEnd?.call();
      widget.onUndoStateChanged?.call();
    }
    if (_activePointers == 0) _cancelPending = false;
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _activePointers = (_activePointers - 1).clamp(0, 99);
    if (_drawing) {
      widget.bridge.cancelStroke();
      _drawing = false;
    }
    if (_activePointers == 0) _cancelPending = false;
  }
}

/// Widget de carga mientras el motor inicializa
class NativeCanvasLoader extends StatefulWidget {
  final int canvasW, canvasH;
  final int maxUndoSteps;
  final Widget Function(NativeCanvasBridge bridge) builder;

  const NativeCanvasLoader({
    super.key,
    this.canvasW      = 1080,
    this.canvasH      = 1920,
    this.maxUndoSteps = 20,
    required this.builder,
  });

  @override
  State<NativeCanvasLoader> createState() => _NativeCanvasLoaderState();
}

class _NativeCanvasLoaderState extends State<NativeCanvasLoader> {
  NativeCanvasBridge? _bridge;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final bridge = NativeCanvasBridge();
      await bridge.init(
        canvasW:    widget.canvasW,
        canvasH:    widget.canvasH,
        maxUndo:    widget.maxUndoSteps,
      );
      if (mounted) setState(() => _bridge = bridge);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _bridge?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error: $_error',
          style: const TextStyle(color: Colors.red)));
    }
    if (_bridge == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }
    return widget.builder(_bridge!);
  }
}
