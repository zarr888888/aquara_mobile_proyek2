import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'services/session_service.dart';
import 'widgets/session_boundary.dart';
import 'widgets/samudera_theme.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'aquara_channel_id',
          'Notifikasi AQUARA',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF009FE3),
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: message.notification!.title ?? 'AQUARA',
      body: message.notification!.body ?? '',
      notificationDetails: details,
    );
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _stage(String name, Future<void> Function() action) async {
  final timer = Stopwatch()..start();
  if (kDebugMode) debugPrint('startup $name.start 0ms');
  try {
    await action();
    if (kDebugMode)
      debugPrint('startup $name.done ${timer.elapsedMilliseconds}ms');
  } catch (_) {
    if (kDebugMode)
      debugPrint('startup $name.failed ${timer.elapsedMilliseconds}ms');
    rethrow;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

Future<void> _initializeNotifications(VoidCallback listen) async {
  try {
    await _stage('firebase', () async {
      await Firebase.initializeApp();
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _stage('permission', () async {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    });

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    listen();
    await Future.wait([
      for (final topic in ['all_users', 'info_pasar'])
        _stage(topic, () => FirebaseMessaging.instance.subscribeToTopic(topic)),
    ]);
  } catch (_) {
    // Stage diagnostics omit exception details.
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<int>? _sessionSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  int _revision = SessionService.instance.revision;
  bool _hadSession = SessionService.instance.hasSession;

  @override
  void initState() {
    super.initState();
    _sessionSubscription = SessionService.instance.changes.listen((revision) {
      if (!mounted) return;
      final session = SessionService.instance;
      if (_hadSession && revision != _revision) {
        final navigator = _navigatorKey.currentState;
        if (navigator != null) SessionNavigation.leaveNavigator(navigator);
      }
      _revision = revision;
      _hadSession = session.hasSession;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (kDebugMode)
        debugPrint(
          'startup first_frame.done ${_startupClock.elapsedMilliseconds}ms',
        );
      unawaited(_initializeNotifications(_listenForMessages));
    });
  }

  final _startupClock = Stopwatch()..start();

  void _listenForMessages() {
    if (!mounted) return;
    _messageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      debugPrint("Ada Sinyal Masuk Saat Aplikasi Dibuka!");

      if (message.notification != null) {
        _showLocalNotification(
          message.notification!.title ?? 'AQUARA',
          message.notification!.body ?? '',
        );
      }
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'aquara_channel_id',
          'Notifikasi AQUARA',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          color: Color(0xFF009FE3),
          icon: '@mipmap/ic_launcher',
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'AQUARA',
          themeMode: currentMode,

          theme: samuderaTheme(Brightness.light),
          darkTheme: samuderaTheme(Brightness.dark),

          home: const SplashScreen(),
        );
      },
    );
  }
}
