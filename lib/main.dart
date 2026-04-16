import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'app_router.dart';
import 'services/update_service.dart'; // 👈 TU updater

// 🔔 Notificaciones
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 🔄 BACKGROUND
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await checkForUpdate();
    return Future.value(true);
  });
}

// 🔍 VERIFICAR UPDATE (USA TU SISTEMA)
Future<void> checkForUpdate() async {
  try {
    final update = await UpdateService.checkForUpdates();

    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString("last_version") ?? "";

    if (update.isAvailable && update.version != lastVersion) {
      await showNotification(update);
      await prefs.setString("last_version", update.version);
    }
  } catch (e) {
    print("Error verificando actualización: $e");
  }
}

// 🔔 NOTIFICACIÓN
Future<void> showNotification(UpdateInfo update) async {
  const androidDetails = AndroidNotificationDetails(
    'update_channel',
    'Actualizaciones',
    importance: Importance.high,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
    0,
    'Nueva versión ${update.version} disponible 🚀',
    'Toca para actualizar',
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
      final update = await UpdateService.checkForUpdates();

      if (update.isAvailable) {
        // 👉 Aquí se dispara tu sistema actual de actualización
        await UpdateService.downloadAndInstall(update);
      }
    },
  );

  // ⚙️ Workmanager (cada 6 horas)
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  Workmanager().registerPeriodicTask(
    "updateTask",
    "checkUpdate",
    frequency: const Duration(hours: 6),
  );

  // 🔒 CONFIG ORIGINAL (NO TOCADA)
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
