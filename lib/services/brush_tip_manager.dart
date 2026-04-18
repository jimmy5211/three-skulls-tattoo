import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Gestor de brush tips PNG.
/// Carga imágenes desde assets/brushes/{categoria}/{brushId}.png
/// y las cachea en memoria para estamparlas a lo largo del trazo.
class BrushTipManager {
  static final Map<String, ui.Image> _cache = {};
  static final Set<String> _notFound = {}; // rutas que no existen

  // ── Mapeo de BrushCategory.name → carpeta en assets ──
  static const Map<String, String> _categoryFolders = {
    'todos': 'basicos',
    'caligrafia': 'caligrafia',
    'aerografo': 'aerografo',
    'texturas': 'texturas',
    'abstractos': 'abstractos',
    'carbonciilo': 'carboncillo',
    'elementos': 'elementos',
    'aerosoles': 'aerosoles',
    'retoque': 'retoque',
    'luminancia': 'luminancia',
    'industriales': 'industriales',
    'organicos': 'organicos',
    'agua': 'agua',
    'importado': 'importado',
  };

  /// Ruta al asset PNG de un pincel
  static String assetPath(String brushId, String categoryKey) {
    final folder = _categoryFolders[categoryKey] ?? 'basicos';
    return 'assets/brushes/$folder/$brushId.png';
  }

  /// Carga un brush tip PNG desde assets. Retorna null si no existe.
  static Future<ui.Image?> load(String brushId, String categoryKey) async {
    // Ya en caché
    if (_cache.containsKey(brushId)) return _cache[brushId];

    final path = assetPath(brushId, categoryKey);

    // Ya sabemos que no existe
    if (_notFound.contains(path)) return null;

    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 256, // Normalizar tamaño
        targetHeight: 256,
      );
      final frame = await codec.getNextFrame();
      _cache[brushId] = frame.image;
      return frame.image;
    } catch (_) {
      _notFound.add(path);
      return null;
    }
  }

  /// Obtiene el tip cacheado (null si no se ha cargado o no existe)
  static ui.Image? get(String brushId) => _cache[brushId];

  /// Precarga TODOS los pinceles default al iniciar la app
  static Future<void> preloadAll(List<dynamic> brushes) async {
    for (final brush in brushes) {
      await load(brush.id as String, (brush.category as Enum).name);
    }
  }

  /// Precarga una categoría específica
  static Future<void> preloadCategory(
      String categoryKey, List<String> brushIds) async {
    for (final id in brushIds) {
      await load(id, categoryKey);
    }
  }

  /// Limpia toda la caché
  static void clearCache() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _notFound.clear();
  }

  /// ¿Tiene tip cargado este pincel?
  static bool hasTip(String brushId) => _cache.containsKey(brushId);
}
