import 'stroke_model.dart';

class BrushModel {
  final String id;
  final String name;
  final String emoji;
  final StrokeType type;
  double size;
  double opacity;
  double spacing;
  bool isPressureSensitive;

  BrushModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    this.size = 5.0,
    this.opacity = 1.0,
    this.spacing = 1.0,
    this.isPressureSensitive = true,
  });

  BrushModel copyWith({
    String? id,
    String? name,
    String? emoji,
    StrokeType? type,
    double? size,
    double? opacity,
    double? spacing,
    bool? isPressureSensitive,
  }) {
    return BrushModel(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      type: type ?? this.type,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      spacing: spacing ?? this.spacing,
      isPressureSensitive:
          isPressureSensitive ?? this.isPressureSensitive,
    );
  }

  static List<BrushModel> defaultBrushes() {
    return [
      BrushModel(
        id: 'liner_fine',
        name: 'Liner Fino',
        emoji: '✒️',
        type: StrokeType.liner,
        size: 2.0,
        opacity: 1.0,
      ),
      BrushModel(
        id: 'liner_medium',
        name: 'Liner Medio',
        emoji: '🖊️',
        type: StrokeType.liner,
        size: 4.0,
        opacity: 1.0,
      ),
      BrushModel(
        id: 'shader_soft',
        name: 'Shader Suave',
        emoji: '🖌️',
        type: StrokeType.shader,
        size: 15.0,
        opacity: 0.5,
      ),
      BrushModel(
        id: 'dotwork',
        name: 'Dotwork',
        emoji: '⚫',
        type: StrokeType.dotwork,
        size: 3.0,
        opacity: 1.0,
        spacing: 3.0,
      ),
      BrushModel(
        id: 'fill',
        name: 'Relleno',
        emoji: '🎨',
        type: StrokeType.fill,
        size: 20.0,
        opacity: 0.8,
      ),
      BrushModel(
        id: 'eraser',
        name: 'Borrador',
        emoji: '🧹',
        type: StrokeType.eraser,
        size: 10.0,
        opacity: 1.0,
      ),
    ];
  }
}
