import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../services/native_canvas_bridge.dart';

/// Carga los PNG de brush tips al GPU como texturas OpenGL ES.
class GpuBrushLoader {
  static final Map<String, int> _shapeTexIds = {};
  static bool _loaded = false;

  static bool get isLoaded => _loaded;
  static int  get loadedCount => _shapeTexIds.length;
  static int  get loadedCount => _shapeTexIds.length;
  static int shapeTexId(String brushId) => _shapeTexIds[brushId] ?? -1;

  static Future<void> loadAll(NativeCanvasBridge bridge) async {
    if (_loaded) return;
    for (final entry in _brushAssets.entries) {
      await _uploadTexture(bridge, entry.key, entry.value);
    }
    _loaded = true;
    // ignore: avoid_print
    print('[GpuBrushLoader] Cargadas ${_shapeTexIds.length}/${_brushAssets.length} texturas');
  }

  static Future<void> loadBrush(NativeCanvasBridge bridge, String brushId) async {
    if (_shapeTexIds.containsKey(brushId)) return;
    final path = _brushAssets[brushId];
    if (path != null) await _uploadTexture(bridge, brushId, path);
  }

  static Future<void> _uploadTexture(
      NativeCanvasBridge bridge, String brushId, String assetPath) async {
    try {
      final data  = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(), targetWidth: 256, targetHeight: 256);
      final frame = await codec.getNextFrame();
      final img   = frame.image;
      final bd    = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (bd == null) return;

      // El shader lee canal Alpha. Nuestros PNGs son grises (R=luminancia, A=255).
      // Mover luminancia → Alpha para que el shader vea la forma correctamente.
      final src = bd.buffer.asUint8List();
      final dst = Uint8List(src.length);
      for (int i = 0; i < src.length; i += 4) {
        dst[i]     = 255;
        dst[i + 1] = 255;
        dst[i + 2] = 255;
        dst[i + 3] = src[i]; // R → A
      }

      final texId = await bridge.loadBrushTexture(dst, 256, 256);
      if (texId >= 0) {
        _shapeTexIds[brushId] = texId;
        // ignore: avoid_print
        print('[GpuBrushLoader] ✅ $brushId → texId=$texId');
      } else {
        // ignore: avoid_print
        print('[GpuBrushLoader] ⚠️ $brushId → texId=-1');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[GpuBrushLoader] ❌ $brushId → $e');
    }
  }

  static Future<void> dispose(NativeCanvasBridge bridge) async {
    for (final texId in _shapeTexIds.values) {
      await bridge.unloadBrushTexture(texId);
    }
    _shapeTexIds.clear();
    _loaded = false;
  }

