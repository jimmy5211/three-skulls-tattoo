import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'app_router.dart';
import 'services/update_service.dart';

// 🔔 Notificaciones
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 🔄 BACKGROUND (fuera de la clase, requerido por Workmanager)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await _checkForUpdateBackground();
    return Future.value(true);
  });
}

// 🔍 Verificar update en background
Future<void> _checkForUpdateBackground() async {
  try {
    final update = await UpdateService.checkForUpdates();
    final prefs = await SharedPreferences.getInstance();
    final lastNotified = prefs.getString('last_notified_version') ?? '';

    if (update.isAvailable && update.version != lastNotified) {
      await _showUpdateNotification(update);
      await prefs.setString('last_notified_version', update.version);
    }
  } catch (e) {
    print('Error verificando actualización en background: $e');
  }
}

// 🔔 Mostrar notificación de update
Future<void> _showUpdateNotification(UpdateInfo update) async {
  const androidDetails = AndroidNotificationDetails(
    'update_channel',
    'Actualizaciones',
    channelDescription: 'Notificaciones de nuevas versiones',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  const details = NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
    0,
    '💀 Nueva versión ${update.version} disponible',
    'Toca para actualizar Three Skulls Tattoo',
    details,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔔 Inicializar notificaciones
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await notificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) async {
      // El usuario tocó la notificación → verificar y descargar
      try {
        final update = await UpdateService.checkForUpdates();
        if (update.isAvailable) {
          await UpdateService.downloadAndInstall(update);
        }
      } catch (e) {
        print('Error al instalar desde notificación: $e');
      }
    },
  );

  // Solicitar permiso de notificaciones en Android 13+
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // ⚙️ Workmanager — verificar updates en background cada 6 horas
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    'updateTask',
    'checkUpdate',
    frequency: const Duration(hours: 6),
    constraints: Constraints(
      networkType: NetworkType.connected, // solo con internet
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // 🔒 Orientación y UI
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
