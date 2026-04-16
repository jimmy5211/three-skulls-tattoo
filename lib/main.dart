import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'app_router.dart';

// 🔔 Notificaciones
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 📡 URL JSON
const String updateUrl =
    "https://api.jsonbin.io/v3/b/69b8b65eaa77b81da9ef4f41";

// 🔄 BACKGROUND
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await checkForUpdate();
    return Future.value(true);
  });
}

// 🔍 VERIFICAR UPDATE
Future<void> checkForUpdate() async {
  try {
    final response = await Dio().get(updateUrl);
    final data = response.data["record"];

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = int.parse(packageInfo.buildNumber);
    final serverVersion = data["versionCode"];

    final prefs = await SharedPreferences.getInstance();
    final lastNotified = prefs.getInt("last_version") ?? 0;

    if (serverVersion > currentVersion &&
        serverVersion != lastNotified) {
      await showNotification();
      await prefs.setInt("last_version", serverVersion);
    }
  } catch (e) {
    print("Error verificando actualización: $e");
  }
}

// 🔔 NOTIFICACIÓN
Future<void> showNotification() async {
  const androidDetails = AndroidNotificationDetails(
    'update_channel',
    'Actualizaciones',
    importance: Importance.high,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: androidDetails);

  await notificationsPlugin.show(
    0,
    'Nueva versión disponible 🚀',
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
      print("Notificación tocada");

      // 🔥 AQUÍ LLAMAMOS TU SISTEMA DE UPDATE
      // (como ya tienes uno, esto lo dispara)
      await checkForUpdate();
    },
  );

  // ⚙️ Workmanager (cada 6 horas)
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  Workmanager().registerPeriodicTask(
    "updateTask",
    "checkUpdate",
    frequency: const Duration(hours: 6),
  );

  // 🔒 TU CONFIGURACIÓN ORIGINAL (NO SE TOCA)
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
