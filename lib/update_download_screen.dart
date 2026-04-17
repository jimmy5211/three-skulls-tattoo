import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'services/update_service.dart';

class UpdateDownloadScreen extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDownloadScreen({super.key, required this.updateInfo});

  @override
  State<UpdateDownloadScreen> createState() => _UpdateDownloadScreenState();
}

class _UpdateDownloadScreenState extends State<UpdateDownloadScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  String _status = 'Iniciando descarga...';
  bool _isError = false;
  bool _isDone = false;

  // Animaciones de calaveras
  late AnimationController _skull1Controller;
  late AnimationController _skull2Controller;
  late AnimationController _skull3Controller;
  late AnimationController _glowController;

  late Animation<double> _skull1Jump;
  late Animation<double> _skull2Jump;
  late Animation<double> _skull3Jump;
  late Animation<double> _mouthAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    // Calavera 1 — salta primero
    _skull1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Calavera 2 — salta con delay
    _skull2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _skull2Controller.repeat(reverse: true);
    });

    // Calavera 3 — salta con más delay
    _skull3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _skull3Controller.repeat(reverse: true);
    });

    // Glow pulsante
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _skull1Jump = Tween<double>(begin: 0, end: -18).animate(
        CurvedAnimation(parent: _skull1Controller, curve: Curves.easeInOut));
    _skull2Jump = Tween<double>(begin: 0, end: -18).animate(
        CurvedAnimation(parent: _skull2Controller, curve: Curves.easeInOut));
    _skull3Jump = Tween<double>(begin: 0, end: -18).animate(
        CurvedAnimation(parent: _skull3Controller, curve: Curves.easeInOut));
    _mouthAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _skull1Controller, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await UpdateService.downloadAndInstall(
        widget.updateInfo,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              if (progress < 0.3) {
                _status = 'Descargando actualización...';
              } else if (progress < 0.7) {
                _status = 'Casi listo...';
              } else if (progress < 1.0) {
                _status = 'Finalizando descarga...';
              } else {
                _status = '¡Listo para instalar!';
                _isDone = true;
              }
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isDone = true;
          _status = 'Abriendo instalador...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _status = 'Error al descargar. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  void dispose() {
    _skull1Controller.dispose();
    _skull2Controller.dispose();
    _skull3Controller.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Fondo con patrón
          _buildBackground(),
          // Contenido principal
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Título
                    const Text(
                      'THREE SKULLS',
                      style: TextStyle(
                        color: Color(0xFFE74C3C),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        fontFamily: 'BlackOpsOne',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ACTUALIZANDO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        fontFamily: 'BlackOpsOne',
                      ),
                    ),
                    const Text(
                      'TATTOO',
                      style: TextStyle(
                        color: Color(0xFFE74C3C),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        fontFamily: 'BlackOpsOne',
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Calaveras animadas
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _skull1Controller,
                        _skull2Controller,
                        _skull3Controller,
                        _glowController,
                      ]),
                      builder: (context, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildSkull(
                              jumpOffset: _skull1Jump.value,
                              mouthOpen: _mouthAnim.value,
                              glowIntensity: _glowAnim.value,
                              color: const Color(0xFFE74C3C),
                              size: 70,
                            ),
                            const SizedBox(width: 20),
                            _buildSkull(
                              jumpOffset: _skull2Jump.value,
                              mouthOpen: _mouthAnim.value,
                              glowIntensity: _glowAnim.value * 0.8,
                              color: Colors.white,
                              size: 85, // central más grande
                            ),
                            const SizedBox(width: 20),
                            _buildSkull(
                              jumpOffset: _skull3Jump.value,
                              mouthOpen: _mouthAnim.value,
                              glowIntensity: _glowAnim.value * 0.6,
                              color: const Color(0xFFE74C3C),
                              size: 70,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 52),

                    // Versión
                    Text(
                      'v${widget.updateInfo.version}',
                      style: const TextStyle(
                        color: Color(0xFFE74C3C),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Barra de progreso
                    _buildProgressBar(),

                    const SizedBox(height: 16),

                    // Porcentaje
                    Text(
                      _isError ? '' : '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'BlackOpsOne',
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Estado
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isError
                            ? const Color(0xFFE74C3C)
                            : Colors.white54,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),

                    if (_isError) ...[
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isError = false;
                            _progress = 0;
                            _status = 'Reiniciando descarga...';
                          });
                          _startDownload();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFE74C3C), width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REINTENTAR',
                            style: TextStyle(
                              color: Color(0xFFE74C3C),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return CustomPaint(
      painter: _BackgroundPainter(),
      size: MediaQuery.of(context).size,
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        // Barra contenedor
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                return Stack(
                  children: [
                    // Progreso base
                    FractionallySizedBox(
                      widthFactor: _progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE74C3C),
                              Color.lerp(const Color(0xFFE74C3C),
                                  const Color(0xFFFF6B6B), _glowAnim.value)!,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Brillo animado
                    if (_progress > 0)
                      FractionallySizedBox(
                        widthFactor: _progress.clamp(0.0, 1.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white
                                      .withOpacity(0.6 * _glowAnim.value),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Marcadores de progreso
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(11, (i) {
            final mark = i / 10;
            final active = _progress >= mark;
            return Container(
              width: 2,
              height: active ? 8 : 4,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFE74C3C)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSkull({
    required double jumpOffset,
    required double mouthOpen,
    required double glowIntensity,
    required Color color,
    required double size,
  }) {
    return Transform.translate(
      offset: Offset(0, jumpOffset),
      child: CustomPaint(
        size: Size(size, size * 1.1),
        painter: _SkullPainter(
          color: color,
          mouthOpen: mouthOpen,
          glowIntensity: glowIntensity,
        ),
      ),
    );
  }
}

// Painter de la calavera
class _SkullPainter extends CustomPainter {
  final Color color;
  final double mouthOpen;
  final double glowIntensity;

  _SkullPainter({
    required this.color,
    required this.mouthOpen,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15 * glowIntensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * glowIntensity);
    canvas.drawCircle(Offset(cx, h * 0.38), w * 0.52, glowPaint);

    // Cráneo principal
    final skullPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Parte superior redondeada
    path.moveTo(cx - w * 0.42, h * 0.55);
    path.quadraticBezierTo(cx - w * 0.5, h * 0.1, cx, h * 0.05);
    path.quadraticBezierTo(cx + w * 0.5, h * 0.1, cx + w * 0.42, h * 0.55);
    // Mandíbula
    path.lineTo(cx + w * 0.35, h * 0.68);
    path.lineTo(cx + w * 0.35, h * 0.7 + mouthOpen * h * 0.08);
    path.lineTo(cx - w * 0.35, h * 0.7 + mouthOpen * h * 0.08);
    path.lineTo(cx - w * 0.35, h * 0.68);
    path.close();

    canvas.drawPath(path, skullPaint);

    // Ojos (huecos)
    final eyePaint = Paint()
      ..color = const Color(0xFF0A0A0A)
      ..style = PaintingStyle.fill;

    // Ojo izquierdo
    final leftEyePath = Path();
    leftEyePath.moveTo(cx - w * 0.28, h * 0.28);
    leftEyePath.quadraticBezierTo(cx - w * 0.15, h * 0.18, cx - w * 0.03, h * 0.28);
    leftEyePath.quadraticBezierTo(cx - w * 0.15, h * 0.42, cx - w * 0.28, h * 0.28);
    canvas.drawPath(leftEyePath, eyePaint);

    // Ojo derecho
    final rightEyePath = Path();
    rightEyePath.moveTo(cx + w * 0.03, h * 0.28);
    rightEyePath.quadraticBezierTo(cx + w * 0.15, h * 0.18, cx + w * 0.28, h * 0.28);
    rightEyePath.quadraticBezierTo(cx + w * 0.15, h * 0.42, cx + w * 0.03, h * 0.28);
    canvas.drawPath(rightEyePath, eyePaint);

    // Nariz
    final nosePath = Path();
    nosePath.moveTo(cx - w * 0.06, h * 0.44);
    nosePath.lineTo(cx, h * 0.52);
    nosePath.lineTo(cx + w * 0.06, h * 0.44);
    canvas.drawPath(nosePath, eyePaint);

    // Dientes (visibles cuando abre la boca)
    if (mouthOpen > 0.1) {
      final teethPaint = Paint()
        ..color = const Color(0xFF0A0A0A)
        ..style = PaintingStyle.fill;

      final toothW = w * 0.1;
      final toothH = h * 0.08 * mouthOpen;
      final teethY = h * 0.69;
      final startX = cx - w * 0.25;

      for (int i = 0; i < 5; i++) {
        final tx = startX + i * (toothW + w * 0.02);
        canvas.drawRect(
          Rect.fromLTWH(tx + w * 0.01, teethY, toothW - w * 0.02, toothH),
          teethPaint,
        );
      }
    }

    // Contorno
    final outlinePaint = Paint()
      ..color = const Color(0xFF0A0A0A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(_SkullPainter old) =>
      old.mouthOpen != mouthOpen || old.glowIntensity != glowIntensity;
}

// Fondo con patrón de hexágonos
class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    const hexR = 16.0;

    for (double y = 0; y < size.height + spacing; y += spacing * 0.866) {
      final offset = (y ~/ (spacing * 0.866)) % 2 == 0 ? 0.0 : spacing / 2;
      for (double x = -spacing + offset; x < size.width + spacing; x += spacing) {
        _drawHex(canvas, Offset(x, y), hexR, paint);
      }
    }

    // Viñeta
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF0A0A0A).withOpacity(0.8),
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}
