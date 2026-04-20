import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../screens/notifications_screen.dart';
import '../screens/task_screen.dart';
import '../screens/leads_screen.dart';
import '../screens/leave_screen.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'svss_crm_channel',
    'SVSOFT Notifications',
    description: 'Notifications for leads, tasks, and approvals',
    importance: Importance.high,
  );

  Future<void> init() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if the app was opened from a terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Slight delay to let the navigator settle
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateFromData(initialMessage.data);
      });
    }

    // Get and register FCM token
    await _registerToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((token) => _sendTokenToServer(token));
  }

  Future<void> _registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      if (ApiService.instance.isAuthenticated) {
        await ApiService.instance.post('push/register', {
          'device_token': token,
          'platform': 'android',
        });
      }
    } catch (e) {
      debugPrint('[FCM] Error sending token to server: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'SVSOFT',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[FCM] Notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromData(data);
      } catch (e) {
        debugPrint('[FCM] Error parsing notification payload: $e');
        _navigateToNotifications();
      }
    } else {
      _navigateToNotifications();
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Background notification tapped: ${message.data}');
    _navigateFromData(message.data);
  }

  /// Route to the appropriate screen based on notification type
  void _navigateFromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'task':
        nav.push(MaterialPageRoute(builder: (_) => const TaskScreen()));
        break;
      case 'lead':
        nav.push(MaterialPageRoute(builder: (_) => const LeadsScreen()));
        break;
      case 'leave':
        nav.push(MaterialPageRoute(builder: (_) => const LeaveScreen()));
        break;
      default:
        _navigateToNotifications();
        break;
    }
  }

  void _navigateToNotifications() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }
}
