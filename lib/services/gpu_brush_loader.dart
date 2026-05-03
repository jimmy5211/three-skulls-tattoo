import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../services/native_canvas_bridge.dart';

/// Carga los PNG de brush tips al GPU como texturas OpenGL ES.
/// Cada pincel tiene una textura de forma (shape) y opcionalmente de grano (grain).
///
/// Los IDs GPU se guardan en memoria y se pasan a beginStroke como brushTexId.
/// -1 = usar Gaussian default del motor C++.
class GpuBrushLoader {
  static final Map<String, int> _shapeTexIds = {};  // brushId → GPU tex ID
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// Devuelve el GPU tex ID del shape para un brushId. -1 si no existe.
  static int shapeTexId(String brushId) => _shapeTexIds[brushId] ?? -1;

  /// Precarga todas las texturas disponibles al GPU.
  /// Llamar DESPUÉS de bridge.init() y ANTES del primer trazo.
  static Future<void> loadAll(NativeCanvasBridge bridge) async {
    if (_loaded) return;

    for (final entry in _brushAssets.entries) {
      final brushId  = entry.key;
      final shapePath = entry.value;
      await _uploadTexture(bridge, brushId, shapePath);
    }

    _loaded = true;
  }

  /// Carga un único brush tip al GPU. Útil para lazy loading.
  static Future<void> loadBrush(
      NativeCanvasBridge bridge, String brushId) async {
    if (_shapeTexIds.containsKey(brushId)) return;
    final path = _brushAssets[brushId];
    if (path != null) await _uploadTexture(bridge, brushId, path);
  }

  static Future<void> _uploadTexture(
      NativeCanvasBridge bridge, String brushId, String assetPath) async {
    try {
      final data  = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      // Decodificar PNG → RGBA 256×256
      final codec = await ui.instantiateImageCodec(
          bytes, targetWidth: 256, targetHeight: 256);
      final frame = await codec.getNextFrame();
      final img   = frame.image;
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (byteData == null) return;

      // FIX CRÍTICO: el shader GPU lee el canal Alpha (texture.a) como máscara.
      // Nuestras brush tips son PNGs grises: el shape está en R/G/B, pero Alpha=255.
      // → Mover luminosidad (canal R) al canal Alpha para que el shader funcione.
      // Resultado: blanco (255) = opaco, negro (0) = transparente.
      final src  = byteData.buffer.asUint8List();
      final dst  = Uint8List(src.length);
      for (int i = 0; i < src.length; i += 4) {
        final lum = src[i]; // R = luminosidad en PNG grayscale-as-RGBA
        dst[i]     = 255;   // R (no importa — el shader usa solo A)
        dst[i + 1] = 255;   // G
        dst[i + 2] = 255;   // B
        dst[i + 3] = lum;   // A = shape mask ← esto es lo que lee el shader
      }

      final texId = await bridge.loadBrushTexture(dst, 256, 256);
      if (texId >= 0) {
        _shapeTexIds[brushId] = texId;
      }
    } catch (_) {
      // Textura no disponible → el motor usará el Gaussian default
    }
  }

  /// Libera todas las texturas GPU. Llamar al destruir el bridge.
  static Future<void> dispose(NativeCanvasBridge bridge) async {
    for (final texId in _shapeTexIds.values) {
      await bridge.unloadBrushTexture(texId);
    }
    _shapeTexIds.clear();
    _loaded = false;
  }

