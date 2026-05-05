import 'dart:typed_data';

// ─── Curva de presión ─────────────────────────────────────────────────────────
class PressureCurve {
  final double p0, p1, p2, p3;
  const PressureCurve({
    this.p0 = 0.0,
    this.p1 = 0.3,
    this.p2 = 0.7,
    this.p3 = 1.0,
  });

  double evaluate(double t) {
    t = t.clamp(0.0, 1.0);
    if (t < 0.333) {
      final s = t / 0.333;
      return p0 + (p1 - p0) * s;
    } else if (t < 0.666) {
      final s = (t - 0.333) / 0.333;
      return p1 + (p2 - p1) * s;
    } else {
      final s = (t - 0.666) / 0.334;
      return p2 + (p3 - p2) * s;
    }
  }

  Map<String, dynamic> toJson() => {'p0': p0, 'p1': p1, 'p2': p2, 'p3': p3};

  factory PressureCurve.fromJson(Map<String, dynamic> j) => PressureCurve(
        p0: (j['p0'] as num?)?.toDouble() ?? 0.0,
        p1: (j['p1'] as num?)?.toDouble() ?? 0.3,
        p2: (j['p2'] as num?)?.toDouble() ?? 0.7,
        p3: (j['p3'] as num?)?.toDouble() ?? 1.0,
      );
}

// ─── Jitter ───────────────────────────────────────────────────────────────────
class JitterParams {
  final double position;
  final double size;
  final double rotation;

  const JitterParams({
    this.position = 0.03,
    this.size = 0.02,
    this.rotation = 6.28,
  });

  Map<String, dynamic> toJson() => {
        'position': position,
        'size': size,
        'rotation': rotation,
      };

  factory JitterParams.fromJson(Map<String, dynamic> j) => JitterParams(
        position: (j['position'] as num?)?.toDouble() ?? 0.03,
        size:     (j['size']     as num?)?.toDouble() ?? 0.02,
        rotation: (j['rotation'] as num?)?.toDouble() ?? 6.28,
      );
}

// ─── Spacing ──────────────────────────────────────────────────────────────────
class SpacingParams {
  final double base;
  final double velocityInfluence;
  final double minSpacing;

  const SpacingParams({
    this.base = 0.04,
    this.velocityInfluence = 0.001,
    this.minSpacing = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'base': base,
        'velocityInfluence': velocityInfluence,
        'minSpacing': minSpacing,
      };

  factory SpacingParams.fromJson(Map<String, dynamic> j) => SpacingParams(
        base:              (j['base']              as num?)?.toDouble() ?? 0.04,
        velocityInfluence: (j['velocityInfluence'] as num?)?.toDouble() ?? 0.001,
        minSpacing:        (j['minSpacing']        as num?)?.toDouble() ?? 1.0,
      );
}

// ─── Modelo principal TskBrush ────────────────────────────────────────────────
class TskBrushModel {
  final String id;
  final String name;
  final String category;
  final int version;

  // Parámetros base
  final double size;
  final double opacity;
  final double hardness;
  final double flow;
  final double grainDepth;

  // Textura interna del motor C++
  // -10=airbrush -11=charcoal -12=ink -13=pencil -14=glow -15=watercolor
  final int internalTexId;

  // Assets dentro del .tskbrush
  final String? shapeAsset;
  final String? grainAsset;

  // Dinámica
  final SpacingParams spacing;
  final JitterParams jitter;
  final PressureCurve pressureCurve;
  final bool followStroke;
  final double randomRotation;
  final bool isEraser;

  // Preview (bytes PNG cargados del archivo)
  final Uint8List? previewBytes;

  // Ruta del archivo en disco (null si es pincel de la app)
  final String? filePath;

  const TskBrushModel({
    required this.id,
    required this.name,
    required this.category,
    this.version = 1,
    this.size = 25.0,
    this.opacity = 1.0,
    this.hardness = 0.8,
    this.flow = 0.85,
    this.grainDepth = 0.3,
    this.internalTexId = -12,
    this.shapeAsset,
    this.grainAsset,
    this.spacing = const SpacingParams(),
    this.jitter = const JitterParams(),
    this.pressureCurve = const PressureCurve(),
    this.followStroke = true,
    this.randomRotation = 6.28,
    this.isEraser = false,
    this.previewBytes,
    this.filePath,
  });

