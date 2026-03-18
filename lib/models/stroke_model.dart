import 'package:flutter/material.dart';

class StrokeModel {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final StrokeType type;
  final int layerId;

  StrokeModel({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.type,
    required this.layerId,
  });

  StrokeModel copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    double? opacity,
    StrokeType? type,
    int? layerId,
  }) {
    return StrokeModel(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      type: type ?? this.type,
      layerId: layerId ?? this.layerId,
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