  // ── Mapa brushId → ruta del asset shape PNG ─────────────────────────
  // Las texturas de grano (grain) no se cargan al GPU en esta fase:
  // el motor C++ usa el shape como alfa del stamp; el grain se añade
  // en la Fase 5 cuando se implemente el segundo sampler en el shader.
  static const Map<String, String> _brushAssets = {
    // ── AEROSOLES ────────────────────────────────────────────────────
    'aers_01': 'assets/brushes/aerosoles/aers_01_shape.png',
    'aers_02': 'assets/brushes/aerosoles/aers_02_shape.png',
    'aers_03': 'assets/brushes/aerosoles/aers_03_shape.png',
    'aers_04': 'assets/brushes/aerosoles/aers_04_shape.png',
    'aers_05': 'assets/brushes/aerosoles/aers_05_shape.png',
    'aers_06': 'assets/brushes/aerosoles/aers_06_shape.png',
    'aers_07': 'assets/brushes/aerosoles/aers_07_shape.png',
    'aers_08': 'assets/brushes/aerosoles/aers_08_shape.png',
    'aers_09': 'assets/brushes/aerosoles/aers_09_shape.png',
    'aers_10': 'assets/brushes/aerosoles/aers_10_shape.png',
    'aers_11': 'assets/brushes/aerosoles/aers_11_shape.png',
    'aers_12': 'assets/brushes/aerosoles/aers_12_shape.png',
    'aers_13': 'assets/brushes/aerosoles/aers_13_shape.png',
    'aers_14': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aers_15': 'assets/brushes/aerosoles/aers_15_shape.png',

    // ── CARBONCILLO ──────────────────────────────────────────────────
    'carb_01': 'assets/brushes/carboncillo/carb_01_shape.png',
    'carb_02': 'assets/brushes/carboncillo/carb_02_shape.png',
    'carb_03': 'assets/brushes/carboncillo/carb_03_shape.png',
    'carb_04': 'assets/brushes/carboncillo/carb_04_shape.png',
    'carb_05': 'assets/brushes/carboncillo/carb_05_shape.png',
    'carb_06': 'assets/brushes/carboncillo/carb_06_shape.png',
    'carb_07': 'assets/brushes/carboncillo/carb_07_shape.png',
    'carb_08': 'assets/brushes/carboncillo/carb_08_shape.png',
    'carb_09': 'assets/brushes/carboncillo/carb_09_shape.png',
    'carb_10': 'assets/brushes/carboncillo/carb_10_shape.png',
    'carb_11': 'assets/brushes/carboncillo/carb_11_shape.png',
    'carb_12': 'assets/brushes/carboncillo/carb_12_shape.png',
    'carb_13': 'assets/brushes/carboncillo/carb_13_shape.png',
    'carb_14': 'assets/brushes/carboncillo/carb_14_shape.png',

    // ── CALIGRAFÍA ───────────────────────────────────────────────────
    // Nota: IDs en BrushModel usan prefijo 'cal_', texturas usan 'cali_'
    'cal_01': 'assets/brushes/caligrafia/cali_01_shape.png',
    'cal_02': 'assets/brushes/caligrafia/cali_02_shape.png',
    'cal_03': 'assets/brushes/caligrafia/cali_03_shape.png',
    'cal_04': 'assets/brushes/caligrafia/cali_04_shape.png',
    'cal_05': 'assets/brushes/caligrafia/cali_05_shape.png',
    'cal_06': 'assets/brushes/caligrafia/cali_06_shape.png',
    'cal_07': 'assets/brushes/caligrafia/cali_07_shape.png',
    'cal_08': 'assets/brushes/caligrafia/cali_08_shape.png',
    'cal_09': 'assets/brushes/caligrafia/cali_09_shape.png',
    'cal_10': 'assets/brushes/caligrafia/cali_10_shape.png',
    'cal_11': 'assets/brushes/caligrafia/cali_11_shape.png',
    'cal_12': 'assets/brushes/caligrafia/cali_12_shape.png',
    'cal_13': 'assets/brushes/caligrafia/cali_13_shape.png',
    'cal_14': 'assets/brushes/caligrafia/cali_14_shape.png',
    'cal_15': 'assets/brushes/caligrafia/cali_15_shape.png',

    // ── LUMINANCIA ───────────────────────────────────────────────────
    'lumi_01': 'assets/brushes/luminancia/lumi_01_shape.png',
    'lumi_02': 'assets/brushes/luminancia/lumi_02_shape.png',
    'lumi_03': 'assets/brushes/luminancia/lumi_03_shape.png',
    'lumi_04': 'assets/brushes/luminancia/lumi_04_shape.png',
    'lumi_05': 'assets/brushes/luminancia/lumi_05_shape.png',
    'lumi_06': 'assets/brushes/luminancia/lumi_06_shape.png',
    'lumi_07': 'assets/brushes/luminancia/lumi_07_shape.png',
    'lumi_08': 'assets/brushes/luminancia/lumi_08_shape.png',
    'lumi_09': 'assets/brushes/luminancia/lumi_09_shape.png',
    'lumi_10': 'assets/brushes/luminancia/lumi_10_shape.png',
    'lumi_11': 'assets/brushes/luminancia/lumi_11_shape.png',
    'lumi_12': 'assets/brushes/luminancia/lumi_12_shape.png',
    'lumi_13': 'assets/brushes/luminancia/lumi_13_shape.png',
    'lumi_14': 'assets/brushes/luminancia/lumi_14_shape.png',
    'lumi_15': 'assets/brushes/luminancia/lumi_15_shape.png',

    // ── AERÓGRAFO (aero_xx → mismas texturas de aerosoles reutilizadas) ─
    'aero_01': 'assets/brushes/aerosoles/aers_14_shape.png', // suave
    'aero_02': 'assets/brushes/aerosoles/aers_01_shape.png', // medio
    'aero_03': 'assets/brushes/aerosoles/aers_03_shape.png', // duro
    'aero_04': 'assets/brushes/aerosoles/aers_14_shape.png', // difuminado
    'aero_05': 'assets/brushes/aerosoles/aers_14_shape.png', // niebla
    'aero_06': 'assets/brushes/aerosoles/aers_03_shape.png', // spray fino
    'aero_07': 'assets/brushes/aerosoles/aers_04_shape.png', // spray grueso
    'aero_08': 'assets/brushes/aerosoles/aers_14_shape.png', // degradado
    'aero_09': 'assets/brushes/aerosoles/aers_14_shape.png', // sombra suave
    'aero_10': 'assets/brushes/aerosoles/aers_07_shape.png', // luz suave
    'aero_11': 'assets/brushes/aerosoles/aers_06_shape.png', // contorno
    'aero_12': 'assets/brushes/aerosoles/aers_14_shape.png', // nube
    'aero_13': 'assets/brushes/aerosoles/aers_03_shape.png', // puntual
    'aero_14': 'assets/brushes/aerosoles/aers_14_shape.png', // bruma
    'aero_15': 'assets/brushes/aerosoles/aers_13_shape.png', // flash/chrome

    // ── RETOQUE ──────────────────────────────────────────────────────
    'ret_01': 'assets/brushes/retoque/ret_01_shape.png',
    'ret_02': 'assets/brushes/retoque/ret_02_shape.png',
    'ret_03': 'assets/brushes/retoque/ret_03_shape.png',
    'ret_04': 'assets/brushes/retoque/ret_04_shape.png',
    'ret_05': 'assets/brushes/retoque/ret_05_shape.png',
    'ret_06': 'assets/brushes/retoque/ret_06_shape.png',
    'ret_07': 'assets/brushes/retoque/ret_07_shape.png',
    'ret_08': 'assets/brushes/retoque/ret_08_shape.png',
    'ret_09': 'assets/brushes/retoque/ret_09_shape.png',
    'ret_10': 'assets/brushes/retoque/ret_10_shape.png',
    'ret_11': 'assets/brushes/retoque/ret_11_shape.png',
    'ret_12': 'assets/brushes/retoque/ret_12_shape.png',
    'ret_13': 'assets/brushes/retoque/ret_13_shape.png',
    'ret_14': 'assets/brushes/retoque/ret_14_shape.png',
    'ret_15': 'assets/brushes/retoque/ret_15_shape.png',
  };
}
