import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'theme/app_theme.dart';
import 'app_router.dart';
import 'services/update_service.dart';
import 'update_download_screen.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ValueNotifier global — cuando hay update pendiente, la app lo detecta
// y muestra la pantalla de descarga automáticamente
final ValueNotifier<UpdateInfo?> pendingUpdateNotifier =
    ValueNotifier<UpdateInfo?>(null);

const _channel = AndroidNotificationChannel(
  'update_channel',
  'Actualizaciones',
  description: 'Notificaciones de nuevas versiones de Three Skulls',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final notifs = FlutterLocalNotificationsPlugin();
    await notifs.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await notifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _checkAndNotify(notifs);
    return true;
  });
}

Future<void> _checkAndNotify(FlutterLocalNotificationsPlugin notifs) async {
  try {
    final update = await UpdateService.checkForUpdates();
    if (!update.isAvailable) return;
    final prefs = await SharedPreferences.getInstance();
    if (update.version == (prefs.getString('last_notified') ?? '')) return;
    await notifs.show(0,
        '💀 Three Skulls v${update.version} disponible',
        'Toca para actualizar',
        NotificationDetails(android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          importance: Importance.high, priority: Priority.high,
          icon: '@mipmap/ic_launcher')));
    await prefs.setString('last_notified', update.version);
  } catch (e) {
    debugPrint('Background check: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await notificationsPlugin.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (r) async {
      // Usuario tocó la notificación → buscar update y activar pantalla
      try {
        final update = await UpdateService.checkForUpdates();
        if (update.isAvailable) {
          pendingUpdateNotifier.value = update;
        }
      } catch (e) {
        debugPrint('Notification tap error: $e');
      }
    },
  );

  final android = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_channel);
  await android?.requestNotificationsPermission();

  // FCM setup
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission(alert: true, badge: true, sound: true);
  await fcm.subscribeToTopic('updates');

  FirebaseMessaging.onMessage.listen((msg) {
    final n = msg.notification;
    if (n == null) return;
    notificationsPlugin.show(n.hashCode, n.title, n.body,
        NotificationDetails(android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          importance: Importance.high, priority: Priority.high,
          icon: '@mipmap/ic_launcher')));
  });

  // App abierta desde notificación FCM
  FirebaseMessaging.onMessageOpenedApp.listen((_) async {
    try {
      final update = await UpdateService.checkForUpdates();
      if (update.isAvailable) pendingUpdateNotifier.value = update;
    } catch (e) { debugPrint('FCM open: $e'); }
  });

  // App cerrada → abierta por notificación FCM
  final initialMessage = await fcm.getInitialMessage();
  if (initialMessage != null) {
    try {
      final update = await UpdateService.checkForUpdates();
      if (update.isAvailable) pendingUpdateNotifier.value = update;
    } catch (e) { debugPrint('FCM initial: $e'); }
  }

  // Workmanager fallback
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask('ts_update', 'checkUpdate',
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep);

  // Verificar al abrir la app (silencioso)
  _checkAndNotify(notificationsPlugin);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
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
      builder: (context, child) {
        // ValueListenableBuilder detecta cuando hay update pendiente
        // y muestra la pantalla de descarga encima de todo
        return ValueListenableBuilder<UpdateInfo?>(
          valueListenable: pendingUpdateNotifier,
          builder: (context, update, _) {
            if (update != null) {
              // Mostrar pantalla de descarga como overlay
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(context).canPop()) return;
                showGeneralDialog(
                  context: context,
                  barrierColor: Colors.black87,
                  pageBuilder: (ctx, _, __) => UpdateDownloadScreen(
                    updateInfo: update,
                  ),
                ).then((_) {
                  pendingUpdateNotifier.value = null;
                });
              });
            }
            return child ?? const SizedBox();
          },
        );
      },
    );
  }
}
