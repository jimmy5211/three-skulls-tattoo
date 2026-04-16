import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
    print("Error: $e");
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
    'Actualización disponible',
    'Toca para actualizar la app',
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
    onDidReceiveNotificationResponse: (response) {
      print("Notificación tocada");
    },
  );

  // ⚙️ Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  Workmanager().registerPeriodicTask(
    "updateTask",
    "checkUpdate",
    frequency: Duration(hours: 6),
  );

  runApp(const MyApp());
}

// 🎨 APP
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Three Skulls Tattoo',
      home: const HomePage(),
    );
  }
}

// 🏠 HOME
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Three Skulls Tattoo")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await checkForUpdate();
          },
          child: const Text("Buscar actualización"),
        ),
      ),
    );
  }
}
