import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('onDidReceiveBackgroundNotificationResponse ${notificationResponse.toString()}');

  // handle action
}

class LocalNotificationService {
  // Instance of Flutternotification plugin
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  void init() {
    final InitializationSettings initializationSettings = const InitializationSettings(
      android: AndroidInitializationSettings(
        '@drawable/ic_launcher_foreground',
      ),
      iOS: DarwinInitializationSettings(),
    );

    _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('onDidReceiveNotificationResponse :: $details');
        if (details.input != null) {}
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  void onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    // display a dialog with the notification details, tap ok to go to another page

    debugPrint('onDidReceiveLocalNotification :: $id, $title, $body, $payload');
  }

  Future<void> showNotification({
    required String? title,
    required String? body,
    String? payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'location_notification_channel_id',
          'location_notification',
          channelDescription: 'Used to show location notification for trip status.',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: 'local_notification',
          interruptionLevel: InterruptionLevel.active,
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
          presentBanner: true,
          badgeNumber: 0,
        ),
      ),
    );
  }
}
