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
  List<List<LayerModel>> _undoHistory = [];
  List<List<LayerModel>> _redoHistory = [];
  bool symmetryEnabled = false;
  SymmetryType symmetryType = SymmetryType.horizontal;
  double scale = 1.0;
  Offset offset = Offset.zero;
  Size canvasSize = const Size(1080, 1920);

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
    notifyListeners();
  }

  void continueStroke(Offset point) {
    if (currentStroke == null) return;
    final newPoints = List<Offset>.from(currentStroke!.points)
      ..add(point);

    if (symmetryEnabled) {
      final mirroredPoint = _getMirroredPoint(point);
      newPoints.add(mirroredPoint);
    }

    currentStroke = StrokeModel(
      points: newPoints,
      color: currentStroke!.color,
      strokeWidth: currentStroke!.strokeWidth,
      opacity: currentStroke!.opacity,
      type: currentStroke!.type,
      layerId: activeLayerId,
    );
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
          canvasSize.width - point.dx,
          canvasSize.height - point.dy,
        );
    }
  }

  void endStroke() {
    if (currentStroke == null) return;
    final layerIndex = layers.indexWhere(
      (l) => l.id == activeLayerId,
    );
    if (layerIndex != -1) {
      final updatedStrokes = List<StrokeModel>.from(
        layers[layerIndex].strokes,
      )..add(currentStroke!);
      layers[layerIndex] = layers[layerIndex].copyWith(
        strokes: updatedStrokes,
      );
    }
    currentStroke = null;
    notifyListeners();
  }

  void _saveToHistory() {
    _undoHistory.add(
      layers
          .map((l) => l.copyWith(
                strokes: List<StrokeModel>.from(l.strokes),
              ))
          .toList(),
    );
    _redoHistory.clear();
    if (_undoHistory.length > 50) {
      _undoHistory.removeAt(0);
    }
  }

  void undo() {
    if (_undoHistory.isEmpty) return;
    _redoHistory.add(
      layers
          .map((l) => l.copyWith(
                strokes: List<StrokeModel>.from(l.strokes),
              ))
          .toList(),
    );
    layers = _undoHistory.removeLast();
    notifyListeners();
  }

  void redo() {
    if (_redoHistory.isEmpty) return;
    _undoHistory.add(
      layers
          .map((l) => l.copyWith(
                strokes: List<StrokeModel>.from(l.strokes),
              ))
          .toList(),
    );
    layers = _redoHistory.removeLast();
    notifyListeners();
  }

  void addLayer() {
    final newId =
        layers.isEmpty ? 0 : layers.last.id + 1;
    layers.add(LayerModel(
      id: newId,
      name: 'Capa ${newId + 1}',
    ));
    activeLayerId = newId;
    notifyListeners();
  }

  void removeLayer(int layerId) {
    if (layers.length <= 1) return;
    layers.removeWhere((l) => l.id == layerId);
    if (activeLayerId == layerId) {
      activeLayerId = layers.last.id;
    }
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
    notifyListeners();
  }

  void clearActiveLayer() {
    final index = layers.indexWhere(
      (l) => l.id == activeLayerId,
    );
    if (index != -1) {
      _saveToHistory();
      layers[index] = layers[index].copyWith(strokes: []);
      notifyListeners();
    }
  }

  void clearCanvas() {
    _saveToHistory();
    layers = layers
        .map((l) => l.copyWith(strokes: []))
        .toList();
    notifyListeners();
  }
}

enum SymmetryType { horizontal, vertical, radial }
