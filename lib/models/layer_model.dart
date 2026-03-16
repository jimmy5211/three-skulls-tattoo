import 'package:flutter/material.dart';
import 'stroke_model.dart';

class LayerModel {
  final int id;
  String name;
  bool isVisible;
  bool isLocked;
  double opacity;
  List<StrokeModel> strokes;
  BlendMode blendMode;

  LayerModel({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1.0,
    List<StrokeModel>? strokes,
    this.blendMode = BlendMode.srcOver,
  }) : strokes = strokes ?? [];

  LayerModel copyWith({
    int? id,
    String? name,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    List<StrokeModel>? strokes,
    BlendMode? blendMode,
  }) {
    return LayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      strokes: strokes ?? this.strokes,
      blendMode: blendMode ?? this.blendMode,
    );
  }
}
