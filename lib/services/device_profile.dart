import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Perfil de rendimiento del dispositivo.
/// Detecta automáticamente el tier y ajusta parámetros de la app.
class DeviceProfile {
  // ── Singleton ────────────────────────────────────────────────
  static DeviceProfile? _instance;
  static DeviceProfile get instance => _instance ?? DeviceProfile._mid();

  final String tierName;        // 'high' | 'mid' | 'low'

  // Canvas
  final int defaultCanvasWidth;
  final int defaultCanvasHeight;

  // Historial undo
  final int maxUndoSteps;

  // Sellos / imágenes
  final int stampLoadSize;      // targetWidth/Height al cargar PNG

  // Strokes
  final double simplifyMin;     // clamp mínimo de tolerancia de simplificación
  final double simplifyMax;     // clamp máximo
  final double minDistMultiplier; // porcentaje del brush.size para mínima distancia

  // Rendering
  final int eraseRepaintEvery;  // repaints cada N puntos del borrador
  final int maxCachedLayers;    // máximo de capas en caché simultáneas

  const DeviceProfile._({
    required this.tierName,
    required this.defaultCanvasWidth,
    required this.defaultCanvasHeight,
    required this.maxUndoSteps,
    required this.stampLoadSize,
    required this.simplifyMin,
    required this.simplifyMax,
    required this.minDistMultiplier,
    required this.eraseRepaintEvery,
    required this.maxCachedLayers,
  });

  // ── Tiers predefinidos ───────────────────────────────────────

  /// Gama alta: flagship / mid-high (≥8GB RAM, API ≥31, GPU potente)
  const DeviceProfile._high() : this._(
    tierName: 'high',
    defaultCanvasWidth: 1080,
    defaultCanvasHeight: 1920,
    maxUndoSteps: 30,
    stampLoadSize: 512,
    simplifyMin: 0.5,
    simplifyMax: 3.0,
    minDistMultiplier: 0.15,
    eraseRepaintEvery: 3,
    maxCachedLayers: 8,
  );

  /// Gama media: mid-range (4-6GB RAM, API 28-30, o gama alta con Android viejo)
  const DeviceProfile._mid() : this._(
    tierName: 'mid',
    defaultCanvasWidth: 1080,
    defaultCanvasHeight: 1920,
    maxUndoSteps: 20,
    stampLoadSize: 256,
    simplifyMin: 0.5,   // mantener precisión, solo reducir RAM
    simplifyMax: 3.0,
    minDistMultiplier: 0.15,
    eraseRepaintEvery: 4,
    maxCachedLayers: 4,
  );

  /// Gama baja: entry-level (≤3GB RAM, API <28, o chip muy lento)
  const DeviceProfile._low() : this._(
    tierName: 'low',
    defaultCanvasWidth: 720,
    defaultCanvasHeight: 1280,
    maxUndoSteps: 10,
    stampLoadSize: 192,
    simplifyMin: 1.0,   // más agresivo en dispositivos lentos
    simplifyMax: 5.0,
    minDistMultiplier: 0.20,
    eraseRepaintEvery: 6,
    maxCachedLayers: 2,
  );

  // ── Detección automática ─────────────────────────────────────

  /// Detecta el hardware y asigna el perfil apropiado.
  /// Llamar una vez en main() antes de runApp().
  static Future<DeviceProfile> detect() async {
    if (_instance != null) return _instance!;

    try {
      if (!Platform.isAndroid) {
        // iOS / desktop: asumir gama alta
        _instance = const DeviceProfile._high();
        return _instance!;
      }

      final info = await DeviceInfoPlugin().androidInfo;
      final apiLevel = info.version.sdkInt;  // e.g. 33 = Android 13
      final board = info.board.toLowerCase(); // chip info parcial
      final model = info.model.toLowerCase();

      // Detección por chip conocido (por nombre de board/model)
      final tier = _detectTier(apiLevel, board, model);
      _instance = tier;

      if (kDebugMode) {
        print('[DeviceProfile] Model: ${info.model}, '
            'API: $apiLevel, Board: ${info.board} → Tier: ${tier.tierName}');
      }

      return _instance!;
    } catch (e) {
      // Si falla la detección, usar mid como fallback seguro
      _instance = const DeviceProfile._mid();
      return _instance!;
    }
  }

  static DeviceProfile _detectTier(int apiLevel, String board, String model) {
    // ── Chips de gama baja conocidos ──
    final lowEndChips = [
      'mt6739', 'mt6737', 'mt6580', 'mt6757',  // MediaTek entry-level
      'msm8909', 'msm8917', 'msm8937',          // Snapdragon 200/400 series
      'sc7731', 'sc8830',                         // Spreadtrum
      'helio_a22', 'helio_a25',
    ];

    // ── Chips de gama media ──
    final midChips = [
      'mt6765', 'mt6768', 'mt6769',              // Helio G80/G85/G88
      'helio_g80', 'helio_g81', 'helio_g85',     // G-series mid
      'helio_g88', 'helio_g96',
      'msm8953', 'msm8956', 'msm8976',           // Snapdragon 625/650/652
      'sdm450', 'sdm625', 'sdm660',              // Snapdragon 450/625/660
      'sm4250', 'sm4350', 'sm6115',              // Snapdragon 460/480/662
      'exynos7884', 'exynos7904', 'exynos9610',  // Exynos mid
    ];

    // ── Chips de gama alta ──
    final highEndChips = [
      'sm8', // Snapdragon 8xx series (sm8150, sm8250, sm8350, sm8450, sm8550)
      'sm7', // Snapdragon 7xx series
      'kirin9', // Kirin 9xx
      'tensor', // Google Tensor
      'exynos2', // Exynos 2xxx
      'dimensity9', // Dimensity 9xxx
      'dimensity8', // Dimensity 8xxx
    ];

    final combined = '$board $model';

    // Check high-end chips
    for (final chip in highEndChips) {
      if (combined.contains(chip)) return const DeviceProfile._high();
    }

    // Check low-end chips
    for (final chip in lowEndChips) {
      if (combined.contains(chip)) return const DeviceProfile._low();
    }

    // Check mid chips
    for (final chip in midChips) {
      if (combined.contains(chip)) return const DeviceProfile._mid();
    }

    // Fallback por API level si no se reconoce el chip
    if (apiLevel >= 31) return const DeviceProfile._high();    // Android 12+
    if (apiLevel >= 28) return const DeviceProfile._mid();     // Android 9-11
    return const DeviceProfile._low();                          // Android <9
  }

  // ── Helpers ──────────────────────────────────────────────────

  bool get isHighEnd => tierName == 'high';
  bool get isMidRange => tierName == 'mid';
  bool get isLowEnd => tierName == 'low';

  @override
  String toString() => 'DeviceProfile($tierName: canvas=${defaultCanvasWidth}x$defaultCanvasHeight, '
      'undo=$maxUndoSteps, stamp=$stampLoadSize)';
}
