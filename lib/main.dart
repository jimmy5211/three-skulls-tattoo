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

const _channelId = 'update_channel';
const _channel = AndroidNotificationChannel(
  _channelId,
  'Actualizaciones',
  description: 'Notificaciones de nuevas versiones de Three Skulls',
  importance: Importance.high,
);

// ─── MOSTRAR NOTIFICACIÓN LOCAL ──────────────────────────────
// Función top-level para poder llamarla desde el background handler
Future<void> _showLocalNotification(
  FlutterLocalNotificationsPlugin notifs,
  String title,
  String body,
  String payload,
) async {
  await notifs.show(
    0, title, body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, 'Actualizaciones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: payload,
  );
}

// ─── BACKGROUND FCM HANDLER ──────────────────────────────────
// Recibe mensajes data-only cuando la app está cerrada/background
// Muestra una notificación LOCAL — al tocarla, Flutter la maneja
// via onDidReceiveNotificationResponse de forma confiable
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  WidgetsFlutterBinding.ensureInitialized();

  final data = message.data;
  if (data['type'] != 'update') return;

  final notifs = FlutterLocalNotificationsPlugin();
  await notifs.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher')));

  await notifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  // Construir payload con los datos del update
  final updateInfo = UpdateInfo(
    version: data['version'] ?? '',
    downloadUrl: data['downloadUrl'] ?? '',
    releaseNotes: (data['notes'] as String?)
            ?.split(' • ')
            .where((s) => s.isNotEmpty)
            .toList() ?? [],
    isAvailable: true,
  );

  await _showLocalNotification(
    notifs,
    data['title'] ?? '💀 Three Skulls disponible',
    data['body'] ?? 'Toca para actualizar',
    updateInfo.toJson(), // payload completo
  );

  // Guardar en prefs también por si la app se abre antes de tocar
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_update', updateInfo.toJson());
}

// ─── WORKMANAGER ─────────────────────────────────────────────
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
    await _backgroundCheck(notifs);
    return true;
  });
}

Future<void> _backgroundCheck(FlutterLocalNotificationsPlugin notifs) async {
  try {
    final update = await UpdateService.checkForUpdates();
    if (!update.isAvailable) return;
    final prefs = await SharedPreferences.getInstance();
    if (update.version == (prefs.getString('last_notified') ?? '')) return;
    await _showLocalNotification(
      notifs,
      '💀 Three Skulls v${update.version} disponible',
      'Toca para actualizar',
      update.toJson(),
    );
    await prefs.setString('last_notified', update.version);
    await prefs.setString('pending_update', update.toJson());
  } catch (e) {
    debugPrint('Background check: $e');
  }
}

// ─── MAIN ────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicializar notificaciones locales
  await notificationsPlugin.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (response) async {
      debugPrint('Notification tapped! payload: ${response.payload}');
      try {
        UpdateInfo? update;
        if (response.payload != null && response.payload!.isNotEmpty) {
          update = UpdateInfo.fromJson(response.payload!);
          if (update.version.isEmpty || update.downloadUrl.isEmpty) {
            update = null;
          }
        }
        update ??= await UpdateService.checkForUpdates();

        if (update != null && (update.isAvailable || update.version.isNotEmpty)) {
          // Guardar en prefs — más confiable que el notifier cuando
          // el widget tree aún no está listo
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_update', update.toJson());
          // También setear el notifier por si el widget ya existe
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

  // FCM: app en primer plano recibe data-only message
  // → mostrar notificación local con payload
  FirebaseMessaging.onMessage.listen((msg) async {
    final data = msg.data;
    if (data['type'] != 'update') return;
    debugPrint('FCM data message received (foreground)');
    final update = UpdateInfo(
      version: data['version'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      releaseNotes: (data['notes'] as String?)
              ?.split(' • ')
              .where((s) => s.isNotEmpty)
              .toList() ?? [],
      isAvailable: true,
    );
    await _showLocalNotification(
      notificationsPlugin,
      data['title'] ?? '💀 Three Skulls disponible',
      data['body'] ?? 'Toca para actualizar',
      update.toJson(),
    );
  });

  // Suscribir a topic
  await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true);
  await FirebaseMessaging.instance.subscribeToTopic('updates');

  // Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask('ts_update', 'checkUpdate',
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep);

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

class _UpdateListenerState extends State<_UpdateListener>
    with WidgetsBindingObserver {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pendingUpdateNotifier.addListener(_onUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pendingUpdateNotifier.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPending();
  }

  Future<void> _checkPending() async {
    if (pendingUpdateNotifier.value != null) { _onUpdate(); return; }
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('pending_update');
      if (json != null && json.isNotEmpty && mounted) {
        await prefs.remove('pending_update');
        pendingUpdateNotifier.value = UpdateInfo.fromJson(json);
      }
    } catch (e) { debugPrint('_checkPending: $e'); }
  }

  void _onUpdate() {
    final update = pendingUpdateNotifier.value;
    if (update == null || _showing || !mounted) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) { _showing = false; return; }
      ConfirmUpdateDialog.show(context, update).then((_) {
        _showing = false;
        pendingUpdateNotifier.value = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
