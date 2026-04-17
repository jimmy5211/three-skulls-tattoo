import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'services/update_service.dart';

// ─── DIALOG: NOTAS DE LA VERSIÓN ACTUAL ──────────────────────
class VersionNotesDialog extends StatelessWidget {
  final UpdateInfo currentInfo;

  const VersionNotesDialog({super.key, required this.currentInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      builder: (_) => VersionNotesDialog(currentInfo: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: _DialogContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _SkullIcon(size: 32, color: const Color(0xFFE74C3C)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'NOTAS DE VERSIÓN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontFamily: 'BlackOpsOne',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Versión actual
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: const Color(0xFFE74C3C).withOpacity(0.4)),
              ),
              child: Text(
                'v${currentInfo.version}',
                style: const TextStyle(
                  color: Color(0xFFE74C3C),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Separador
            _Divider(),
            const SizedBox(height: 16),
            // Lista de cambios
            if (currentInfo.releaseNotes.isNotEmpty)
              ...currentInfo.releaseNotes.map((note) => _NoteItem(note: note))
            else
              const _NoteItem(note: 'Mejoras generales y bug fixes'),
            const SizedBox(height: 20),
            // Botón cerrar
            Align(
              alignment: Alignment.centerRight,
              child: _ActionButton(
                label: 'CERRAR',
                onTap: () => Navigator.pop(context),
                primary: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DIALOG: NUEVA VERSIÓN DISPONIBLE ────────────────────────
class NewVersionDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  const NewVersionDialog({
    super.key,
    required this.updateInfo,
    required this.onUpdate,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context,
    UpdateInfo info, {
    required VoidCallback onUpdate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (_) => NewVersionDialog(
        updateInfo: info,
        onUpdate: onUpdate,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: _DialogContainer(
        accentColor: const Color(0xFFE74C3C),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con badge pulsante
            Row(
              children: [
                _PulsingBadge(),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'NUEVA VERSIÓN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontFamily: 'BlackOpsOne',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Versión nueva
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFFE74C3C),
                  Color(0xFFFF6B35),
                ]),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'v${updateInfo.version} DISPONIBLE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Divider(),
            const SizedBox(height: 12),
            // Título novedades
            const Text(
              'NOVEDADES',
              style: TextStyle(
                color: Color(0xFFE74C3C),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            // Lista de cambios
            if (updateInfo.releaseNotes.isNotEmpty)
              ...updateInfo.releaseNotes.map((note) => _NoteItem(note: note))
            else
              const _NoteItem(note: 'Mejoras generales y bug fixes'),
            const SizedBox(height: 24),
            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!updateInfo.mandatory)
                  _ActionButton(
                    label: 'DESPUÉS',
                    onTap: onDismiss,
                    primary: false,
                  ),
                const SizedBox(width: 12),
                _ActionButton(
                  label: '↓  ACTUALIZAR',
                  onTap: onUpdate,
                  primary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGETS COMPARTIDOS ─────────────────────────────────────

class _DialogContainer extends StatelessWidget {
  final Widget child;
  final Color accentColor;

  const _DialogContainer({
    required this.child,
    this.accentColor = const Color(0xFFE74C3C),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NoteItem extends StatelessWidget {
  final String note;

  const _NoteItem({required this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: SizedBox(
              width: 6,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE74C3C),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        30,
        (i) => Expanded(
          child: Container(
            height: 1,
            color: i % 2 == 0
                ? const Color(0xFFE74C3C).withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFFE74C3C), Color(0xFFFF6B35)],
                )
              : null,
          borderRadius: BorderRadius.circular(6),
          border: primary
              ? null
              : Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primary ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _SkullIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _SkullIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MiniSkullPainter(color: color),
    );
  }
}

class _MiniSkullPainter extends CustomPainter {
  final Color color;
  _MiniSkullPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final paint = Paint()..color = color..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx - w * 0.42, h * 0.58)
      ..quadraticBezierTo(cx - w * 0.5, h * 0.08, cx, h * 0.04)
      ..quadraticBezierTo(cx + w * 0.5, h * 0.08, cx + w * 0.42, h * 0.58)
      ..lineTo(cx + w * 0.35, h * 0.72)
      ..lineTo(cx - w * 0.35, h * 0.72)
      ..close();
    canvas.drawPath(path, paint);

    final bg = Paint()..color = const Color(0xFF141414)..style = PaintingStyle.fill;
    // ojos
    for (final dx in [-0.18, 0.18]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + w * dx, h * 0.32),
            width: w * 0.22,
            height: h * 0.22),
        bg,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PulsingBadge extends StatefulWidget {
  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              const Color(0xFFE74C3C).withOpacity(0.2 * _anim.value),
          border: Border.all(
            color: const Color(0xFFE74C3C).withOpacity(_anim.value),
            width: 2,
          ),
        ),
        child: const Icon(Icons.system_update,
            color: Color(0xFFE74C3C), size: 16),
      ),
    );
  }
}
