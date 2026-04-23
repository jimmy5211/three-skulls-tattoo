import 'package:flutter/material.dart';

class StrokeModel {
  // FIX: mutable growable list — permite mutación in-place en continueStroke
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final StrokeType type;
  final int layerId;
  final double hardness; // 0.0=suave, 1.0=duro
  final String? brushId; // ID del pincel para cargar brush tip PNG

  StrokeModel({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.type,
    required this.layerId,
    this.hardness = 1.0,
    this.brushId,
  });

  StrokeModel copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    double? opacity,
    StrokeType? type,
    int? layerId,
    double? hardness,
    String? brushId,
  }) {
    return StrokeModel(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      type: type ?? this.type,
      layerId: layerId ?? this.layerId,
      hardness: hardness ?? this.hardness,
      brushId: brushId ?? this.brushId,
    );
  }
}

enum StrokeType {
  liner,
  shader,
  dotwork,
  fill,
  eraser,
  caligrafia,
  aerografo,
  textura,
  abstracto,
  carbonciilo,
  elemento,
  aerosol,
  retoque,
  luminancia,
  industrial,
  organico,
  agua,
  importado,
}

enum BrushCategory {
  todos,
  caligrafia,
  aerografo,
  texturas,
  abstractos,
  carbonciilo,
  elementos,
  aerosoles,
  retoque,
  luminancia,
  industriales,
  organicos,
  agua,
  importado,
}
