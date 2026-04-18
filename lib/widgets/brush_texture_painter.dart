import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';

// Cache global de texturas generadas
class BrushTextureCache {
  static final Map<String, ui.Image?> _cache = {};

  static ui.Image? get(String key) => _cache[key];
  static void set(String key, ui.Image image) => _cache[key] = image;
  static bool has(String key) => _cache.containsKey(key) && _cache[key] != null;

  static Future<ui.Image> generateTexture(
      String key, int size, void Function(Canvas, Size) painter) async {
    if (has(key)) return _cache[key]!;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas, Size(size.toDouble(), size.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    _cache[key] = image;
    return image;
  }
}

// Generadores de texturas procedurales
class BrushTextures {

  // ─── CARBONCILLO — ruido granular ────────────────────────
  static void paintCarboncillo(Canvas canvas, Size size) {
    final rng = Random(42);
    final bgPaint = Paint()..color = Colors.transparent;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Granos de carbón irregulares
    for (int i = 0; i < 800; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 2.5 + 0.3;
      final opacity = rng.nextDouble() * 0.7 + 0.1;
      final paint = Paint()
        ..color = Colors.black.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: r * (1 + rng.nextDouble()),
          height: r * (0.5 + rng.nextDouble() * 0.5),
        ),
        paint,
      );
    }