  // IDs exactos de BrushModel → ruta del asset shape PNG
  static const Map<String, String> _brushAssets = {
    // ── AEROSOLES (aero_xx) ──────────────────────────────────────────
    'aero_01': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aero_02': 'assets/brushes/aerosoles/aers_01_shape.png',
    'aero_03': 'assets/brushes/aerosoles/aers_03_shape.png',
    'aero_04': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aero_05': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aero_06': 'assets/brushes/aerosoles/aers_03_shape.png',
    'aero_07': 'assets/brushes/aerosoles/aers_04_shape.png',
    'aero_08': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aero_09': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aero_10': 'assets/brushes/aerosoles/aers_07_shape.png',
    'aero_11': 'assets/brushes/aerosoles/aers_06_shape.png',
    'aero_12': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aero_13': 'assets/brushes/aerosoles/aers_03_shape.png',
    'aero_14': 'assets/brushes/aerosoles/aers_14_shape.png',
    'aero_15': 'assets/brushes/aerosoles/aers_13_shape.png',

    // ── CALIGRAFÍA (cal_xx) ──────────────────────────────────────────
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

    // ── CARBONCILLO (car_xx) ─────────────────────────────────────────
    'car_01': 'assets/brushes/carboncillo/carb_01_shape.png',
    'car_02': 'assets/brushes/carboncillo/carb_02_shape.png',
    'car_03': 'assets/brushes/carboncillo/carb_03_shape.png',
    'car_04': 'assets/brushes/carboncillo/carb_04_shape.png',
    'car_05': 'assets/brushes/carboncillo/carb_05_shape.png',
    'car_06': 'assets/brushes/carboncillo/carb_06_shape.png',
    'car_07': 'assets/brushes/carboncillo/carb_07_shape.png',
    'car_08': 'assets/brushes/carboncillo/carb_08_shape.png',
    'car_09': 'assets/brushes/carboncillo/carb_09_shape.png',
    'car_10': 'assets/brushes/carboncillo/carb_10_shape.png',
    'car_11': 'assets/brushes/carboncillo/carb_11_shape.png',
    'car_12': 'assets/brushes/carboncillo/carb_12_shape.png',
    'car_13': 'assets/brushes/carboncillo/carb_13_shape.png',
    'car_14': 'assets/brushes/carboncillo/carb_14_shape.png',
    'car_15': 'assets/brushes/carboncillo/carb_14_shape.png', // reutiliza carb_14

    // ── LUMINANCIA (lum_xx) ──────────────────────────────────────────
    'lum_01': 'assets/brushes/luminancia/lumi_01_shape.png',
    'lum_02': 'assets/brushes/luminancia/lumi_02_shape.png',
    'lum_03': 'assets/brushes/luminancia/lumi_03_shape.png',
    'lum_04': 'assets/brushes/luminancia/lumi_04_shape.png',
    'lum_05': 'assets/brushes/luminancia/lumi_05_shape.png',
    'lum_06': 'assets/brushes/luminancia/lumi_06_shape.png',
    'lum_07': 'assets/brushes/luminancia/lumi_07_shape.png',
    'lum_08': 'assets/brushes/luminancia/lumi_08_shape.png',
    'lum_09': 'assets/brushes/luminancia/lumi_09_shape.png',
    'lum_10': 'assets/brushes/luminancia/lumi_10_shape.png',
    'lum_11': 'assets/brushes/luminancia/lumi_11_shape.png',
    'lum_12': 'assets/brushes/luminancia/lumi_12_shape.png',
    'lum_13': 'assets/brushes/luminancia/lumi_13_shape.png',
    'lum_14': 'assets/brushes/luminancia/lumi_14_shape.png',
    'lum_15': 'assets/brushes/luminancia/lumi_15_shape.png',

    // ── RETOQUE (ret_xx) ─────────────────────────────────────────────
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

    // ── ABSTRACTOS (abs_xx) — reutilizan aerosoles ───────────────────
    'abs_01': 'assets/brushes/aerosoles/aers_14_shape.png',
    'abs_02': 'assets/brushes/aerosoles/aers_06_shape.png',
    'abs_03': 'assets/brushes/aerosoles/aers_12_shape.png',
    'abs_04': 'assets/brushes/aerosoles/aers_12_shape.png',
    'abs_05': 'assets/brushes/aerosoles/aers_05_shape.png',
    'abs_06': 'assets/brushes/aerosoles/aers_09_shape.png',
    'abs_07': 'assets/brushes/aerosoles/aers_11_shape.png',
    'abs_08': 'assets/brushes/aerosoles/aers_09_shape.png',
    'abs_09': 'assets/brushes/aerosoles/aers_01_shape.png',
    'abs_10': 'assets/brushes/aerosoles/aers_12_shape.png',
    'abs_11': 'assets/brushes/aerosoles/aers_10_shape.png',
    'abs_12': 'assets/brushes/luminancia/lumi_06_shape.png',
    'abs_13': 'assets/brushes/luminancia/lumi_03_shape.png',
    'abs_14': 'assets/brushes/aerosoles/aers_09_shape.png',
    'abs_15': 'assets/brushes/luminancia/lumi_02_shape.png',

    // ── TEXTURAS (tex_xx) — reutilizan carboncillo ───────────────────
    'tex_01': 'assets/brushes/carboncillo/carb_03_shape.png',
    'tex_02': 'assets/brushes/carboncillo/carb_09_shape.png',
    'tex_03': 'assets/brushes/carboncillo/carb_08_shape.png',
    'tex_04': 'assets/brushes/carboncillo/carb_02_shape.png',
    'tex_05': 'assets/brushes/carboncillo/carb_03_shape.png',
    'tex_06': 'assets/brushes/carboncillo/carb_01_shape.png',
    'tex_07': 'assets/brushes/carboncillo/carb_10_shape.png',
    'tex_08': 'assets/brushes/carboncillo/carb_14_shape.png',
    'tex_09': 'assets/brushes/carboncillo/carb_13_shape.png',
    'tex_10': 'assets/brushes/carboncillo/carb_05_shape.png',
    'tex_11': 'assets/brushes/carboncillo/carb_11_shape.png',
    'tex_12': 'assets/brushes/carboncillo/carb_12_shape.png',
    'tex_13': 'assets/brushes/carboncillo/carb_06_shape.png',
    'tex_14': 'assets/brushes/carboncillo/carb_04_shape.png',
    'tex_15': 'assets/brushes/carboncillo/carb_07_shape.png',

    // ── ORGÁNICOS (org_xx) ───────────────────────────────────────────
    'org_01': 'assets/brushes/carboncillo/carb_03_shape.png',
    'org_02': 'assets/brushes/carboncillo/carb_12_shape.png',
    'org_03': 'assets/brushes/carboncillo/carb_08_shape.png',
    'org_04': 'assets/brushes/aerosoles/aers_11_shape.png',
    'org_05': 'assets/brushes/caligrafia/cali_08_shape.png',
    'org_06': 'assets/brushes/carboncillo/carb_10_shape.png',
    'org_07': 'assets/brushes/aerosoles/aers_10_shape.png',
    'org_08': 'assets/brushes/aerosoles/aers_06_shape.png',
    'org_09': 'assets/brushes/caligrafia/cali_07_shape.png',
    'org_10': 'assets/brushes/aerosoles/aers_11_shape.png',
    'org_11': 'assets/brushes/aerosoles/aers_09_shape.png',
    'org_12': 'assets/brushes/carboncillo/carb_10_shape.png',
    'org_13': 'assets/brushes/aerosoles/aers_14_shape.png',
    'org_14': 'assets/brushes/carboncillo/carb_12_shape.png',
    'org_15': 'assets/brushes/carboncillo/carb_09_shape.png',

    // ── ACUARELA (agua_xx) ───────────────────────────────────────────
    'agua_01': 'assets/brushes/aerosoles/aers_14_shape.png',
    'agua_02': 'assets/brushes/aerosoles/aers_01_shape.png',
    'agua_03': 'assets/brushes/caligrafia/cali_07_shape.png',
    'agua_04': 'assets/brushes/aerosoles/aers_05_shape.png',
    'agua_05': 'assets/brushes/aerosoles/aers_09_shape.png',
    'agua_06': 'assets/brushes/aerosoles/aers_14_shape.png',
    'agua_07': 'assets/brushes/caligrafia/cali_06_shape.png',
    'agua_08': 'assets/brushes/aerosoles/aers_14_shape.png',
    'agua_09': 'assets/brushes/aerosoles/aers_14_shape.png',
    'agua_10': 'assets/brushes/aerosoles/aers_03_shape.png',
    'agua_11': 'assets/brushes/aerosoles/aers_06_shape.png',
    'agua_12': 'assets/brushes/aerosoles/aers_09_shape.png',
    'agua_13': 'assets/brushes/caligrafia/cali_06_shape.png',
    'agua_14': 'assets/brushes/aerosoles/aers_14_shape.png',
    'agua_15': 'assets/brushes/aerosoles/aers_10_shape.png',

    // ── INDUSTRIALES (ind_xx) ────────────────────────────────────────
    'ind_01': 'assets/brushes/aerosoles/aers_06_shape.png',
    'ind_02': 'assets/brushes/aerosoles/aers_10_shape.png',
    'ind_03': 'assets/brushes/aerosoles/aers_10_shape.png',
    'ind_04': 'assets/brushes/caligrafia/cali_12_shape.png',
    'ind_05': 'assets/brushes/aerosoles/aers_06_shape.png',
    'ind_06': 'assets/brushes/aerosoles/aers_09_shape.png',
    'ind_07': 'assets/brushes/caligrafia/cali_07_shape.png',
    'ind_08': 'assets/brushes/carboncillo/carb_14_shape.png',
    'ind_09': 'assets/brushes/aerosoles/aers_10_shape.png',
    'ind_10': 'assets/brushes/carboncillo/carb_03_shape.png',
    'ind_11': 'assets/brushes/aerosoles/aers_09_shape.png',
    'ind_12': 'assets/brushes/caligrafia/cali_04_shape.png',
    'ind_13': 'assets/brushes/aerosoles/aers_10_shape.png',
    'ind_14': 'assets/brushes/carboncillo/carb_14_shape.png',
    'ind_15': 'assets/brushes/carboncillo/carb_03_shape.png',

    // ── IMPORTADOS (imp_xx) — reutilizan formas base ─────────────────
    'imp_01': 'assets/brushes/caligrafia/cali_03_shape.png',
    'imp_02': 'assets/brushes/caligrafia/cali_01_shape.png',
    'imp_03': 'assets/brushes/carboncillo/carb_04_shape.png',
    'imp_04': 'assets/brushes/aerosoles/aers_01_shape.png',
    'imp_05': 'assets/brushes/aerosoles/aers_01_shape.png',
    'imp_06': 'assets/brushes/aerosoles/aers_14_shape.png',
    'imp_07': 'assets/brushes/aerosoles/aers_06_shape.png',
    'imp_08': 'assets/brushes/carboncillo/carb_03_shape.png',
    'imp_09': 'assets/brushes/caligrafia/cali_01_shape.png',
    'imp_10': 'assets/brushes/carboncillo/carb_12_shape.png',
    'imp_11': 'assets/brushes/aerosoles/aers_14_shape.png',
    'imp_12': 'assets/brushes/caligrafia/cali_03_shape.png',
    'imp_13': 'assets/brushes/aerosoles/aers_01_shape.png',
    'imp_14': 'assets/brushes/aerosoles/aers_14_shape.png',
    'imp_15': 'assets/brushes/aerosoles/aers_01_shape.png',
  };
}
