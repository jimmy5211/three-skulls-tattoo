import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CanvasImageModel {
  final String id;
  final ui.Image image;
  Offset position; // en coordenadas del canvas
  Size size;       // en píxeles del canvas
  double opacity;
  bool isSelected;

  CanvasImageModel({
    required this.id,
    required this.image,
    required this.position,
    required this.size,
    this.opacity = 1.0,
    this.isSelected = false,
  });

  CanvasImageModel copyWith({
    ui.Image? image,
    Offset? position,
    Size? size,
    double? opacity,
    bool? isSelected,
  }) {
    return CanvasImageModel(
      id: id,
      image: image ?? this.image,
      position: position ?? this.position,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Rect get rect => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );
}
