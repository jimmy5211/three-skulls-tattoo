import 'stroke_model.dart';

enum RotationDynamic { fijo, libre, seguirTrazo, aleteo }
enum BlendModeType   { estandar, multiplicar, pantalla, superposicion, luz }

class BrushModel {
  final String id;
  final String name;
  final String emoji;
  final StrokeType type;
  final BrushCategory category;

  // ── General ────────────────────────────────────────────────────────────────
  double size;
  double opacity;
  double spacing;
  double hardness;
  double flow;
  double sizeMin;
  double flowMax;
  double flowMin;
  bool   accumulative;
  bool   velocityPressure;
  double smoothing;
  bool   professionalLine;
  bool   detectRefLimits;
  bool   pressureConeSync;
  double pressureConeHead;
  double pressureConeTail;

  // ── Forma ──────────────────────────────────────────────────────────────────
  bool   flipX;
  bool   flipY;
  bool   convertToAlpha;
  double shapeSmoothing;
  double shapeRoundness;
  double shapeAngle;
  int    shapeCount;
  double shapeCountJitter;
  double scatter;
  bool   scatter2D;
  BlendModeType blendMode;
  RotationDynamic rotationDynamic;

  // ── Textura ────────────────────────────────────────────────────────────────
  String? grainAsset;
  double  grainDepth;

  // ── Lápiz ──────────────────────────────────────────────────────────────────
  bool   pressureSizeOn;
  bool   pressureFlowOn;
  bool   tiltSizeOn;
  bool   tiltFlowOn;
  double pressureCurveP1x;
  double pressureCurveP1y;
  double pressureCurveP2x;
  double pressureCurveP2y;

  // ── Cepillo doble ──────────────────────────────────────────────────────────
  bool    doubleBrushOn;
  String? doubleBrushId;

  bool isPressureSensitive;

  BrushModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    required this.category,
    this.size               = 5.0,
    this.opacity            = 1.0,
    this.spacing            = 1.0,
    this.hardness           = 1.0,
    this.flow               = 1.0,
    this.sizeMin            = 0.0,
    this.flowMax            = 1.0,
    this.flowMin            = 0.0,
    this.accumulative       = false,
    this.velocityPressure   = false,
    this.smoothing          = 0.0,
    this.professionalLine   = true,
    this.detectRefLimits    = true,
    this.pressureConeSync   = true,
    this.pressureConeHead   = 0.0,
    this.pressureConeTail   = 0.0,
    this.flipX              = false,
    this.flipY              = false,
    this.convertToAlpha     = true,
    this.shapeSmoothing     = 1.0,
    this.shapeRoundness     = 1.0,
    this.shapeAngle         = 0.0,
    this.shapeCount         = 1,
    this.shapeCountJitter   = 0.0,
    this.scatter            = 0.0,
    this.scatter2D          = true,
    this.blendMode          = BlendModeType.estandar,
    this.rotationDynamic    = RotationDynamic.libre,
    this.grainAsset,
    this.grainDepth         = 0.0,
    this.pressureSizeOn     = true,
    this.pressureFlowOn     = false,
    this.tiltSizeOn         = false,
    this.tiltFlowOn         = false,
    this.pressureCurveP1x   = 0.33,
    this.pressureCurveP1y   = 0.33,
    this.pressureCurveP2x   = 0.66,
    this.pressureCurveP2y   = 0.66,
    this.doubleBrushOn      = false,
    this.doubleBrushId,
    this.isPressureSensitive = true,
  });

  // Getters para el motor C++
  double get spacingBase     => spacing * 0.04;
  double get spacingVelocity => velocityPressure ? 0.001 : 0.0;
  double get spacingMinPx    => 1.0;
  double get jitterPos       => scatter * 0.15;
  double get jitterSize      => shapeCountJitter * 0.2;
  double get jitterRot {
    switch (rotationDynamic) {
      case RotationDynamic.fijo:        return 0.0;
      case RotationDynamic.seguirTrazo: return 0.1;
      case RotationDynamic.aleteo:      return 1.0;
      case RotationDynamic.libre:       return 6.28;
    }
  }
  bool get followStroke => rotationDynamic == RotationDynamic.seguirTrazo;

  BrushModel copyWith({
    String? id, String? name, String? emoji,
    StrokeType? type, BrushCategory? category,
    double? size, double? opacity, double? spacing, double? hardness,
    double? flow, double? sizeMin, double? flowMax, double? flowMin,
    bool? accumulative, bool? velocityPressure, double? smoothing,
    bool? professionalLine, bool? detectRefLimits,
    bool? pressureConeSync, double? pressureConeHead, double? pressureConeTail,
    bool? flipX, bool? flipY, bool? convertToAlpha,
    double? shapeSmoothing, double? shapeRoundness, double? shapeAngle,
    int? shapeCount, double? shapeCountJitter,
    double? scatter, bool? scatter2D,
    BlendModeType? blendMode, RotationDynamic? rotationDynamic,
    String? grainAsset, double? grainDepth,
    bool? pressureSizeOn, bool? pressureFlowOn,
    bool? tiltSizeOn, bool? tiltFlowOn,
    double? pressureCurveP1x, double? pressureCurveP1y,
    double? pressureCurveP2x, double? pressureCurveP2y,
    bool? doubleBrushOn, String? doubleBrushId,
    bool? isPressureSensitive,
  }) {
    return BrushModel(
      id: id ?? this.id, name: name ?? this.name, emoji: emoji ?? this.emoji,
      type: type ?? this.type, category: category ?? this.category,
      size: size ?? this.size, opacity: opacity ?? this.opacity,
      spacing: spacing ?? this.spacing, hardness: hardness ?? this.hardness,
      flow: flow ?? this.flow, sizeMin: sizeMin ?? this.sizeMin,
      flowMax: flowMax ?? this.flowMax, flowMin: flowMin ?? this.flowMin,
      accumulative: accumulative ?? this.accumulative,
      velocityPressure: velocityPressure ?? this.velocityPressure,
      smoothing: smoothing ?? this.smoothing,
      professionalLine: professionalLine ?? this.professionalLine,
      detectRefLimits: detectRefLimits ?? this.detectRefLimits,
      pressureConeSync: pressureConeSync ?? this.pressureConeSync,
      pressureConeHead: pressureConeHead ?? this.pressureConeHead,
      pressureConeTail: pressureConeTail ?? this.pressureConeTail,
      flipX: flipX ?? this.flipX, flipY: flipY ?? this.flipY,
      convertToAlpha: convertToAlpha ?? this.convertToAlpha,
      shapeSmoothing: shapeSmoothing ?? this.shapeSmoothing,
      shapeRoundness: shapeRoundness ?? this.shapeRoundness,
      shapeAngle: shapeAngle ?? this.shapeAngle,
      shapeCount: shapeCount ?? this.shapeCount,
      shapeCountJitter: shapeCountJitter ?? this.shapeCountJitter,
      scatter: scatter ?? this.scatter, scatter2D: scatter2D ?? this.scatter2D,
      blendMode: blendMode ?? this.blendMode,
      rotationDynamic: rotationDynamic ?? this.rotationDynamic,
      grainAsset: grainAsset ?? this.grainAsset,
      grainDepth: grainDepth ?? this.grainDepth,
      pressureSizeOn: pressureSizeOn ?? this.pressureSizeOn,
      pressureFlowOn: pressureFlowOn ?? this.pressureFlowOn,
      tiltSizeOn: tiltSizeOn ?? this.tiltSizeOn,
      tiltFlowOn: tiltFlowOn ?? this.tiltFlowOn,
      pressureCurveP1x: pressureCurveP1x ?? this.pressureCurveP1x,
      pressureCurveP1y: pressureCurveP1y ?? this.pressureCurveP1y,
      pressureCurveP2x: pressureCurveP2x ?? this.pressureCurveP2x,
      pressureCurveP2y: pressureCurveP2y ?? this.pressureCurveP2y,
      doubleBrushOn: doubleBrushOn ?? this.doubleBrushOn,
      doubleBrushId: doubleBrushId ?? this.doubleBrushId,
      isPressureSensitive: isPressureSensitive ?? this.isPressureSensitive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'emoji': emoji,
    'type': type.name, 'category': category.name,
    'size': size, 'opacity': opacity, 'spacing': spacing,
    'hardness': hardness, 'flow': flow,
    'sizeMin': sizeMin, 'flowMax': flowMax, 'flowMin': flowMin,
    'accumulative': accumulative, 'velocityPressure': velocityPressure,
    'smoothing': smoothing, 'professionalLine': professionalLine,
    'detectRefLimits': detectRefLimits,
    'pressureConeSync': pressureConeSync,
    'pressureConeHead': pressureConeHead, 'pressureConeTail': pressureConeTail,
    'flipX': flipX, 'flipY': flipY, 'convertToAlpha': convertToAlpha,
    'shapeSmoothing': shapeSmoothing, 'shapeRoundness': shapeRoundness,
    'shapeAngle': shapeAngle, 'shapeCount': shapeCount,
    'shapeCountJitter': shapeCountJitter,
    'scatter': scatter, 'scatter2D': scatter2D,
    'blendMode': blendMode.name, 'rotationDynamic': rotationDynamic.name,
    'grainAsset': grainAsset, 'grainDepth': grainDepth,
    'pressureSizeOn': pressureSizeOn, 'pressureFlowOn': pressureFlowOn,
    'tiltSizeOn': tiltSizeOn, 'tiltFlowOn': tiltFlowOn,
    'pressureCurveP1x': pressureCurveP1x, 'pressureCurveP1y': pressureCurveP1y,
    'pressureCurveP2x': pressureCurveP2x, 'pressureCurveP2y': pressureCurveP2y,
    'doubleBrushOn': doubleBrushOn, 'doubleBrushId': doubleBrushId,
  };

  factory BrushModel.fromJson(Map<String, dynamic> j) => BrushModel(
    id:       j['id']    as String,
    name:     j['name']  as String,
    emoji:    j['emoji'] as String? ?? '🖌️',
    type:     StrokeType.values.firstWhere((e) => e.name == j['type'],     orElse: () => StrokeType.liner),
    category: BrushCategory.values.firstWhere((e) => e.name == j['category'], orElse: () => BrushCategory.todos),
    size:              (j['size']              as num?)?.toDouble() ?? 5.0,
    opacity:           (j['opacity']           as num?)?.toDouble() ?? 1.0,
    spacing:           (j['spacing']           as num?)?.toDouble() ?? 1.0,
    hardness:          (j['hardness']          as num?)?.toDouble() ?? 1.0,
    flow:              (j['flow']              as num?)?.toDouble() ?? 1.0,
    sizeMin:           (j['sizeMin']           as num?)?.toDouble() ?? 0.0,
    flowMax:           (j['flowMax']           as num?)?.toDouble() ?? 1.0,
    flowMin:           (j['flowMin']           as num?)?.toDouble() ?? 0.0,
    accumulative:      j['accumulative']       as bool? ?? false,
    velocityPressure:  j['velocityPressure']   as bool? ?? false,
    smoothing:         (j['smoothing']         as num?)?.toDouble() ?? 0.0,
    professionalLine:  j['professionalLine']   as bool? ?? true,
    detectRefLimits:   j['detectRefLimits']    as bool? ?? true,
    pressureConeSync:  j['pressureConeSync']   as bool? ?? true,
    pressureConeHead:  (j['pressureConeHead']  as num?)?.toDouble() ?? 0.0,
    pressureConeTail:  (j['pressureConeTail']  as num?)?.toDouble() ?? 0.0,
    flipX:             j['flipX']              as bool? ?? false,
    flipY:             j['flipY']              as bool? ?? false,
    convertToAlpha:    j['convertToAlpha']     as bool? ?? true,
    shapeSmoothing:    (j['shapeSmoothing']    as num?)?.toDouble() ?? 1.0,
    shapeRoundness:    (j['shapeRoundness']    as num?)?.toDouble() ?? 1.0,
    shapeAngle:        (j['shapeAngle']        as num?)?.toDouble() ?? 0.0,
    shapeCount:        j['shapeCount']         as int?  ?? 1,
    shapeCountJitter:  (j['shapeCountJitter']  as num?)?.toDouble() ?? 0.0,
    scatter:           (j['scatter']           as num?)?.toDouble() ?? 0.0,
    scatter2D:         j['scatter2D']          as bool? ?? true,
    blendMode:         BlendModeType.values.firstWhere((e) => e.name == j['blendMode'],       orElse: () => BlendModeType.estandar),
    rotationDynamic:   RotationDynamic.values.firstWhere((e) => e.name == j['rotationDynamic'], orElse: () => RotationDynamic.libre),
    grainAsset:        j['grainAsset']         as String?,
    grainDepth:        (j['grainDepth']        as num?)?.toDouble() ?? 0.0,
    pressureSizeOn:    j['pressureSizeOn']     as bool? ?? true,
    pressureFlowOn:    j['pressureFlowOn']     as bool? ?? false,
    tiltSizeOn:        j['tiltSizeOn']         as bool? ?? false,
    tiltFlowOn:        j['tiltFlowOn']         as bool? ?? false,
    pressureCurveP1x:  (j['pressureCurveP1x'] as num?)?.toDouble() ?? 0.33,
    pressureCurveP1y:  (j['pressureCurveP1y'] as num?)?.toDouble() ?? 0.33,
    pressureCurveP2x:  (j['pressureCurveP2x'] as num?)?.toDouble() ?? 0.66,
    pressureCurveP2y:  (j['pressureCurveP2y'] as num?)?.toDouble() ?? 0.66,
    doubleBrushOn:     j['doubleBrushOn']      as bool? ?? false,
    doubleBrushId:     j['doubleBrushId']      as String?,
  );

  static List<BrushModel> defaultBrushes() => [
    BrushModel(id:'liner_fino',  name:'Liner Fino',  emoji:'✒️', type:StrokeType.liner,   category:BrushCategory.todos, size:2.0,  opacity:1.0, rotationDynamic:RotationDynamic.seguirTrazo),
    BrushModel(id:'liner_medio', name:'Liner Medio', emoji:'🖊️', type:StrokeType.liner,   category:BrushCategory.todos, size:4.0,  opacity:1.0, rotationDynamic:RotationDynamic.seguirTrazo),
    BrushModel(id:'shader_suave',name:'Shader Suave',emoji:'🖌️', type:StrokeType.shader,  category:BrushCategory.todos, size:15.0, opacity:0.5, hardness:0.2),
    BrushModel(id:'dotwork',     name:'Dotwork',     emoji:'⚫', type:StrokeType.dotwork, category:BrushCategory.todos, size:3.0,  opacity:1.0, spacing:3.0, scatter:0.1),
    BrushModel(id:'relleno',     name:'Relleno',     emoji:'🎨', type:StrokeType.fill,    category:BrushCategory.todos, size:20.0, opacity:0.8),
    BrushModel(id:'borrador',    name:'Borrador',    emoji:'🧹', type:StrokeType.eraser,  category:BrushCategory.todos, size:10.0, opacity:1.0, hardness:1.0),
    BrushModel(id:'cal_01', name:'Pluma Clásica',    emoji:'✒️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:3.0,  opacity:1.0, rotationDynamic:RotationDynamic.seguirTrazo),
    BrushModel(id:'cal_02', name:'Pluma Caligráfica',emoji:'🖋️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:4.0,  opacity:1.0, shapeAngle:45.0),
    BrushModel(id:'cal_03', name:'Pincel Caligráfico',emoji:'🖌️',type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:6.0,  opacity:0.9, smoothing:0.3),
    BrushModel(id:'cal_04', name:'Marcador Fino',    emoji:'✏️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:2.0,  opacity:1.0),
    BrushModel(id:'cal_05', name:'Marcador Grueso',  emoji:'🖍️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:8.0,  opacity:1.0),
    BrushModel(id:'cal_06', name:'Tinta China',      emoji:'🖊️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:3.0,  opacity:1.0, pressureConeHead:0.2, pressureConeTail:0.1),
    BrushModel(id:'cal_07', name:'Brocha Japonesa',  emoji:'🎋', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:10.0, opacity:0.8, scatter:0.05),
    BrushModel(id:'cal_08', name:'Plumilla',         emoji:'🪶', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:1.5,  opacity:1.0, pressureConeHead:0.3),
    BrushModel(id:'cal_09', name:'Rotulador',        emoji:'🖊️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:5.0,  opacity:1.0),
    BrushModel(id:'cal_10', name:'Pincel Seco',      emoji:'🎨', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:7.0,  opacity:0.7, grainDepth:0.4),
    BrushModel(id:'cal_11', name:'Caña',             emoji:'🌾', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:4.0,  opacity:0.9),
    BrushModel(id:'cal_12', name:'Gótico',           emoji:'⚜️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:5.0,  opacity:1.0, shapeAngle:30.0),
    BrushModel(id:'cal_13', name:'Copperplate',      emoji:'✒️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:2.0,  opacity:1.0),
    BrushModel(id:'cal_14', name:'Brush Lettering',  emoji:'🖌️', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:8.0,  opacity:0.9),
    BrushModel(id:'cal_15', name:'Uncial',           emoji:'📜', type:StrokeType.caligrafia,  category:BrushCategory.caligrafia,  size:6.0,  opacity:1.0),
    BrushModel(id:'aero_01',name:'Aerógrafo Suave',  emoji:'💨', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:30.0, opacity:0.3, hardness:0.1, accumulative:true),
    BrushModel(id:'aero_02',name:'Aerógrafo Medio',  emoji:'🌫️', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:20.0, opacity:0.5, hardness:0.3, accumulative:true),
    BrushModel(id:'aero_03',name:'Aerógrafo Duro',   emoji:'💨', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:15.0, opacity:0.8, hardness:0.7),
    BrushModel(id:'aero_04',name:'Difuminado',       emoji:'🌀', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:40.0, opacity:0.2, hardness:0.0, accumulative:true),
    BrushModel(id:'aero_05',name:'Niebla',           emoji:'🌁', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:50.0, opacity:0.15),
    BrushModel(id:'aero_06',name:'Spray Fino',       emoji:'✨', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:10.0, opacity:0.6, scatter:0.3),
    BrushModel(id:'aero_07',name:'Spray Grueso',     emoji:'💦', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:25.0, opacity:0.4, scatter:0.4),
    BrushModel(id:'aero_08',name:'Degradado',        emoji:'🎨', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:35.0, opacity:0.25,hardness:0.0),
    BrushModel(id:'aero_09',name:'Sombra Suave',     emoji:'🌑', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:45.0, opacity:0.2),
    BrushModel(id:'aero_10',name:'Luz Suave',        emoji:'🌟', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:40.0, opacity:0.2),
    BrushModel(id:'aero_11',name:'Contorno Aerosol', emoji:'🖊️', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:8.0,  opacity:0.7),
    BrushModel(id:'aero_12',name:'Nube',             emoji:'☁️', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:60.0, opacity:0.1),
    BrushModel(id:'aero_13',name:'Aerógrafo Puntual',emoji:'🎯', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:5.0,  opacity:0.9),
    BrushModel(id:'aero_14',name:'Bruma',            emoji:'🌫️', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:55.0, opacity:0.12),
    BrushModel(id:'aero_15',name:'Flash',            emoji:'⚡', type:StrokeType.aerografo,   category:BrushCategory.aerografo,   size:20.0, opacity:0.6),
    BrushModel(id:'car_01', name:'Carboncillo Fino', emoji:'✏️', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:3.0,  opacity:0.9, grainDepth:0.6, scatter:0.05),
    BrushModel(id:'car_02', name:'Carboncillo Medio',emoji:'✏️', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:8.0,  opacity:0.8, grainDepth:0.7, scatter:0.08),
    BrushModel(id:'car_03', name:'Carboncillo Grueso',emoji:'🖤',type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:15.0, opacity:0.7, grainDepth:0.8, scatter:0.1),
    BrushModel(id:'car_04', name:'Grafito HB',       emoji:'📝', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:2.0,  opacity:0.85,grainDepth:0.3),
    BrushModel(id:'car_05', name:'Grafito 2B',       emoji:'📝', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:4.0,  opacity:0.8, grainDepth:0.4),
    BrushModel(id:'car_06', name:'Grafito 6B',       emoji:'📝', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:8.0,  opacity:0.75,grainDepth:0.5),
    BrushModel(id:'car_07', name:'Difuminador',      emoji:'👆', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:20.0, opacity:0.4, hardness:0.2),
    BrushModel(id:'car_08', name:'Sanguina',         emoji:'🟤', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:6.0,  opacity:0.7, grainDepth:0.5),
    BrushModel(id:'car_09', name:'Tiza',             emoji:'🪨', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:10.0, opacity:0.6, grainDepth:0.6),
    BrushModel(id:'car_10', name:'Pastel Seco',      emoji:'🎨', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:14.0, opacity:0.65,grainDepth:0.65),
    BrushModel(id:'car_11', name:'Lápiz Duro',       emoji:'✏️', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:1.5,  opacity:0.95,grainDepth:0.2),
    BrushModel(id:'car_12', name:'Boceto',           emoji:'📐', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:3.0,  opacity:0.7, grainDepth:0.3),
    BrushModel(id:'car_13', name:'Sombreado Suave',  emoji:'🌑', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:18.0, opacity:0.5, grainDepth:0.5, hardness:0.3),
    BrushModel(id:'car_14', name:'Rayado Cruzado',   emoji:'✂️', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:2.0,  opacity:0.8),
    BrushModel(id:'car_15', name:'Carbón Comprimido',emoji:'🖤', type:StrokeType.carbonciilo, category:BrushCategory.carbonciilo, size:12.0, opacity:0.9, grainDepth:0.7),
    BrushModel(id:'aers_01',name:'Spray Urbano',     emoji:'🎨', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:30.0, opacity:0.7, scatter:0.35, shapeCount:3),
    BrushModel(id:'aers_02',name:'Graffiti Base',    emoji:'🖌️', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:25.0, opacity:0.8),
    BrushModel(id:'aers_03',name:'Spray Fino',       emoji:'✨', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:8.0,  opacity:0.9, scatter:0.2),
    BrushModel(id:'aers_04',name:'Spray Grueso',     emoji:'💦', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:40.0, opacity:0.6, scatter:0.4),
    BrushModel(id:'aers_05',name:'Drip',             emoji:'💧', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:5.0,  opacity:0.9),
    BrushModel(id:'aers_06',name:'Stencil',          emoji:'🔲', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:20.0, opacity:0.85),
    BrushModel(id:'aers_07',name:'Tag Fino',         emoji:'🖊️', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:3.0,  opacity:1.0),
    BrushModel(id:'aers_08',name:'Tag Grueso',       emoji:'✏️', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:10.0, opacity:0.95),
    BrushModel(id:'aers_09',name:'Fill Urbano',      emoji:'🎭', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:35.0, opacity:0.7),
    BrushModel(id:'aers_10',name:'Outline Graffiti', emoji:'🖋️', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:4.0,  opacity:1.0, rotationDynamic:RotationDynamic.seguirTrazo),
    BrushModel(id:'aers_11',name:'Bubble',           emoji:'🫧', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:22.0, opacity:0.75),
    BrushModel(id:'aers_12',name:'Wildstyle',        emoji:'🌀', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:6.0,  opacity:0.9),
    BrushModel(id:'aers_13',name:'Chrome',           emoji:'⚡', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:18.0, opacity:0.8),
    BrushModel(id:'aers_14',name:'Fade',             emoji:'🌫️', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:45.0, opacity:0.4, hardness:0.0),
    BrushModel(id:'aers_15',name:'Block Letter',     emoji:'🔠', type:StrokeType.aerosol,     category:BrushCategory.aerosoles,   size:15.0, opacity:0.9),
    BrushModel(id:'lum_01', name:'Luz Brillante',    emoji:'✨', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:30.0, opacity:0.3, hardness:0.0, accumulative:true),
    BrushModel(id:'lum_02', name:'Destello',         emoji:'💥', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:20.0, opacity:0.4),
    BrushModel(id:'lum_03', name:'Halo',             emoji:'🌟', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:40.0, opacity:0.2, hardness:0.0),
    BrushModel(id:'lum_04', name:'Neón',             emoji:'💡', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:6.0,  opacity:0.9),
    BrushModel(id:'lum_05', name:'Aurora',           emoji:'🌌', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:50.0, opacity:0.15),
    BrushModel(id:'lum_06', name:'Chispa',           emoji:'⚡', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:4.0,  opacity:0.95,scatter:0.2),
    BrushModel(id:'lum_07', name:'Resplandor',       emoji:'🌅', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:45.0, opacity:0.2),
    BrushModel(id:'lum_08', name:'Luz Suave',        emoji:'🕯️', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:35.0, opacity:0.25,hardness:0.0),
    BrushModel(id:'lum_09', name:'Brillo Metálico',  emoji:'🪙', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:10.0, opacity:0.7),
    BrushModel(id:'lum_10', name:'Luz Solar',        emoji:'☀️', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:55.0, opacity:0.15),
    BrushModel(id:'lum_11', name:'Glitter',          emoji:'✨', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:8.0,  opacity:0.8, scatter:0.3, shapeCount:4),
    BrushModel(id:'lum_12', name:'Reflejo',          emoji:'🪞', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:15.0, opacity:0.5),
    BrushModel(id:'lum_13', name:'Fosfórico',        emoji:'🔦', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:12.0, opacity:0.6),
    BrushModel(id:'lum_14', name:'Luz de Luna',      emoji:'🌙', type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:40.0, opacity:0.2, hardness:0.0),
    BrushModel(id:'lum_15', name:'Explosión Lumínica',emoji:'💫',type:StrokeType.luminancia,  category:BrushCategory.luminancia,  size:25.0, opacity:0.4),
  ];

  static List<BrushModel> byCategory(List<BrushModel> brushes, BrushCategory category) {
    if (category == BrushCategory.todos) return brushes;
    return brushes.where((b) => b.category == category).toList();
  }

  static String categoryName(BrushCategory cat) {
    const m = {
      BrushCategory.todos:'Todos', BrushCategory.caligrafia:'Caligrafía',
      BrushCategory.aerografo:'Aerógrafo', BrushCategory.texturas:'Texturas',
      BrushCategory.abstractos:'Abstractos', BrushCategory.carbonciilo:'Carboncillo',
      BrushCategory.elementos:'Elementos', BrushCategory.aerosoles:'Aerosoles',
      BrushCategory.retoque:'Retoque', BrushCategory.luminancia:'Luminancia',
      BrushCategory.industriales:'Industriales', BrushCategory.organicos:'Orgánicos',
      BrushCategory.agua:'Agua', BrushCategory.importado:'Importado',
    };
    return m[cat] ?? cat.name;
  }

  static String categoryEmoji(BrushCategory cat) {
    const m = {
      BrushCategory.todos:'🖌️', BrushCategory.caligrafia:'✒️',
      BrushCategory.aerografo:'💨', BrushCategory.texturas:'🪨',
      BrushCategory.abstractos:'🌀', BrushCategory.carbonciilo:'✏️',
      BrushCategory.elementos:'💀', BrushCategory.aerosoles:'🎨',
      BrushCategory.retoque:'✨', BrushCategory.luminancia:'🌟',
      BrushCategory.industriales:'⚙️', BrushCategory.organicos:'🌿',
      BrushCategory.agua:'💧', BrushCategory.importado:'📥',
    };
    return m[cat] ?? '🖌️';
  }
}
