import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Un trazo del borrador sobre la imagen (coordenadas canvas)
class EraseStroke {
  final List<Offset> points; // mutable — se agrega en tiempo real
  final double radius;

  EraseStroke({required this.points, required this.radius});

  // Mantener copyWithPoint por compatibilidad pero ya no se usa en hot path
  EraseStroke copyWithPoint(Offset point) => EraseStroke(
        points: [...points, point],
        radius: radius,
      );
}

class CanvasImageModel {
  final String id;
  final ui.Image image;
  Offset position;
  Size size;
  double opacity;
  bool isSelected;

  /// Trazos del borrador ya confirmados
  List<EraseStroke> eraseStrokes;
  /// Trazo en progreso (se muestra en tiempo real)
  EraseStroke? currentEraseStroke;

  CanvasImageModel({
    required this.id,
    required this.image,
    required this.position,
    required this.size,
    this.opacity = 1.0,
    this.isSelected = false,
    List<EraseStroke>? eraseStrokes,
    this.currentEraseStroke,
  }) : eraseStrokes = eraseStrokes ?? [];

  Rect get rect => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );

  bool get hasErases =>
      eraseStrokes.isNotEmpty || currentEraseStroke != null;
}
