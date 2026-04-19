import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Un trazo del borrador sobre la imagen (coordenadas canvas)
class EraseStroke {
  final List<Offset> points; // mutable — se agrega en tiempo real
  final double radius;
  final double hardness; // 0.0 = suave, 1.0 = duro

  EraseStroke({required this.points, required this.radius, this.hardness = 1.0});

  EraseStroke copyWithPoint(Offset point) => EraseStroke(
        points: [...points, point],
        radius: radius,
        hardness: hardness,
      );
}

class CanvasImageModel {
  final String id;
  final ui.Image image;
  Offset position;
  Size size;
  double opacity;
  bool isSelected;
  bool flipX;
  bool flipY;
  double rotation; // radianes
  int layerId;
  /// Índice de inserción — determina posición en el orden temporal de renderizado.
  /// Imágenes con insertionIndex > N se renderizan DESPUÉS del stroke N.
  /// Esto garantiza que el borrador del stroke N no afecte imágenes insertadas después.
  int insertionIndex;

  List<EraseStroke> eraseStrokes;
  EraseStroke? currentEraseStroke;

  CanvasImageModel({
    required this.id,
    required this.image,
    required this.position,
    required this.size,
    required this.layerId,
    this.insertionIndex = 0,
    this.opacity = 1.0,
    this.isSelected = false,
    this.flipX = false,
    this.flipY = false,
    this.rotation = 0.0,
    List<EraseStroke>? eraseStrokes,
    this.currentEraseStroke,
  }) : eraseStrokes = eraseStrokes ?? [];

  Rect get rect => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );

  Offset get center => rect.center;

  bool get hasErases =>
      eraseStrokes.isNotEmpty || currentEraseStroke != null;
}
