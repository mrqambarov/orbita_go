import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle tap on notification (can redirect user back to app dashboard/active walk)
        },
      );

      // Create high-importance notification channel for Android 8.0+
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'orbita_walk_active_channel',
            'Faol sayohat xabarnomalari',
            description: 'Fonda qadamlarni va topshiriqlarni real vaqtda ko\'rsatish',
            importance: Importance.max,
            playSound: false,
            enableVibration: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  static Future<void> showWalkNotification({
    required int steps,
    required double distanceKm,
    String? activeQuestTitle,
    double? distanceToQuestKm,
  }) async {
    String contentText = 'Qadamlar: $steps qadam | Masofa: ${distanceKm.toStringAsFixed(2)} km';
    if (activeQuestTitle != null) {
      contentText += '\nTopshiriq: $activeQuestTitle';
      if (distanceToQuestKm != null) {
        if (distanceToQuestKm == 0) {
          contentText += ' (Bajarildi!)';
        } else {
          contentText += ' (${distanceToQuestKm.toStringAsFixed(2)} km qoldi)';
        }
      }
    }

    final androidDetails = AndroidNotificationDetails(
      'orbita_walk_active_channel',
      'Faol sayohat xabarnomalari',
      channelDescription: 'Fonda qadamlarni va topshiriqlarni real vaqtda ko\'rsatish',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // Prevents swipe-to-dismiss while active
      onlyAlertOnce: true, // Prevents annoying repetitive alert sounds
      showWhen: false, // Hides timestamp for a cleaner widget look
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public, // VISIBLE ON LOCK SCREEN!
      styleInformation: BigTextStyleInformation(
        contentText,
        contentTitle: '🏃 Orbita Walk — Faol yurish',
        summaryText: 'Yurish rejimi',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        888, // Constant notification ID
        '🏃 Orbita Walk — Faol yurish',
        contentText,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing dynamic notification: $e');
    }
  }

  static Future<void> cancelWalkNotification() async {
    try {
      await _notificationsPlugin.cancel(888);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }
}
