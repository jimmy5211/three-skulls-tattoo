import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/layer_model.dart';
import '../models/brush_model.dart';
import '../models/canvas_image_model.dart';
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
  Color backgroundColor = Colors.transparent;

  // ─── IMÁGENES EN CANVAS ──────────────────────────────────
  List<CanvasImageModel> canvasImages = [];
  CanvasImageModel? _selectedImage;

  // FIX: Separar tamaño del lienzo real del tamaño de pantalla
  // screenSize = tamaño de la pantalla (se actualiza automáticamente)
  // canvasSize = tamaño real del lienzo (configurable por el usuario)
  Size screenSize = const Size(360, 772);
  Size canvasSize = const Size(1080, 1920);

  // Cache de capas renderizadas
  final Map<int, ui.Picture?> _layerCache = {};
  bool _cacheInvalidated = false;
  // Flag para forzar repaint cuando cambian imágenes (posición, resize, flip, borrador)
  bool _imagesChanged = false;
  bool get imagesChanged => _imagesChanged;
  void resetImagesChanged() => _imagesChanged = false;

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

  // Simplificación de puntos
  List<Offset> _simplifyPoints(
      List<Offset> points, double tolerance) {
    if (points.length <= 2) return points;
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

    if (currentStroke!.points.isNotEmpty) {
      final lastPoint = currentStroke!.points.last;
      final minDist = activeBrush.size * 0.15;
      if ((point - lastPoint).distance < minDist) return;
    }

    final newPoints =
        List<Offset>.from(currentStroke!.points)..add(point);

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
      final mirrorPoints =
          List<Offset>.from(currentMirrorStroke!.points)
            ..add(mirroredPoint);

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

    final layerIndex =
        layers.indexWhere((l) => l.id == activeLayerId);

    if (layerIndex != -1) {
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

      final updatedStrokes =
          List<StrokeModel>.from(layers[layerIndex].strokes)
            ..add(simplifiedStroke);

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

      layers[layerIndex] =
          layers[layerIndex].copyWith(strokes: updatedStrokes);
      invalidateLayerCache(activeLayerId);
    }

    currentStroke = null;
    currentMirrorStroke = null;

    // Si el trazo que terminó era un borrador, consolidar la capa.
    // Esto "aplana" los huecos del borrador en la imagen permanentemente.
    // Los trazos anteriores al borrador se fusionan con el resultado del borrado.
    // Resultado: lienzo limpio sin huecos "fantasma" que afecten trazos futuros.
    if (simplifiedStroke.type == StrokeType.eraser) {
      // Consolidar async — no bloquea UI
      _consolidateEraserStrokes(layerIndex).then((_) => notifyListeners());
    }

    notifyListeners();
  }

  /// Consolida los strokes hasta e incluyendo el último borrador
  /// en una imagen rasterizada permanente (CanvasImageModel con layerId).
  /// Los strokes posteriores al borrador se conservan como vectores.
  /// Resultado: los huecos del borrador son permanentes y no afectan
  /// nada que se dibuje después.
  Future<void> _consolidateEraserStrokes(int layerIndex) async {
    if (layerIndex < 0) return;
    final layer = layers[layerIndex];
    final strokes = layer.strokes;
    if (strokes.isEmpty) return;

    // Encontrar el último borrador
    final lastEraserIdx = strokes.lastIndexWhere(
        (s) => s.type == StrokeType.eraser);
    if (lastEraserIdx < 0) return;

    // Strokes a consolidar (hasta e incluyendo el borrador)
    final strokesToConsolidate = strokes.sublist(0, lastEraserIdx + 1);
    // Strokes posteriores — se conservan como vectores
    final strokesAfter = strokes.sublist(lastEraserIdx + 1);

    // Rasterizar strokesToConsolidate a imagen transparente
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    // Fondo transparente
    final rect = ui.Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    
    // Dibujar en orden temporal (igual que el painter)
    for (final stroke in strokesToConsolidate) {
      _drawStrokeToCanvas(canvas, stroke);
    }
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );

    // Agregar como imagen de la capa (no se verá borde ni handles)
    final consolidated = CanvasImageModel(
      id: 'consolidated_${layer.id}_${DateTime.now().millisecondsSinceEpoch}',
      image: image,
      position: ui.Offset.zero,
      size: canvasSize,
      layerId: layer.id,
      opacity: 1.0,
    );
    canvasImages.add(consolidated);

    // Reemplazar strokes con solo los posteriores al borrador
    layers[layerIndex] = layer.copyWith(strokes: strokesAfter);
    invalidateLayerCache(layer.id);
    _imagesChanged = true;
  }

  /// Dibuja un stroke en un canvas de rasterización
  void _drawStrokeToCanvas(ui.Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;
    
    final paint = ui.Paint()
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth * 2;

    if (stroke.type == StrokeType.eraser) {
      paint.blendMode = ui.BlendMode.dstOut;
      paint.color = const ui.Color(0xFFFFFFFF);
    } else {
      paint.color = stroke.color.withOpacity(stroke.opacity);
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth, paint);
      return;
    }

    final path = ui.Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      final mid = ui.Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
          stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  Offset _getMirroredPoint(Offset point) {
    switch (symmetryType) {
      case SymmetryType.horizontal:
        return Offset(canvasSize.width - point.dx, point.dy);
      case SymmetryType.vertical:
        return Offset(point.dx, canvasSize.height - point.dy);
      case SymmetryType.radial:
        return Offset(canvasSize.width - point.dx,
            canvasSize.height - point.dy);
    }
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
    if (_undoHistory.length > 30) {
      _undoHistory.removeAt(0);
    }
  }

  void undo() {
    if (_undoHistory.isEmpty) return;
    _redoHistory.add(layers
        .map((l) => l.copyWith(
              strokes: List<StrokeModel>.from(l.strokes),
            ))
        .toList());
    layers = _undoHistory.removeLast();
    invalidateAllCache();
    notifyListeners();
  }

  void redo() {
    if (_redoHistory.isEmpty) return;
    _undoHistory.add(layers
        .map((l) => l.copyWith(
              strokes: List<StrokeModel>.from(l.strokes),
            ))
        .toList());
    layers = _redoHistory.removeLast();
    invalidateAllCache();
    notifyListeners();
  }

  void addLayer() {
    final newId =
        layers.isEmpty ? 0 : layers.last.id + 1;
    layers
        .add(LayerModel(id: newId, name: 'Capa ${newId + 1}'));
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
    final index =
        layers.indexWhere((l) => l.id == layerId);
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
    final index =
        layers.indexWhere((l) => l.id == layerId);
    if (index <= 0) return;
    _saveToHistory();
    final current = layers[index];
    final below = layers[index - 1];
    final mergedStrokes = [
      ...below.strokes,
      ...current.strokes
    ];
    layers[index - 1] =
        below.copyWith(strokes: mergedStrokes);
    layers.removeAt(index);
    activeLayerId = layers[index - 1].id;
    invalidateLayerCache(below.id);
    notifyListeners();
  }

  void lockLayer(int layerId) {
    final index =
        layers.indexWhere((l) => l.id == layerId);
    if (index == -1) return;
    layers[index] = layers[index].copyWith(
      isLocked: !layers[index].isLocked,
    );
    notifyListeners();
  }

  void flattenLayers() {
    if (layers.length <= 1) return;
    _saveToHistory();
    final allStrokes =
        layers.expand((l) => l.strokes).toList();
    layers = [
      LayerModel(id: 0, name: 'Capa 1', strokes: allStrokes)
    ];
    activeLayerId = 0;
    invalidateAllCache();
    notifyListeners();
  }

  void setActiveLayer(int layerId) {
    activeLayerId = layerId;
    notifyListeners();
  }

  void toggleLayerVisibility(int layerId) {
    final index =
        layers.indexWhere((l) => l.id == layerId);
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

  void setBackgroundColor(Color color) {
    backgroundColor = color;
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
    currentMirrorStroke = null;
    notifyListeners();
  }

  void setSymmetryType(SymmetryType type) {
    symmetryType = type;
    notifyListeners();
  }

  // FIX: updateScreenSize actualiza solo el tamaño de pantalla
  // sin afectar el tamaño real del lienzo
  void updateScreenSize(Size size) {
    if (screenSize != size) {
      screenSize = size;
      // No invalidar cache — la pantalla cambió, no el lienzo
    }
  }

  // FIX: updateCanvasSize cambia el tamaño real del lienzo
  // (lo que antes se llamaba igual pero era confuso)
  void updateCanvasSize(Size size) {
    if (canvasSize != size) {
      canvasSize = size;
      invalidateAllCache();
      notifyListeners();
    }
  }

  // FIX: centrar el lienzo en la pantalla
  // Retorna el offset necesario para centrar el lienzo
  Offset get centeredOffset {
    final scaleX = screenSize.width / canvasSize.width;
    final scaleY = screenSize.height / canvasSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final scaledW = canvasSize.width * scale;
    final scaledH = canvasSize.height * scale;
    return Offset(
      (screenSize.width - scaledW) / 2,
      (screenSize.height - scaledH) / 2,
    );
  }

  // FIX: escala inicial para que el lienzo quepa en pantalla
  double get initialScale {
    final scaleX = screenSize.width / canvasSize.width;
    final scaleY = screenSize.height / canvasSize.height;
    return (scaleX < scaleY ? scaleX : scaleY) * 0.9;
  }

  void clearActiveLayer() {
    final index =
        layers.indexWhere((l) => l.id == activeLayerId);
    if (index != -1) {
      _saveToHistory();
      layers[index] =
          layers[index].copyWith(strokes: []);
      invalidateLayerCache(activeLayerId);
      notifyListeners();
    }
  }

  // ─── MÉTODOS DE IMAGEN ───────────────────────────────────

  void addCanvasImage(ui.Image image) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final maxW = canvasSize.width * 0.6;
    final maxH = canvasSize.height * 0.6;
    final scale = min(maxW / imgW, maxH / imgH).clamp(0.01, 1.0);
    final scaledW = imgW * scale;
    final scaledH = imgH * scale;
    final pos = Offset(
      (canvasSize.width - scaledW) / 2,
      (canvasSize.height - scaledH) / 2,
    );
    canvasImages.add(CanvasImageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      image: image,
      position: pos,
      size: Size(scaledW, scaledH),
      layerId: activeLayerId, // asociar a la capa activa
    ));
    _imagesChanged = true;
    notifyListeners();
  }

  void removeCanvasImage(String id) {
    canvasImages.removeWhere((img) => img.id == id);
    notifyListeners();
  }

  void setCanvasImagePosition(String id, Offset position) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].position = position;
    _imagesChanged = true;
    notifyListeners();
  }

  void setCanvasImageRect(String id, Rect rect) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].position = rect.topLeft;
    canvasImages[idx].size = rect.size;
    _imagesChanged = true;
    notifyListeners();
  }

  void toggleFlipX(String id) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].flipX = !canvasImages[idx].flipX;
    _imagesChanged = true;
    notifyListeners();
  }

  void toggleFlipY(String id) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].flipY = !canvasImages[idx].flipY;
    _imagesChanged = true;
    notifyListeners();
  }

  void setCanvasImageRotation(String id, double rotation) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].rotation = rotation;
    _imagesChanged = true;
    notifyListeners();
  }

  void rotateSelected(Offset center, double angle) {
    if (selectedStrokeIndices.isEmpty) return;
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    final cosA = cos(angle);
    final sinA = sin(angle);
    final strokes = List<StrokeModel>.from(layers[idx].strokes);
    for (final i in selectedStrokeIndices) {
      if (i < strokes.length) {
        strokes[i] = strokes[i].copyWith(
          points: strokes[i].points.map((p) {
            final dx = p.dx - center.dx;
            final dy = p.dy - center.dy;
            return Offset(
              center.dx + dx * cosA - dy * sinA,
              center.dy + dx * sinA + dy * cosA,
            );
          }).toList(),
        );
      }
    }
    layers[idx] = layers[idx].copyWith(strokes: strokes);
    invalidateLayerCache(activeLayerId);
    notifyListeners();
  }

  void moveCanvasImage(String id, Offset delta) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].position += delta;
    notifyListeners();
  }

  void selectCanvasImage(String? id) {
    for (final img in canvasImages) {
      img.isSelected = img.id == id;
    }
    _selectedImage = id == null
        ? null
        : canvasImages.firstWhere((img) => img.id == id,
            orElse: () => canvasImages.first);
    notifyListeners();
  }

  CanvasImageModel? imageAtPoint(Offset point) {
    for (final img in canvasImages.reversed) {
      if (img.rect.contains(point)) return img;
    }
    return null;
  }

  void scaleCanvasImage(String id, double scaleFactor) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    final img = canvasImages[idx];
    final newW = (img.size.width * scaleFactor).clamp(20.0, canvasSize.width);
    final newH = (img.size.height * scaleFactor).clamp(20.0, canvasSize.height);
    canvasImages[idx].size = Size(newW, newH);
    notifyListeners();
  }

  void clearCanvasImages() {
    canvasImages.clear();
    notifyListeners();
  }

  // ─── BORRADOR EN IMAGEN ──────────────────────────────────

  void startEraseOnImage(String id, Offset point, double radius) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].currentEraseStroke = EraseStroke(
      points: [point],
      radius: radius,
    );
    notifyListeners();
  }

  void continueEraseOnImage(String id, Offset point) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    final current = canvasImages[idx].currentEraseStroke;
    if (current == null) return;
    final last = current.points.last;
    // Distancia mínima: 30% del radio o 4px mínimo para suavidad
    final minDist = max(current.radius * 0.3, 4.0);
    if ((last - point).distance < minDist) return;
    current.points.add(point);
    // Solo notificar cada 3 puntos para reducir repaints sin perder fluidez
    if (current.points.length % 3 == 0) {
      _imagesChanged = true;
      notifyListeners();
    }
  }

  void endEraseOnImage(String id) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    final current = canvasImages[idx].currentEraseStroke;
    if (current != null) {
      canvasImages[idx].eraseStrokes.add(current);
      canvasImages[idx].currentEraseStroke = null;
    }
    _imagesChanged = true;
    notifyListeners();
  }

  void undoLastEraseOnImage(String id) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    if (canvasImages[idx].eraseStrokes.isNotEmpty) {
      canvasImages[idx].eraseStrokes.removeLast();
      _imagesChanged = true;
      notifyListeners();
    }
  }

  void clearErasesOnImage(String id) {
    final idx = canvasImages.indexWhere((img) => img.id == id);
    if (idx == -1) return;
    canvasImages[idx].eraseStrokes.clear();
    canvasImages[idx].currentEraseStroke = null;
    _imagesChanged = true;
    notifyListeners();
  }

  void clearCanvas() {
    _saveToHistory();
    layers =
        layers.map((l) => l.copyWith(strokes: [])).toList();
    invalidateAllCache();
    notifyListeners();
  }

  // ─── SELECCIÓN ───────────────────────────────────────────

  List<int> selectedStrokeIndices = [];
  List<StrokeModel> _clipboard = [];
  bool get hasSelection => selectedStrokeIndices.isNotEmpty;
  bool get hasClipboard => _clipboard.isNotEmpty;

  List<StrokeModel> get selectedStrokes {
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return [];
    final strokes = layers[idx].strokes;
    return selectedStrokeIndices
        .where((i) => i < strokes.length)
        .map((i) => strokes[i])
        .toList();
  }

  Rect? get selectionBounds {
    final strokes = selectedStrokes;
    if (strokes.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final s in strokes) {
      for (final p in s.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void selectStrokesInRect(Rect rect) {
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    selectedStrokeIndices = [];
    final strokes = layers[idx].strokes;
    for (int i = 0; i < strokes.length; i++) {
      if (strokes[i].points.any((p) => rect.contains(p))) {
        selectedStrokeIndices.add(i);
      }
    }
    notifyListeners();
  }

  void selectStrokesInPath(Path path) {
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    selectedStrokeIndices = [];
    final strokes = layers[idx].strokes;
    for (int i = 0; i < strokes.length; i++) {
      if (strokes[i].points.any((p) => path.contains(p))) {
        selectedStrokeIndices.add(i);
      }
    }
    notifyListeners();
  }

  void selectStrokesInEllipse(Rect rect) {
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    selectedStrokeIndices = [];
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    if (rx <= 0 || ry <= 0) return;
    final strokes = layers[idx].strokes;
    for (int i = 0; i < strokes.length; i++) {
      if (strokes[i].points.any((p) {
        final dx = (p.dx - cx) / rx;
        final dy = (p.dy - cy) / ry;
        return dx * dx + dy * dy <= 1.0;
      })) {
        selectedStrokeIndices.add(i);
      }
    }
    notifyListeners();
  }

  void selectStrokesNear(Offset point, double radius) {
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    selectedStrokeIndices = [];
    final strokes = layers[idx].strokes;
    for (int i = 0; i < strokes.length; i++) {
      if (strokes[i].points.any((p) => (p - point).distance <= radius)) {
        selectedStrokeIndices.add(i);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedStrokeIndices = [];
    notifyListeners();
  }

  void moveSelected(Offset delta) {
    if (selectedStrokeIndices.isEmpty) return;
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    final strokes = List<StrokeModel>.from(layers[idx].strokes);
    for (final i in selectedStrokeIndices) {
      if (i < strokes.length) {
        strokes[i] = strokes[i].copyWith(
          points: strokes[i].points.map((p) => p + delta).toList(),
        );
      }
    }
    layers[idx] = layers[idx].copyWith(strokes: strokes);
    invalidateLayerCache(activeLayerId);
    notifyListeners();
  }

  void cutSelected() {
    if (selectedStrokeIndices.isEmpty) return;
    _saveToHistory();
    _clipboard = selectedStrokes
        .map((s) => s.copyWith(points: List<Offset>.from(s.points)))
        .toList();
    _removeSelected();
  }

  void copySelected() {
    if (selectedStrokeIndices.isEmpty) return;
    _clipboard = selectedStrokes
        .map((s) => s.copyWith(points: List<Offset>.from(s.points)))
        .toList();
  }

  void paste() {
    if (_clipboard.isEmpty) return;
    _saveToHistory();
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    const delta = Offset(30, 30);
    final pasted = _clipboard.map((s) => s.copyWith(
      points: s.points.map((p) => p + delta).toList(),
      layerId: activeLayerId,
    )).toList();
    final updated = List<StrokeModel>.from(layers[idx].strokes)..addAll(pasted);
    layers[idx] = layers[idx].copyWith(strokes: updated);
    // Seleccionar los strokes recién pegados
    final base = layers[idx].strokes.length - pasted.length;
    selectedStrokeIndices = List.generate(pasted.length, (i) => base + i);
    invalidateLayerCache(activeLayerId);
    notifyListeners();
  }

  void deleteSelected() {
    if (selectedStrokeIndices.isEmpty) return;
    _saveToHistory();
    _removeSelected();
  }

  void _removeSelected() {
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    final toRemove = Set<int>.from(selectedStrokeIndices);
    final strokes = layers[idx].strokes;
    final newStrokes = [
      for (int i = 0; i < strokes.length; i++)
        if (!toRemove.contains(i)) strokes[i]
    ];
    layers[idx] = layers[idx].copyWith(strokes: newStrokes);
    selectedStrokeIndices = [];
    invalidateLayerCache(activeLayerId);
    notifyListeners();
  }

  void scaleSelectedStrokes(Offset center, double scaleX, double scaleY) {
    if (selectedStrokeIndices.isEmpty) return;
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    final strokes = List<StrokeModel>.from(layers[idx].strokes);
    for (final i in selectedStrokeIndices) {
      if (i < strokes.length) {
        strokes[i] = strokes[i].copyWith(
          points: strokes[i].points.map((p) {
            return Offset(
              (p.dx - center.dx) * scaleX + center.dx,
              (p.dy - center.dy) * scaleY + center.dy,
            );
          }).toList(),
        );
      }
    }
    layers[idx] = layers[idx].copyWith(strokes: strokes);
    invalidateLayerCache(activeLayerId);
    notifyListeners();
  }

  void colorSelected(Color color) {
    if (selectedStrokeIndices.isEmpty) return;
    _saveToHistory();
    final idx = layers.indexWhere((l) => l.id == activeLayerId);
    if (idx == -1) return;
    final strokes = List<StrokeModel>.from(layers[idx].strokes);
    for (final i in selectedStrokeIndices) {
      if (i < strokes.length) {
        strokes[i] = strokes[i].copyWith(color: color);
      }
    }
    layers[idx] = layers[idx].copyWith(strokes: strokes);
    invalidateLayerCache(activeLayerId);
    notifyListeners();
  }

  void saveSelectionMoveToHistory() => _saveToHistory();
}

enum SymmetryType { horizontal, vertical, radial }
