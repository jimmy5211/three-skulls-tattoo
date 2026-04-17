import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'app_router.dart';
import 'services/update_service.dart';

// ─── BACKGROUND ISOLATE ──────────────────────────────────────
// @pragma es obligatorio en release builds — sin esto Workmanager
// no encuentra la función en el árbol de símbolos
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // CRÍTICO: el callback corre en un isolate separado.
    // Flutter y todos los plugins deben reinicializarse aquí.
    WidgetsFlutterBinding.ensureInitialized();

    // Reinicializar el plugin de notificaciones en este isolate
    final notifs = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifs.initialize(
        const InitializationSettings(android: androidInit));

    // Crear el canal (requerido Android 8+, idempotente si ya existe)
    final androidPlugin = notifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'update_channel',
        'Actualizaciones',
        description: 'Notificaciones de nuevas versiones de Three Skulls',
        importance: Importance.high,
      ),
    );

    // Verificar y notificar si hay update
    await _checkAndNotify(notifs);
    return Future.value(true);
  });
}

// ─── LÓGICA DE VERIFICACIÓN ──────────────────────────────────
Future<void> _checkAndNotify(FlutterLocalNotificationsPlugin notifs) async {
  try {
    final update = await UpdateService.checkForUpdates();
    if (!update.isAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    final lastNotified = prefs.getString('last_notified_version') ?? '';

    // Solo notificar si es una versión nueva que no hemos notificado antes
    if (update.version == lastNotified) return;

    await notifs.show(
      0,
      '💀 Three Skulls v${update.version} disponible',
      'Toca para actualizar la app',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'update_channel',
          'Actualizaciones',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );

    await prefs.setString('last_notified_version', update.version);
  } catch (e) {
    // Silencioso en background — no hay UI para mostrar errores
    debugPrint('Background update check error: $e');
  }
}

// ─── NOTIFICACIONES (instancia global para el main isolate) ──
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ─── MAIN ────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar notificaciones en el main isolate
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
    onDidReceiveNotificationResponse: (response) async {
      // Usuario tocó la notificación → descargar e instalar
      try {
        final update = await UpdateService.checkForUpdates();
        if (update.isAvailable) {
          await UpdateService.downloadAndInstall(update);
        }
      } catch (e) {
        debugPrint('Install from notification error: $e');
      }
    },
  );

  // 2. Crear canal de notificación (Android 8+)
  final androidPlugin = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'update_channel',
      'Actualizaciones',
      description: 'Notificaciones de nuevas versiones de Three Skulls',
      importance: Importance.high,
    ),
  );

  // 3. Solicitar permiso de notificaciones (Android 13+)
  await androidPlugin?.requestNotificationsPermission();

  // 4. Inicializar Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, // cambiar a true para ver logs en Logcat
  );

  // 5. Registrar tarea periódica (mínimo real en Android: 15 min)
  await Workmanager().registerPeriodicTask(
    'three_skulls_update_check',
    'checkUpdate',
    frequency: const Duration(hours: 6),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 15),
  );

  // 6. Verificar update inmediatamente al abrir la app
  // (no esperar al background task para la primera vez)
  _checkOnLaunch();

  // 7. Orientación y sistema UI
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ThreeSkullsApp());
}

// Verificación silenciosa al arrancar la app
Future<void> _checkOnLaunch() async {
  try {
    final update = await UpdateService.checkForUpdates();
    if (!update.isAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    final lastNotified = prefs.getString('last_notified_version') ?? '';
    if (update.version == lastNotified) return;

    await notificationsPlugin.show(
      0,
      '💀 Three Skulls v${update.version} disponible',
      'Toca para actualizar la app',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'update_channel',
          'Actualizaciones',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );

    await prefs.setString('last_notified_version', update.version);
  } catch (e) {
    debugPrint('Launch update check error: $e');
  }
}

// ─── APP ─────────────────────────────────────────────────────
class ThreeSkullsApp extends StatelessWidget {
  const ThreeSkullsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Three Skulls Tattoo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      backButtonDispatcher: RootBackButtonDispatcher(),
    );
  }
}
