import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'photoland_channel',
      'Photoland Notifications',
      description: 'Used for all notifications.',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'photoland_channel',
      'Photoland Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
