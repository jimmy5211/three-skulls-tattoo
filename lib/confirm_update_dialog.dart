import 'package:flutter/material.dart';
import 'services/update_service.dart';
import 'update_download_screen.dart';

/// Muestra el diálogo de confirmación y luego la pantalla de descarga.
/// Usar desde cualquier parte de la app con:
///   ConfirmUpdateDialog.show(context, update);
class ConfirmUpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const ConfirmUpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (_) => ConfirmUpdateDialog(updateInfo: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE74C3C).withOpacity(0.15),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE74C3C).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFFE74C3C), width: 2),
                ),
                child: const Icon(Icons.system_update,
                    color: Color(0xFFE74C3C), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('NUEVA VERSIÓN',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w900, letterSpacing: 2,
                        fontFamily: 'BlackOpsOne')),
              ),
            ]),
            const SizedBox(height: 12),

            // Badge versión
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFE74C3C), Color(0xFFFF6B35)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('v${updateInfo.version} DISPONIBLE',
                  style: const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 20),

            // Separador
            Row(children: List.generate(28, (i) => Expanded(
              child: Container(height: 1,
                  color: i % 2 == 0
                      ? const Color(0xFFE74C3C).withOpacity(0.4)
                      : Colors.transparent),
            ))),
            const SizedBox(height: 14),

            // Notas
            const Text('NOVEDADES',
                style: TextStyle(color: Color(0xFFE74C3C), fontSize: 10,
                    fontWeight: FontWeight.bold, letterSpacing: 3)),
            const SizedBox(height: 10),

            if (updateInfo.releaseNotes.isNotEmpty)
              ...updateInfo.releaseNotes.take(5).map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 8),
                      child: SizedBox(width: 5, height: 5,
                          child: DecoratedBox(decoration: BoxDecoration(
                              color: Color(0xFFE74C3C),
                              shape: BoxShape.circle))),
                    ),
                    Expanded(child: Text(note,
                        style: const TextStyle(color: Color(0xFFCCCCCC),
                            fontSize: 13, height: 1.4,
                            fontFamily: 'Raleway'))),
                  ],
                ),
              ))
            else
              const Text('Mejoras y correcciones',
                  style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13,
                      fontFamily: 'Raleway')),

            const SizedBox(height: 24),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!updateInfo.mandatory)
                  _Btn(
                    label: 'DESPUÉS',
                    primary: false,
                    onTap: () => Navigator.pop(context),
                  ),
                const SizedBox(width: 10),
                _Btn(
                  label: '↓  ACTUALIZAR',
                  primary: true,
                  onTap: () {
                    Navigator.pop(context);
                    // Navegar a pantalla de descarga
                    Navigator.of(context, rootNavigator: true).push(
                      PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black87,
                        pageBuilder: (_, __, ___) =>
                            UpdateDownloadScreen(updateInfo: updateInfo),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _Btn({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFFE74C3C), Color(0xFFFF6B35)])
              : null,
          borderRadius: BorderRadius.circular(8),
          border: primary ? null : Border.all(color: Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? Colors.white : Colors.white54,
                fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
    );
  }
}
