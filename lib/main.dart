import 'dart:convert';
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
import 'confirm_update_dialog.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

/// Verificar update y mostrar notificación local con payload de datos
Future<void> _checkAndNotify(FlutterLocalNotificationsPlugin notifs) async {
  try {
    final update = await UpdateService.checkForUpdates();
    if (!update.isAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    if (update.version == (prefs.getString('last_notified') ?? '')) return;

    // Guardar datos en el payload — así al tocar la notificación
    // no necesitamos consultar nada, ya tenemos todo
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
      payload: update.toJson(), // ← datos serializados
    );

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
    onDidReceiveNotificationResponse: (response) async {
      // ✅ Usar payload directo — no necesita red
      try {
        if (response.payload != null && response.payload!.isNotEmpty) {
          final update = UpdateInfo.fromJson(response.payload!);
          pendingUpdateNotifier.value = update;
        } else {
          // Fallback: consultar GitHub
          final update = await UpdateService.checkForUpdates();
          if (update.isAvailable) pendingUpdateNotifier.value = update;
        }
      } catch (e) {
        debugPrint('Notification tap: $e');
      }
    },
  );

  final android = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_channel);
  await android?.requestNotificationsPermission();

  // FCM
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission(alert: true, badge: true, sound: true);
  await fcm.subscribeToTopic('updates');

  // App en primer plano → mostrar notificación local con payload
  FirebaseMessaging.onMessage.listen((msg) async {
    final n = msg.notification;
    if (n == null) return;
    // Intentar construir UpdateInfo desde datos FCM
    final data = msg.data;
    UpdateInfo? update;
    if (data['version'] != null && data['downloadUrl'] != null) {
      update = UpdateInfo(
        version: data['version']!,
        downloadUrl: data['downloadUrl']!,
        releaseNotes: (data['notes'] as String?)
                ?.split(' • ')
                .where((s) => s.isNotEmpty)
                .toList() ?? [],
        isAvailable: true,
      );
    }
    await notificationsPlugin.show(
      0, n.title, n.body,
      NotificationDetails(android: AndroidNotificationDetails(
        _channel.id, _channel.name,
        importance: Importance.high, priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      )),
      payload: update?.toJson(),
    );
  });

  // App background → usuario tocó notificación FCM
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    final data = msg.data;
    if (data['version'] != null && data['downloadUrl'] != null) {
      pendingUpdateNotifier.value = UpdateInfo(
        version: data['version']!,
        downloadUrl: data['downloadUrl']!,
        releaseNotes: (data['notes'] as String?)
                ?.split(' • ')
                .where((s) => s.isNotEmpty)
                .toList() ?? [],
        isAvailable: true,
      );
    }
  });

  // App cerrada → abierta por notificación FCM
  final initialMessage = await fcm.getInitialMessage();
  if (initialMessage != null) {
    final data = initialMessage.data;
    if (data['version'] != null && data['downloadUrl'] != null) {
      pendingUpdateNotifier.value = UpdateInfo(
        version: data['version']!,
        downloadUrl: data['downloadUrl']!,
        releaseNotes: (data['notes'] as String?)
                ?.split(' • ')
                .where((s) => s.isNotEmpty)
                .toList() ?? [],
        isAvailable: true,
      );
    }
  }

  // Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask('ts_update', 'checkUpdate',
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep);

  // Verificar al abrir
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
      builder: (context, child) =>
          _UpdateListener(child: child ?? const SizedBox()),
    );
  }
}

class _UpdateListener extends StatefulWidget {
  final Widget child;
  const _UpdateListener({required this.child});

  @override
  State<_UpdateListener> createState() => _UpdateListenerState();
}

class _UpdateListenerState extends State<_UpdateListener> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    pendingUpdateNotifier.addListener(_onUpdate);
    // ✅ Fix: verificar si ya hay un update pendiente al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pendingUpdateNotifier.value != null) _onUpdate();
    });
  }

  @override
  void dispose() {
    pendingUpdateNotifier.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    final update = pendingUpdateNotifier.value;
    if (update == null || _showing || !mounted) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ConfirmUpdateDialog.show(context, update).then((_) {
        _showing = false;
        pendingUpdateNotifier.value = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