    // Líneas finas de carbón
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = rng.nextDouble() * 12 + 3;
      final angle = rng.nextDouble() * pi;
      final paint = Paint()
        ..color = Colors.black.withOpacity(rng.nextDouble() * 0.3 + 0.05)
        ..strokeWidth = rng.nextDouble() * 0.8 + 0.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + cos(angle) * len, y + sin(angle) * len),
        paint,
      );
    }
  }

  // ─── ACUARELA — mancha orgánica ──────────────────────────
  static void paintAcuarela(Canvas canvas, Size size) {
    final rng = Random(77);
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Capas concéntricas irregulares
    for (int ring = 8; ring >= 0; ring--) {
      final ringR = maxR * (ring + 1) / 9;
      final opacity = (0.06 - ring * 0.005).clamp(0.01, 0.08);
      final path = Path();
      final points = 24;
      for (int i = 0; i <= points; i++) {
        final angle = (i / points) * 2 * pi;
        final jitter = 1.0 + (rng.nextDouble() - 0.5) * 0.35;
        final r = ringR * jitter;
        final x = center.dx + cos(angle) * r;
        final y = center.dy + sin(angle) * r;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      final paint = Paint()
        ..color = Colors.black.withOpacity(opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ringR * 0.15);
      canvas.drawPath(path, paint);
    }

    // Borde húmedo
    final edgePath = Path();
    final edgePoints = 32;
    for (int i = 0; i <= edgePoints; i++) {
      final angle = (i / edgePoints) * 2 * pi;
      final jitter = 0.85 + rng.nextDouble() * 0.3;
      final r = maxR * jitter;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) edgePath.moveTo(x, y);
      else edgePath.lineTo(x, y);
    }
    edgePath.close();
    final edgePaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = maxR * 0.08
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(edgePath, edgePaint);
  }

  // ─── AERÓGRAFO — gradiente circular suave ────────────────
  static void paintAerografo(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Gradiente radial suave
    final shader = ui.Gradient.radial(
      center,
      maxR,
      [
        Colors.black.withOpacity(0.5),
        Colors.black.withOpacity(0.2),
        Colors.black.withOpacity(0.05),
        Colors.transparent,
      ],
      [0.0, 0.3, 0.7, 1.0],
    );
    final paint = Paint()..shader = shader;
    canvas.drawCircle(center, maxR, paint);

    // Micro puntos de spray
    final rng = Random(11);
    for (int i = 0; i < 200; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = pow(rng.nextDouble(), 0.4) * maxR;
      final x = center.dx + cos(angle) * dist;
      final y = center.dy + sin(angle) * dist;
      final dotPaint = Paint()
        ..color = Colors.black.withOpacity(rng.nextDouble() * 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 0.8 + 0.1, dotPaint);
    }
  }

  // ─── LINER — punto duro y preciso ────────────────────────
  static void paintLiner(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Núcleo sólido
    final corePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.4, corePaint);

    // Halo muy sutil
    final haloPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2);
    canvas.drawCircle(center, r * 0.6, haloPaint);
  }

  // ─── TEXTURA RUGOSA — granulado ──────────────────────────
  static void paintTextura(Canvas canvas, Size size) {
    final rng = Random(33);

    // Base gris
    final basePaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, basePaint);

    // Granos irregulares
    for (int i = 0; i < 400; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 3 + 0.5;
      final paint = Paint()
        ..color = Colors.black.withOpacity(rng.nextDouble() * 0.5 + 0.05)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Líneas de textura
    for (int i = 0; i < 20; i++) {
      final y = rng.nextDouble() * size.height;
      final paint = Paint()
        ..color = Colors.black.withOpacity(rng.nextDouble() * 0.15)
        ..strokeWidth = rng.nextDouble() * 1.5 + 0.3
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + (rng.nextDouble() - 0.5) * 5),
        paint,
      );
    }
  }

  // ─── LUMINANCIA — destello ───────────────────────────────
  static void paintLuminancia(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Halo exterior muy difuso
    final haloShader = ui.Gradient.radial(
      center, maxR,
      [
        Colors.white.withOpacity(0.6),
        Colors.white.withOpacity(0.2),
        Colors.transparent,
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(center, maxR, Paint()..shader = haloShader);

    // Núcleo brillante
    canvas.drawCircle(
      center, maxR * 0.2,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  // ─── INDUSTRIAL — sello cuadrado ─────────────────────────
  static void paintIndustrial(Canvas canvas, Size size) {
    final rng = Random(55);
    final rect = Offset.zero & size;

    // Base sólida
    canvas.drawRect(
      rect.deflate(size.width * 0.1),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    // Líneas de desgaste
    for (int i = 0; i < 15; i++) {
      final x = rng.nextDouble() * size.width;
      final paint = Paint()
        ..color = Colors.white.withOpacity(rng.nextDouble() * 0.3)
        ..strokeWidth = rng.nextDouble() * 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + (rng.nextDouble() - 0.5) * 5, size.height),
        paint,
      );
    }
  }

  // ─── ORGÁNICO — forma irregular ──────────────────────────
  static void paintOrganico(Canvas canvas, Size size) {
    final rng = Random(22);
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    final path = Path();
    final points = 20;
    for (int i = 0; i <= points; i++) {
      final angle = (i / points) * 2 * pi;
      final r = maxR * (0.6 + rng.nextDouble() * 0.5);
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();

    canvas.drawPath(path, Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }
}
// Painter que usa texturas procedurales
class TextureBrushPainter {
  static final Map<String, ui.Image?> _textureCache = {};
  static bool _isGenerating = false;

  // Tamaño de textura base
  static const int _texSize = 64;

  static Future<void> preloadTextures() async {
    if (_isGenerating) return;
    _isGenerating = true;

    final textureDefs = {
      'carboncillo': BrushTextures.paintCarboncillo,
      'acuarela': BrushTextures.paintAcuarela,
      'aerografo': BrushTextures.paintAerografo,
      'liner': BrushTextures.paintLiner,
      'textura': BrushTextures.paintTextura,
      'luminancia': BrushTextures.paintLuminancia,
      'industrial': BrushTextures.paintIndustrial,
      'organico': BrushTextures.paintOrganico,
    };

    for (final entry in textureDefs.entries) {
      if (!BrushTextureCache.has(entry.key)) {
        await BrushTextureCache.generateTexture(
          entry.key, _texSize, entry.value);
      }
    }
    _isGenerating = false;
  }

  // Estampar textura a lo largo del trazo
  static void drawTextureStroke(
    Canvas canvas,
    StrokeModel stroke,
    Color color,
    String textureKey, {
    double stampSpacing = 0.4,
    double opacityMultiplier = 1.0,
    double sizeMultiplier = 1.0,
  }) {
    if (stroke.points.isEmpty) return;
    final texture = BrushTextureCache.get(textureKey);
    if (texture == null) {
      // Fallback si textura no cargó
      _drawFallback(canvas, stroke, color);
      return;
    }

    final stampSize = stroke.strokeWidth * 2.0 * sizeMultiplier;
    final spacing = stampSize * stampSpacing;

    if (stroke.points.length == 1) {
      _drawStamp(canvas, stroke.points.first, stampSize,
          color, stroke.opacity * opacityMultiplier, texture);
      return;
    }

    double accumulated = 0.0;
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final segLen = sqrt(dx * dx + dy * dy);
      if (segLen == 0) continue;

      final nx = dx / segLen;
      final ny = dy / segLen;

      double t = accumulated > 0 ? spacing - accumulated : 0;
      while (t <= segLen) {
        final px = p1.dx + nx * t;
        final py = p1.dy + ny * t;
        _drawStamp(canvas, Offset(px, py), stampSize,
            color, stroke.opacity * opacityMultiplier, texture);
        t += spacing;
      }
      accumulated = (segLen - (t - spacing)) % spacing;
    }
  }

  static void _drawStamp(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double opacity,
    ui.Image texture,
  ) {
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(
        color.withOpacity(opacity.clamp(0.0, 1.0)),
        BlendMode.srcATop,
      )
      ..filterQuality = FilterQuality.medium;

    final dst = Rect.fromCenter(center: center, width: size, height: size);
    final src = Rect.fromLTWH(
        0, 0, texture.width.toDouble(), texture.height.toDouble());
    canvas.drawImageRect(texture, src, dst, paint);
  }

  static void _drawFallback(Canvas canvas, StrokeModel stroke, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(stroke.opacity)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (stroke.points.length < 2) return;
    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (final p in stroke.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }
}

// Métodos de dibujo por tipo usando texturas
class TextureStrokes {

  static void drawCarboncillo(Canvas canvas, StrokeModel stroke, Color color) {
    // Capa base suave
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'carboncillo',
      stampSpacing: 0.25,
      opacityMultiplier: 0.6,
      sizeMultiplier: 1.2,
    );
    // Segunda pasada más densa en el centro
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'carboncillo',
      stampSpacing: 0.15,
      opacityMultiplier: 0.3,
      sizeMultiplier: 0.6,
    );
  }

  static void drawAcuarela(Canvas canvas, StrokeModel stroke, Color color) {
    // Capa exterior muy translúcida
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'acuarela',
      stampSpacing: 0.3,
      opacityMultiplier: 0.25,
      sizeMultiplier: 1.8,
    );
    // Capa interior más densa
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'acuarela',
      stampSpacing: 0.2,
      opacityMultiplier: 0.15,
      sizeMultiplier: 1.0,
    );
  }

  static void drawAerografo(Canvas canvas, StrokeModel stroke, Color color) {
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'aerografo',
      stampSpacing: 0.2,
      opacityMultiplier: 0.4,
      sizeMultiplier: 2.0,
    );
  }

  static void drawLiner(Canvas canvas, StrokeModel stroke, Color color, {double hardness = 1.0}) {
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'liner',
      stampSpacing: 0.1,
      opacityMultiplier: 1.0,
      sizeMultiplier: 0.8,
    );
  }

  static void drawTextura(Canvas canvas, StrokeModel stroke, Color color) {
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'textura',
      stampSpacing: 0.2,
      opacityMultiplier: 0.7,
      sizeMultiplier: 1.3,
    );
  }

  static void drawLuminancia(Canvas canvas, StrokeModel stroke, Color color) {
    // Halo
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'luminancia',
      stampSpacing: 0.15,
      opacityMultiplier: 0.3,
      sizeMultiplier: 3.0,
    );
    // Núcleo
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, Colors.white, 'liner',
      stampSpacing: 0.08,
      opacityMultiplier: 0.9,
      sizeMultiplier: 0.3,
    );
  }

  static void drawIndustrial(Canvas canvas, StrokeModel stroke, Color color) {
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'industrial',
      stampSpacing: 0.5,
      opacityMultiplier: 0.85,
      sizeMultiplier: 1.0,
    );
  }

  static void drawOrganico(Canvas canvas, StrokeModel stroke, Color color) {
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'organico',
      stampSpacing: 0.2,
      opacityMultiplier: 0.6,
      sizeMultiplier: 1.1,
    );
  }

  static void drawAerosol(Canvas canvas, StrokeModel stroke, Color color) {
    // Nube exterior
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'aerografo',
      stampSpacing: 0.15,
      opacityMultiplier: 0.2,
      sizeMultiplier: 2.5,
    );
    // Núcleo
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'liner',
      stampSpacing: 0.1,
      opacityMultiplier: 0.5,
      sizeMultiplier: 0.4,
    );
  }

  static void drawShader(Canvas canvas, StrokeModel stroke, Color color, {double hardness = 1.0}) {
    TextureBrushPainter.drawTextureStroke(
      canvas, stroke, color, 'aerografo',
      stampSpacing: 0.15,
      opacityMultiplier: 0.5,
      sizeMultiplier: 1.5,
    );
  }
}
