import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'push_notification_service.dart';

class BirthdayReminderService {
  static final BirthdayReminderService instance = BirthdayReminderService._();
  BirthdayReminderService._();

  // Reuse the shared plugin instance to avoid iOS double-init crashes
  FlutterLocalNotificationsPlugin get _notifications =>
      PushNotificationService.instance.localNotifications;

  Future<void> init() async {
    // No separate init needed — uses shared notification plugin
  }

  Future<void> scheduleBirthdayReminders(List<Map<String, dynamic>> birthdays) async {
    for (final b in birthdays) {
      final name = b['name'] ?? b['company'] ?? b['contact_name'] ?? 'Customer';
      final dateStr = b['birthday'] ?? b['date_of_birth'] ?? b['dob'] ?? '';
      if (dateStr.toString().isEmpty) continue;

      final dt = DateTime.tryParse(dateStr.toString());
      if (dt == null) continue;

      // Schedule for this year (or next if already passed)
      final now = DateTime.now();
      var targetDate = DateTime(now.year, dt.month, dt.day, 9, 0);
      if (targetDate.isBefore(now)) {
        targetDate = DateTime(now.year + 1, dt.month, dt.day, 9, 0);
      }

      final id = 'bday_${b['id'] ?? name.hashCode}_${targetDate.year}'.hashCode;
      final delay = targetDate.difference(now);
      if (delay.isNegative || delay.inDays > 365) continue;

      Future.delayed(delay, () {
        _notifications.show(
          id,
          'Birthday Reminder',
          "Today is $name's birthday! Send them a wish.",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'svss_crm_reminders',
              'CRM Reminders',
              channelDescription: 'Birthday and anniversary reminders',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      });
    }
  }

  Future<void> scheduleAnniversaryReminders(List<Map<String, dynamic>> anniversaries) async {
    for (final a in anniversaries) {
      final name = a['name'] ?? a['company'] ?? a['contact_name'] ?? 'Customer';
      final dateStr = a['anniversary'] ?? a['anniversary_date'] ?? '';
      if (dateStr.toString().isEmpty) continue;

      final dt = DateTime.tryParse(dateStr.toString());
      if (dt == null) continue;

      final now = DateTime.now();
      var targetDate = DateTime(now.year, dt.month, dt.day, 9, 0);
      if (targetDate.isBefore(now)) {
        targetDate = DateTime(now.year + 1, dt.month, dt.day, 9, 0);
      }

      final id = 'anniv_${a['id'] ?? name.hashCode}_${targetDate.year}'.hashCode;
      final delay = targetDate.difference(now);
      if (delay.isNegative || delay.inDays > 365) continue;

      Future.delayed(delay, () {
        _notifications.show(
          id,
          'Anniversary Reminder',
          "Today is $name's anniversary! Send them your wishes.",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'svss_crm_reminders',
              'CRM Reminders',
              channelDescription: 'Birthday and anniversary reminders',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      });
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
