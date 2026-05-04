import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Diálogo que explica ventajas/desventajas del modo segundo plano
/// y solicita al usuario desactivar optimización de batería.
class BackgroundServiceDialog extends StatelessWidget {
  const BackgroundServiceDialog({super.key});

  static const _channel = MethodChannel('com.threeskullstattoo.app/battery');

  /// Muestra el diálogo. Retorna true si el usuario aceptó.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BackgroundServiceDialog(),
    );
    return result ?? false;
  }

  /// Solicita al sistema ignorar optimización de batería para esta app.
  static Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (_) {}
  }

  /// Verifica si ya está ignorando la optimización.
  static Future<bool> isIgnoringBatteryOptimization() async {
    try {
      return await _channel.invokeMethod('isIgnoringBatteryOptimization') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Text('⚡', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text(
            'App en segundo plano',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Puedes permitir que Three Skulls Tattoo siga activa cuando cambias de app, evitando que pierdas tu trabajo.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            _buildSection(
              '✅ Ventajas',
              const Color(0xFF2A4A2A),
              [
                'Tu dibujo nunca se pierde al cambiar de app',
                'Regresa exactamente donde lo dejaste',
                'Sin esperas de recarga al volver',
                'Ideal para sesiones largas de diseño',
              ],
              const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 12),
            _buildSection(
              '⚠️ Desventajas',
              const Color(0xFF4A3A2A),
              [
                'Mayor consumo de batería en segundo plano',
                'Usa RAM constantemente (~150 MB)',
                'Puede calentar el dispositivo si se deja mucho tiempo',
                'Reduce duración de batería ~10-15%',
              ],
              const Color(0xFFFF9800),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                '💡 Recomendación: Actívalo si haces diseños largos. Desactívalo si usas la app esporádicamente.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'No, usar auto-guardado',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Activar segundo plano'),
        ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    Color bgColor,
    List<String> items,
    Color bulletColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: bulletColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(color: bulletColor, fontSize: 13)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
