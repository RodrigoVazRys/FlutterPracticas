import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final _codeStreamController = StreamController<String>.broadcast();
  
  Stream<String> get onCodeReceived => _codeStreamController.stream;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    // Inicialización requerida para notificaciones locales
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _codeStreamController.add(response.payload!);
        }
      },
    );

    try {
      final token = await _fcm.getToken();
      if (kDebugMode) print('FCM TOKEN: $token');
    } catch (_) {}

    // 1. Terminated / Cerrada completamente y se abre desde la notificación
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _processMessageData(initialMessage);
    }

    // 2. Foreground / App abierta
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 3. Background / App en segundo plano y se toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen(_processMessageData);

    _initialized = true;
  }

  void _processMessageData(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;
    String title = notification?.title ?? '';
    String body = notification?.body ?? '';

    String codeToSend = data['codigo']?.toString() ?? '';
    if (codeToSend.isEmpty) {
      if (body.toLowerCase().contains('orden 66') || title.toLowerCase().contains('orden 66')) {
        codeToSend = 'Ejecutando la Orden 66';
      }
    }

    if (codeToSend.isNotEmpty) {
      // Retraso para dar tiempo a que la HomePage se monte si la app estaba cerrada
      Future.delayed(const Duration(milliseconds: 500), () {
        _codeStreamController.add(codeToSend);
      });
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Procesar comando en vivo
    _processMessageData(message);

    final data = message.data;
    final notification = message.notification;

    String title = notification?.title ?? 'Notificación SUMS';
    String body = notification?.body ?? '';

    if (notification == null && data.containsKey('codigo')) {
      body = 'Código de confirmación: ${data['codigo']}';
    }

    String payload = data['codigo']?.toString() ?? '';
    if (payload.isEmpty && (body.toLowerCase().contains('orden 66') || title.toLowerCase().contains('orden 66'))) {
      payload = 'Ejecutando la Orden 66';
    }

    _showLocalNotification(title: title, body: body, payload: payload);
  }

  void _showLocalNotification({required String title, required String body, String? payload}) {
    try {
      _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sums_channel',
            'SUMS Notificaciones',
            importance: Importance.max,
            priority: Priority.high,
            largeIcon: const DrawableResourceAndroidBitmap('order66'),
            styleInformation: BigPictureStyleInformation(
              const DrawableResourceAndroidBitmap('order66'),
              contentTitle: title,
              summaryText: body,
            ),
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error mostrando notificacion con imagen: $e');
      // Fallback sin imagen en caso de que la imagen sea inválida o muy pesada
      try {
        _localNotifications.show(
          DateTime.now().millisecond,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'sums_channel',
              'SUMS Notificaciones',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: payload,
        );
      } catch (_) {}
    }
  }

  void close() {
    _codeStreamController.close();
  }
}
