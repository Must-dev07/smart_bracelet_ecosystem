// FCM wiring for foreground, background and terminated states.
// Tapping a notification deep-links to AlertDetailScreen via the navigatorKey.
//
// REQUIRES: google-services.json (Android) / GoogleService-Info.plist (iOS)
// from your Firebase project — see mobile/android_notes/README.md.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Data-only messages in background: the system tray notification is created
  // by FCM itself (notification payload); nothing else required here.
}

class PushService {
  final ApiClient _api;
  final GlobalKey<NavigatorState> navigatorKey;
  final _local = FlutterLocalNotificationsPlugin();

  PushService(this._api, this.navigatorKey);

  Future<void> init() async {
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Local notifications channel for foreground display.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final alertId = int.tryParse(resp.payload ?? '');
        if (alertId != null) _openAlert(alertId);
      },
    );

    // Foreground messages → local notification (FCM doesn't show them itself).
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n != null) {
        _local.show(
          message.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'alerts', 'Health alerts',
              importance: Importance.max, priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: message.data['alert_id'],
        );
      }
    });

    // Background tap → deep link.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final alertId = int.tryParse(message.data['alert_id'] ?? '');
      if (alertId != null) _openAlert(alertId);
    });

    // Terminated-state launch via notification tap.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      final alertId = int.tryParse(initial.data['alert_id'] ?? '');
      if (alertId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openAlert(alertId));
      }
    }

    // Register (and keep fresh) the device token with the backend.
    final token = await messaging.getToken();
    if (token != null) await _registerToken(token);
    messaging.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.post('/notifications/device-tokens/',
          body: {'token': token, 'platform': 'android'});
    } catch (_) {
      // Retried on next app start / token refresh.
    }
  }

  void _openAlert(int alertId) {
    navigatorKey.currentState?.pushNamed('/alert-detail', arguments: alertId);
  }
}
