import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/layer_model.dart';
import '../models/brush_model.dart';

class CanvasController extends ChangeNotifier {
  List<LayerModel> layers = [];
  int activeLayerId = 0;
  BrushModel activeBrush = BrushModel.defaultBrushes()[0];
  Color activeColor = Colors.black;
  StrokeModel? currentStroke;
  StrokeModel? currentMirrorStroke;
  List<List<LayerModel>> _undoHistory = [];
  List<List<LayerModel>> _redoHistory = [];
  bool symmetryEnabled = false;
  SymmetryType symmetryType = SymmetryType.horizontal;
  Size canvasSize = const Size(1080, 1920);
  Color backgroundColor = Colors.transparent;

  // Cache de capas renderizadas
  final Map<int, ui.Picture?> _layerCache = {};
  bool _cacheInvalidated = false;

  CanvasController() {
    _initLayers();
  }

  void _initLayers() {
    layers = [LayerModel(id: 0, name: 'Capa 1')];
    activeLayerId = 0;
  }

  LayerModel get activeLayer => layers.firstWhere(
        (l) => l.id == activeLayerId,
        orElse: () => layers.first,
      );

  // Cache invalidation
  void invalidateLayerCache(int layerId) {
    _layerCache[layerId] = null;
    _cacheInvalidated = true;
  }

  void invalidateAllCache() {
    _layerCache.clear();
    _cacheInvalidated = true;
  }

  bool get cacheInvalidated => _cacheInvalidated;
  void resetCacheFlag() => _cacheInvalidated = false;

  ui.Picture? getLayerCache(int layerId) => _layerCache[layerId];
  void setLayerCache(int layerId, ui.Picture picture) {
    _layerCache[layerId] = picture;
  }

