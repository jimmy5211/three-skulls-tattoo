import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/layer_model.dart';
import '../models/brush_model.dart';

class CanvasController extends ChangeNotifier {
  // Capas
  List<LayerModel> layers = [];
  int activeLayerId = 0;

  // Pincel activo
  BrushModel activeBrush = BrushModel.defaultBrushes()[0];

  // Color activo
  Color activeColor = Colors.black;

  // Trazo actual
  StrokeModel? currentStroke;

  // Historial para deshacer/rehacer
  List<List<LayerModel>> _undoHistory = [];
  List<List<LayerModel>> _redoHistory = [];

  // Simetría
  bool symmetryEnabled = false;
  SymmetryType symmetryType = SymmetryType.horizontal;

  // Zoom y paneo
  double scale = 1.0;
  Offset offset = Offset.zero;

  // Canvas size
  Size canvasSize = const Size(1080, 1920);

  CanvasController() {
    _initLayers();
  }

  void _initLayers() {
    layers = [
      LayerModel(id: 0, name: 'Capa 1'),
    ];
    activeLayerId = 0;
  }

  // Obtener capa activa
  LayerModel get activeLayer {
    return layers.firstWhere(
      (l) => l.id == activeLayerId,
      orElse: () => layers.first,
    );
  }

  // Iniciar trazo
  void startStroke(Offset point) {
    if (activeLayer.isLocked) return;
    _saveToHistory();
    currentStroke = StrokeModel(
      points: [point],
      color: activeBrush.type == StrokeType.eraser
          ? Colors.white
          : activeColor,
      strokeWidth: activeBrush.size,
      opacity: activeBrush.opacity,
      type: activeBrush.type,
      layerId: activeLayerId,
    );
    notifyListeners();
  }

  // Continuar trazo
  void continueStroke(Offset point) {
    if (currentStroke == null) return;
    currentStroke = currentStroke!.copyWith(
      points: [...currentStroke!.points, point],
    );

    if (symmetryEnabled) {
      _addSymmetryPoint(point);
    }
    notifyListeners();
  }

  // Terminar trazo
  void endStroke() {
    if (currentStroke == null) return;
    final layerIndex = layers.indexWhere(
      (l) => l.id == activeLayerId,
    );
    if (layerIndex != -1) {
      layers[layerIndex].strokes.add(currentStroke!);
    }
    currentStroke = null;
    notifyListeners();
  }

  // Agregar punto de simetría
  void _addSymmetryPoint(Offset point) {
    if (currentStroke == null) return;
    Offset mirroredPoint;
    switch (symmetryType) {
      case SymmetryType.horizontal:
        mirroredPoint = Offset(
          canvasSize.width - point.dx,
          point.dy,
        );
        break;
      case SymmetryType.vertical:
        mirroredPoint = Offset(
          point.dx,
          canvasSize.height - point.dy,
        );
        break;
      case SymmetryType.radial:
        mirroredPoint = Offset(
          canvasSize.width - point.dx,
          canvasSize.height - point.dy,
        );
        break;
    }
    currentStroke = currentStroke!.copyWith(
      points: [...currentStroke!.points, mirroredPoint],
    );
  }

  // Guardar historial
  void _saveToHistory() {
    _undoHistory.add(
      layers.map((l) => l.copyWith(
        strokes: List.from(l.strokes),
      )).toList(),
    );
    _redoHistory.clear();
    if (_undoHistory.length > 50) {
      _undoHistory.removeAt(0);
    }
  }

  // Deshacer
  void undo() {
    if (_undoHistory.isEmpty) return;
    _redoHistory.add(
      layers.map((l) => l.copyWith(
        strokes: List.from(l.strokes),
      )).toList(),
    );
    layers = _undoHistory.removeLast();
    notifyListeners();
  }

  // Rehacer
  void redo() {
    if (_redoHistory.isEmpty) return;
    _undoHistory.add(
      layers.map((l) => l.copyWith(
        strokes: List.from(l.strokes),
      )).toList(),
    );
    layers = _redoHistory.removeLast();
    notifyListeners();
  }

  // Agregar capa
  void addLayer() {
    final newId = layers.isEmpty ? 0 : layers.last.id + 1;
    layers.add(LayerModel(
      id: newId,
      name: 'Capa ${newId + 1}',
    ));
    activeLayerId = newId;
    notifyListeners();
  }

  // Eliminar capa
  void removeLayer(int layerId) {
    if (layers.length <= 1) return;
    layers.removeWhere((l) => l.id == layerId);
    if (activeLayerId == layerId) {
      activeLayerId = layers.last.id;
    }
    notifyListeners();
  }

  // Cambiar capa activa
  void setActiveLayer(int layerId) {
    activeLayerId = layerId;
    notifyListeners();
  }

  // Cambiar visibilidad de capa
  void toggleLayerVisibility(int layerId) {
    final index = layers.indexWhere((l) => l.id == layerId);
    if (index != -1) {
      layers[index].isVisible = !layers[index].isVisible;
      notifyListeners();
    }
  }

  // Cambiar pincel
  void setActiveBrush(BrushModel brush) {
    activeBrush = brush;
    notifyListeners();
  }

  // Cambiar color
  void setActiveColor(Color color) {
    activeColor = color;
    notifyListeners();
  }

  // Cambiar tamaño del pincel
  void setBrushSize(double size) {
    activeBrush = activeBrush.copyWith(size: size);
    notifyListeners();
  }

  // Cambiar opacidad del pincel
  void setBrushOpacity(double opacity) {
    activeBrush = activeBrush.copyWith(opacity: opacity);
    notifyListeners();
  }

  // Toggle simetría
  void toggleSymmetry() {
    symmetryEnabled = !symmetryEnabled;
    notifyListeners();
  }

  // Limpiar canvas
  void clearCanvas() {
    _saveToHistory();
    for (var layer in layers) {
      layer.strokes.clear();
    }
    notifyListeners();
  }

  // Limpiar capa activa
  void clearActiveLayer() {
    _saveToHistory();
    activeLayer.strokes.clear();
    notifyListeners();
  }
}

enum SymmetryType {
  horizontal,
  vertical,
  radial,
}
