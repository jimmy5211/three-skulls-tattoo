import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'app_router.dart';
import 'services/update_service.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ─── CANAL DE NOTIFICACIÓN ───────────────────────────────────
const _channel = AndroidNotificationChannel(
  'update_channel',
  'Actualizaciones',
  description: 'Notificaciones de nuevas versiones de Three Skulls',
  importance: Importance.high,
);

// ─── BACKGROUND CALLBACK ─────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // OBLIGATORIO en Flutter 3.x: inicializar bindings y plugins
    WidgetsFlutterBinding.ensureInitialized();
    final notifs = FlutterLocalNotificationsPlugin();
    const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await notifs.initialize(init);

    // Crear canal (idempotente)
    await notifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _checkAndNotify(notifs);
    return true;
  });
}

// ─── VERIFICAR Y NOTIFICAR ───────────────────────────────────
Future<void> _checkAndNotify(FlutterLocalNotificationsPlugin notifs) async {
  try {
    final update = await UpdateService.checkForUpdates();
    if (!update.isAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    if (update.version == (prefs.getString('last_notified') ?? '')) return;

    await notifs.show(
      0,
      '💀 Three Skulls v${update.version} disponible',
      'Toca para actualizar',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );

    await prefs.setString('last_notified', update.version);
  } catch (e) {
    debugPrint('Background check error: $e');
  }
}

// ─── MAIN ────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar notificaciones
  await notificationsPlugin.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (response) async {
      try {
        final update = await UpdateService.checkForUpdates();
        if (update.isAvailable) {
          await UpdateService.downloadAndInstall(update);
        }
      } catch (e) {
        debugPrint('Install error: $e');
      }
    },
  );

  // Crear canal de notificación
  final android = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_channel);
  // Solicitar permiso (Android 13+)
  await android?.requestNotificationsPermission();

  // Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'ts_update_check',
    'checkUpdate',
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // Verificar al abrir la app
  _checkAndNotify(notificationsPlugin);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const ThreeSkullsApp());
}

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