  // Simplificación de puntos — algoritmo Ramer-Douglas-Peucker simplificado
  List<Offset> _simplifyPoints(List<Offset> points, double tolerance) {
    if (points.length <= 2) return points;

    // Solo simplificar si hay muchos puntos
    if (points.length < 10) return points;

    final result = <Offset>[points.first];
    Offset lastAdded = points.first;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = (points[i] - lastAdded).distance;
      if (dist >= tolerance) {
        result.add(points[i]);
        lastAdded = points[i];
      }
    }
    result.add(points.last);
    return result;
  }

  void startStroke(Offset point) {
    if (activeLayer.isLocked) return;
    _saveToHistory();

    currentStroke = StrokeModel(
      points: [point],
      color: activeBrush.type == StrokeType.eraser
          ? Colors.white
          : activeColor,
      strokeWidth: activeBrush.size,
      opacity: activeBrush.type == StrokeType.eraser
          ? 1.0
          : activeBrush.opacity,
      type: activeBrush.type,
      layerId: activeLayerId,
    );

    if (symmetryEnabled) {
      final mirroredPoint = _getMirroredPoint(point);
      currentMirrorStroke = StrokeModel(
        points: [mirroredPoint],
        color: activeBrush.type == StrokeType.eraser
            ? Colors.white
            : activeColor,
        strokeWidth: activeBrush.size,
        opacity: activeBrush.type == StrokeType.eraser
            ? 1.0
            : activeBrush.opacity,
        type: activeBrush.type,
        layerId: activeLayerId,
      );
    } else {
      currentMirrorStroke = null;
    }

    notifyListeners();
  }

  void continueStroke(Offset point) {
    if (currentStroke == null) return;

    // Filtrar puntos muy cercanos para reducir procesamiento
    if (currentStroke!.points.isNotEmpty) {
      final lastPoint = currentStroke!.points.last;
      final minDist = activeBrush.size * 0.15;
      if ((point - lastPoint).distance < minDist) return;
    }

    final newPoints = List<Offset>.from(currentStroke!.points)..add(point);

    currentStroke = StrokeModel(
      points: newPoints,
      color: currentStroke!.color,
      strokeWidth: currentStroke!.strokeWidth,
      opacity: currentStroke!.opacity,
      type: currentStroke!.type,
      layerId: activeLayerId,
    );

    if (symmetryEnabled && currentMirrorStroke != null) {
      final mirroredPoint = _getMirroredPoint(point);
      final mirrorPoints = List<Offset>.from(
        currentMirrorStroke!.points,
      )..add(mirroredPoint);

      currentMirrorStroke = StrokeModel(
        points: mirrorPoints,
        color: currentMirrorStroke!.color,
        strokeWidth: currentMirrorStroke!.strokeWidth,
        opacity: currentMirrorStroke!.opacity,
        type: currentMirrorStroke!.type,
        layerId: activeLayerId,
      );
    }

    notifyListeners();
  }

  void endStroke() {
    if (currentStroke == null) return;

    final layerIndex = layers.indexWhere(
      (l) => l.id == activeLayerId,
    );

    if (layerIndex != -1) {
      // Simplificar puntos al terminar el trazo
      final tolerance = activeBrush.size * 0.1;
      final simplifiedPoints = _simplifyPoints(
        currentStroke!.points,
        tolerance.clamp(0.5, 3.0),
      );

      final simplifiedStroke = StrokeModel(
        points: simplifiedPoints,
        color: currentStroke!.color,
        strokeWidth: currentStroke!.strokeWidth,
        opacity: currentStroke!.opacity,
        type: currentStroke!.type,
        layerId: currentStroke!.layerId,
      );

      final updatedStrokes = List<StrokeModel>.from(
        layers[layerIndex].strokes,
      )..add(simplifiedStroke);

      if (symmetryEnabled && currentMirrorStroke != null) {
        final simplifiedMirrorPoints = _simplifyPoints(
          currentMirrorStroke!.points,
          tolerance.clamp(0.5, 3.0),
        );
        updatedStrokes.add(StrokeModel(
          points: simplifiedMirrorPoints,
          color: currentMirrorStroke!.color,
          strokeWidth: currentMirrorStroke!.strokeWidth,
          opacity: currentMirrorStroke!.opacity,
          type: currentMirrorStroke!.type,
          layerId: currentMirrorStroke!.layerId,
        ));
      }

      layers[layerIndex] = layers[layerIndex].copyWith(
        strokes: updatedStrokes,
      );

      // Invalidar cache de esta capa
      invalidateLayerCache(activeLayerId);
    }

    currentStroke = null;
    currentMirrorStroke = null;
    notifyListeners();
  }

  Offset _getMirroredPoint(Offset point) {
    switch (symmetryType) {
      case SymmetryType.horizontal:
        return Offset(canvasSize.width - point.dx, point.dy);
      case SymmetryType.vertical:
        return Offset(point.dx, canvasSize.height - point.dy);
      case SymmetryType.radial:
        return Offset(
            canvasSize.width - point.dx, canvasSize.height - point.dy);
    }
  }

  void _saveToHistory() {
    _undoHistory.add(
      layers.map((l) => l.copyWith(
            strokes: List<StrokeModel>.from(l.strokes),
          )).toList(),
    );
    _redoHistory.clear();
    if (_undoHistory.length > 30) {
      _undoHistory.removeAt(0);
    }
  }

  void undo() {
    if (_undoHistory.isEmpty) return;
    _redoHistory.add(
      layers.map((l) => l.copyWith(
            strokes: List<StrokeModel>.from(l.strokes),
          )).toList(),
    );
    layers = _undoHistory.removeLast();
    invalidateAllCache();
    notifyListeners();
  }

  void redo() {
    if (_redoHistory.isEmpty) return;
    _undoHistory.add(
      layers.map((l) => l.copyWith(
            strokes: List<StrokeModel>.from(l.strokes),
          )).toList(),
    );
    layers = _redoHistory.removeLast();
    invalidateAllCache();
    notifyListeners();
  }

  void addLayer() {
    final newId = layers.isEmpty ? 0 : layers.last.id + 1;
    layers.add(LayerModel(id: newId, name: 'Capa ${newId + 1}'));
    activeLayerId = newId;
    notifyListeners();
  }

  void removeLayer(int layerId) {
    if (layers.length <= 1) return;
    layers.removeWhere((l) => l.id == layerId);
    _layerCache.remove(layerId);
    if (activeLayerId == layerId) {
      activeLayerId = layers.last.id;
    }
    notifyListeners();
  }

  void duplicateLayer(int layerId) {
    final index = layers.indexWhere((l) => l.id == layerId);
    if (index == -1) return;
    _saveToHistory();
    final newId = layers.last.id + 1;
    final original = layers[index];
    final duplicate = LayerModel(
      id: newId,
      name: '${original.name} copia',
      isVisible: original.isVisible,
      isLocked: false,
      opacity: original.opacity,
      strokes: List<StrokeModel>.from(original.strokes),
    );
    layers.insert(index + 1, duplicate);
    activeLayerId = newId;
    notifyListeners();
  }

  void mergeDownLayer(int layerId) {
    final index = layers.indexWhere((l) => l.id == layerId);
    if (index <= 0) return;
    _saveToHistory();
    final current = layers[index];
    final below = layers[index - 1];
    final mergedStrokes = [...below.strokes, ...current.strokes];
    layers[index - 1] = below.copyWith(strokes: mergedStrokes);
    layers.removeAt(index);
    activeLayerId = layers[index - 1].id;
    invalidateLayerCache(below.id);
    notifyListeners();
  }

  void lockLayer(int layerId) {
    final index = layers.indexWhere((l) => l.id == layerId);
    if (index == -1) return;
    layers[index] = layers[index].copyWith(
      isLocked: !layers[index].isLocked,
    );
    notifyListeners();
  }

  void flattenLayers() {
    if (layers.length <= 1) return;
    _saveToHistory();
    final allStrokes = layers.expand((l) => l.strokes).toList();
    layers = [LayerModel(id: 0, name: 'Capa 1', strokes: allStrokes)];
    activeLayerId = 0;
    invalidateAllCache();
    notifyListeners();
  }

  void setActiveLayer(int layerId) {
    activeLayerId = layerId;
    notifyListeners();
  }

  void toggleLayerVisibility(int layerId) {
    final index = layers.indexWhere((l) => l.id == layerId);
    if (index != -1) {
      layers[index] = layers[index].copyWith(
        isVisible: !layers[index].isVisible,
      );
      notifyListeners();
    }
  }

  void setActiveBrush(BrushModel brush) {
    activeBrush = brush;
    notifyListeners();
  }

  void setActiveColor(Color color) {
    activeColor = color;
    notifyListeners();
    void setBackgroundColor(Color color) {
  backgroundColor = color;
  notifyListeners();
    }
  }

  void setBrushSize(double size) {
    activeBrush = activeBrush.copyWith(size: size);
    notifyListeners();
  }

  void setBrushOpacity(double opacity) {
    activeBrush = activeBrush.copyWith(opacity: opacity);
    notifyListeners();
  }

  void toggleSymmetry() {
    symmetryEnabled = !symmetryEnabled;
    currentMirrorStroke = null;
    notifyListeners();
  }

  void setSymmetryType(SymmetryType type) {
    symmetryType = type;
    notifyListeners();
  }

  void updateCanvasSize(Size size) {
    if (canvasSize != size) {
      canvasSize = size;
      invalidateAllCache();
    }
  }

  void clearActiveLayer() {
    final index = layers.indexWhere((l) => l.id == activeLayerId);
    if (index != -1) {
      _saveToHistory();
      layers[index] = layers[index].copyWith(strokes: []);
      invalidateLayerCache(activeLayerId);
      notifyListeners();
    }
  }

  void clearCanvas() {
    _saveToHistory();
    layers = layers.map((l) => l.copyWith(strokes: [])).toList();
    invalidateAllCache();
    notifyListeners();
  }
}

enum SymmetryType { horizontal, vertical, radial }
