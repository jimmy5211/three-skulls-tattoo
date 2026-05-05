import 'dart:typed_data';

// ─── Modelo de capa dentro del proyecto ───────────────────────────────────────
class TskLayerData {
  final int id;
  final String name;
  final double opacity;
  final bool isVisible;
  final bool isLocked;
  // Píxeles RGBA de la capa (del motor C++)
  // null = capa vacía (no se guarda en disco)
  final Uint8List? pixelData;

  const TskLayerData({
    required this.id,
    required this.name,
    this.opacity = 1.0,
    this.isVisible = true,
    this.isLocked = false,
    this.pixelData,
  });

  bool get isEmpty => pixelData == null || pixelData!.isEmpty;

  Map<String, dynamic> toJson() => {
        'id':        id,
        'name':      name,
        'opacity':   opacity,
        'isVisible': isVisible,
        'isLocked':  isLocked,
      };

  factory TskLayerData.fromJson(Map<String, dynamic> j, {Uint8List? pixelData}) =>
      TskLayerData(
        id:        j['id']        as int,
        name:      j['name']      as String,
        opacity:   (j['opacity']  as num?)?.toDouble() ?? 1.0,
        isVisible: j['isVisible'] as bool? ?? true,
        isLocked:  j['isLocked']  as bool? ?? false,
        pixelData: pixelData,
      );
}

// ─── Modelo completo del proyecto ─────────────────────────────────────────────
class TskProjectModel {
  // ── Metadatos ──────────────────────────────────────────────────────────────
  final String id;
  String name;
  String style;
  String folderId;
  final DateTime createdAt;
  DateTime updatedAt;
  final int formatVersion;

  // ── Canvas ─────────────────────────────────────────────────────────────────
  final int canvasWidth;
  final int canvasHeight;
  final int backgroundColorARGB;

  // ── Capas ──────────────────────────────────────────────────────────────────
  final List<TskLayerData> layers;
  final int activeLayerId;

  // ── Pincel activo al guardar ───────────────────────────────────────────────
  final String activeBrushId;
  final double activeBrushSize;
  final double activeBrushOpacity;
  final int activeColorARGB;

  // ── Thumbnail PNG (generado al guardar) ───────────────────────────────────
  final Uint8List? thumbnail;

  // ── Tamaño en disco (se calcula al leer) ──────────────────────────────────
  int sizeBytes;

  TskProjectModel({
    required this.id,
    required this.name,
    this.style = 'Sin estilo',
    this.folderId = 'default',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.formatVersion = 1,
    this.canvasWidth  = 1080,
    this.canvasHeight = 1920,
    this.backgroundColorARGB = 0xFFFFFFFF,
    required this.layers,
    this.activeLayerId = 0,
    this.activeBrushId = 'liner_fino',
    this.activeBrushSize = 5.0,
    this.activeBrushOpacity = 1.0,
    this.activeColorARGB = 0xFF000000,
    this.thumbnail,
    this.sizeBytes = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ── JSON del manifest (sin pixelData) ────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id':                   id,
        'name':                 name,
        'style':                style,
        'folderId':             folderId,
        'createdAt':            createdAt.toIso8601String(),
        'updatedAt':            updatedAt.toIso8601String(),
        'formatVersion':        formatVersion,
        'canvasWidth':          canvasWidth,
        'canvasHeight':         canvasHeight,
        'backgroundColorARGB':  backgroundColorARGB,
        'activeLayerId':        activeLayerId,
        'activeBrushId':        activeBrushId,
        'activeBrushSize':      activeBrushSize,
        'activeBrushOpacity':   activeBrushOpacity,
        'activeColorARGB':      activeColorARGB,
        'layers':               layers.map((l) => l.toJson()).toList(),
      };

  factory TskProjectModel.fromJson(
    Map<String, dynamic> j, {
    List<TskLayerData> layers = const [],
    Uint8List? thumbnail,
    int sizeBytes = 0,
  }) {
    return TskProjectModel(
      id:                  j['id']                as String,
      name:                j['name']              as String,
      style:               j['style']             as String?  ?? 'Sin estilo',
      folderId:            j['folderId']          as String?  ?? 'default',
      createdAt:           DateTime.parse(j['createdAt'] as String),
      updatedAt:           DateTime.parse(j['updatedAt'] as String),
      formatVersion:       j['formatVersion']     as int?     ?? 1,
      canvasWidth:         j['canvasWidth']       as int?     ?? 1080,
      canvasHeight:        j['canvasHeight']      as int?     ?? 1920,
      backgroundColorARGB: j['backgroundColorARGB'] as int?  ?? 0xFFFFFFFF,
      activeLayerId:       j['activeLayerId']     as int?     ?? 0,
      activeBrushId:       j['activeBrushId']     as String?  ?? 'liner_fino',
      activeBrushSize:     (j['activeBrushSize']  as num?)?.toDouble() ?? 5.0,
      activeBrushOpacity:  (j['activeBrushOpacity'] as num?)?.toDouble() ?? 1.0,
      activeColorARGB:     j['activeColorARGB']   as int?     ?? 0xFF000000,
      layers:              layers,
      thumbnail:           thumbnail,
      sizeBytes:           sizeBytes,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get filePath => ''; // lo asigna TskProjectService

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final now  = DateTime.now();
    final diff = now.difference(updatedAt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7)  return 'Hace ${diff.inDays} días';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  static List<String> get styleOptions => [
        'Sin estilo', 'Blackwork', 'Realismo', 'Tribal',
        'Traditional', 'Geométrico', 'Dotwork', 'Acuarela',
        'Neo-traditional', 'Japonés',
      ];
}