  TskBrushModel copyWith({
    String? id,
    String? name,
    String? category,
    double? size,
    double? opacity,
    double? hardness,
    double? flow,
    double? grainDepth,
    int? internalTexId,
    SpacingParams? spacing,
    JitterParams? jitter,
    PressureCurve? pressureCurve,
    bool? followStroke,
    double? randomRotation,
    Uint8List? previewBytes,
    String? filePath,
  }) {
    return TskBrushModel(
      id:             id             ?? this.id,
      name:           name           ?? this.name,
      category:       category       ?? this.category,
      version:        version,
      size:           size           ?? this.size,
      opacity:        opacity        ?? this.opacity,
      hardness:       hardness       ?? this.hardness,
      flow:           flow           ?? this.flow,
      grainDepth:     grainDepth     ?? this.grainDepth,
      internalTexId:  internalTexId  ?? this.internalTexId,
      shapeAsset:     shapeAsset,
      grainAsset:     grainAsset,
      spacing:        spacing        ?? this.spacing,
      jitter:         jitter         ?? this.jitter,
      pressureCurve:  pressureCurve  ?? this.pressureCurve,
      followStroke:   followStroke   ?? this.followStroke,
      randomRotation: randomRotation ?? this.randomRotation,
      isEraser:       isEraser,
      previewBytes:   previewBytes   ?? this.previewBytes,
      filePath:       filePath       ?? this.filePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':             id,
        'name':           name,
        'category':       category,
        'version':        version,
        'size':           size,
        'opacity':        opacity,
        'hardness':       hardness,
        'flow':           flow,
        'grainDepth':     grainDepth,
        'internalTexId':  internalTexId,
        if (shapeAsset != null) 'shape': shapeAsset,
        if (grainAsset != null) 'grain': grainAsset,
        'followStroke':   followStroke,
        'randomRotation': randomRotation,
        'isEraser':       isEraser,
        'spacing':        spacing.toJson(),
        'jitter':         jitter.toJson(),
        'pressureCurve':  pressureCurve.toJson(),
      };

  factory TskBrushModel.fromJson(Map<String, dynamic> j, {
    Uint8List? previewBytes,
    String? filePath,
  }) {
    return TskBrushModel(
      id:             j['id']            as String? ?? '',
      name:           j['name']          as String? ?? 'Sin nombre',
      category:       j['category']      as String? ?? 'basicos',
      version:        j['version']       as int?    ?? 1,
      size:           (j['size']         as num?)?.toDouble() ?? 25.0,
      opacity:        (j['opacity']      as num?)?.toDouble() ?? 1.0,
      hardness:       (j['hardness']     as num?)?.toDouble() ?? 0.8,
      flow:           (j['flow']         as num?)?.toDouble() ?? 0.85,
      grainDepth:     (j['grainDepth']   as num?)?.toDouble() ?? 0.3,
      internalTexId:  j['internalTexId'] as int?    ?? -12,
      shapeAsset:     j['shape']         as String?,
      grainAsset:     j['grain']         as String?,
      followStroke:   j['followStroke']  as bool?   ?? true,
      randomRotation: (j['randomRotation'] as num?)?.toDouble() ?? 6.28,
      isEraser:       j['isEraser']      as bool?   ?? false,
      spacing: j['spacing'] != null
          ? SpacingParams.fromJson(j['spacing'] as Map<String, dynamic>)
          : const SpacingParams(),
      jitter: j['jitter'] != null
          ? JitterParams.fromJson(j['jitter'] as Map<String, dynamic>)
          : const JitterParams(),
      pressureCurve: j['pressureCurve'] != null
          ? PressureCurve.fromJson(j['pressureCurve'] as Map<String, dynamic>)
          : const PressureCurve(),
      previewBytes: previewBytes,
      filePath:     filePath,
    );
  }

  // ── Pinceles por defecto de la app (sin archivo externo) ──────────────────
  static List<TskBrushModel> defaultBrushes() => [
    const TskBrushModel(
      id: 'tsk_liner_fino', name: 'Liner Fino', category: 'linea',
      size: 2.0, hardness: 0.98, flow: 1.0,
      internalTexId: -12,
      spacing: SpacingParams(base: 0.03),
      jitter: JitterParams(position: 0.01, size: 0.01, rotation: 0.1),
    ),
    const TskBrushModel(
      id: 'tsk_grafito_hb', name: 'Grafito HB', category: 'carboncillo',
      size: 8.0, hardness: 0.7, flow: 0.7, grainDepth: 0.5,
      internalTexId: -13,
      spacing: SpacingParams(base: 0.04),
      jitter: JitterParams(position: 0.03, size: 0.05, rotation: 6.28),
    ),
    const TskBrushModel(
      id: 'tsk_carboncillo', name: 'Carboncillo', category: 'carboncillo',
      size: 15.0, hardness: 0.5, flow: 0.6, grainDepth: 0.7,
      internalTexId: -11,
      spacing: SpacingParams(base: 0.05),
      jitter: JitterParams(position: 0.05, size: 0.1, rotation: 6.28),
    ),
    const TskBrushModel(
      id: 'tsk_tinta', name: 'Tinta', category: 'tinta',
      size: 5.0, hardness: 0.95, flow: 0.95,
      internalTexId: -12,
      spacing: SpacingParams(base: 0.03),
      jitter: JitterParams(position: 0.01, size: 0.02, rotation: 0.2),
    ),
    const TskBrushModel(
      id: 'tsk_aerografo', name: 'Aerógrafo', category: 'aerografo',
      size: 40.0, hardness: 0.2, flow: 0.4, grainDepth: 0.1,
      internalTexId: -10,
      spacing: SpacingParams(base: 0.04),
      jitter: JitterParams(position: 0.02, size: 0.05, rotation: 6.28),
    ),
    const TskBrushModel(
      id: 'tsk_acuarela', name: 'Acuarela', category: 'agua',
      size: 30.0, hardness: 0.3, flow: 0.35, grainDepth: 0.4,
      internalTexId: -15,
      spacing: SpacingParams(base: 0.05),
      jitter: JitterParams(position: 0.04, size: 0.08, rotation: 6.28),
    ),
    const TskBrushModel(
      id: 'tsk_borrador', name: 'Borrador', category: 'utilidad',
      size: 20.0, hardness: 0.9, flow: 1.0, isEraser: true,
      internalTexId: -12,
      spacing: SpacingParams(base: 0.04),
    ),
  ];
}
