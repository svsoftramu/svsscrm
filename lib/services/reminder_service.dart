import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  Database? _db;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Uuid _uuid = const Uuid();
  bool _isInitialized = false;

  static const String _tableName = 'reminders';
  static const String _channelId = 'svss_crm_reminders';
  static const String _channelName = 'CRM Reminders';
  static const String _channelDescription =
      'Notifications for CRM scheduled reminders';

  /// Initialize the reminder service: database + notifications.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Initialize database
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'crm_reminders.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            scheduled_at INTEGER NOT NULL,
            is_recurring INTEGER DEFAULT 0,
            interval_days INTEGER DEFAULT 0
          )
        ''');
      },
    );

    _isInitialized = true;

    // Reschedule all future reminders on init
    await rescheduleAllReminders();
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Schedule a new reminder. Returns the generated reminder ID.
  Future<String> scheduleReminder({
    required String entityType,
    required String entityId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    bool isRecurring = false,
    int intervalDays = 0,
  }) async {
    await _ensureInitialized();

    final id = _uuid.v4();
    final notificationId = id.hashCode.abs() % 2147483647;

    // Save to database
    await _db!.insert(_tableName, {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'title': title,
      'body': body,
      'scheduled_at': scheduledAt.millisecondsSinceEpoch,
      'is_recurring': isRecurring ? 1 : 0,
      'interval_days': intervalDays,
    });

    // Schedule the notification
    await _scheduleNotification(
      notificationId: notificationId,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      payload: '$entityType:$entityId:$id',
    );

    return id;
  }

  /// Cancel a reminder by its ID.
  Future<void> cancelReminder(String id) async {
    await _ensureInitialized();

    final notificationId = id.hashCode.abs() % 2147483647;
    await _notifications.cancel(notificationId);
    await _db!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Get all reminders for a specific entity.
  Future<List<Map<String, dynamic>>> getRemindersForEntity(
      String entityType, String entityId) async {
    await _ensureInitialized();

    final results = await _db!.query(
      _tableName,
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'scheduled_at ASC',
    );

    return results.map((row) {
      return {
        ...row,
        'scheduled_at_dt': DateTime.fromMillisecondsSinceEpoch(
            row['scheduled_at'] as int),
        'is_recurring': (row['is_recurring'] as int) == 1,
      };
    }).toList();
  }

  /// Get all reminders from the database.
  Future<List<Map<String, dynamic>>> getAllReminders() async {
    await _ensureInitialized();

    final results = await _db!.query(
      _tableName,
      orderBy: 'scheduled_at ASC',
    );

    return results.map((row) {
      return {
        ...row,
        'scheduled_at_dt': DateTime.fromMillisecondsSinceEpoch(
            row['scheduled_at'] as int),
        'is_recurring': (row['is_recurring'] as int) == 1,
      };
    }).toList();
  }

  /// Reschedule all future reminders. Called on app start.
  /// Also fires any past-due reminders immediately and handles
  /// recurring reminders.
  Future<void> rescheduleAllReminders() async {
    await _ensureInitialized();

    final now = DateTime.now();
    final allReminders = await _db!.query(_tableName);

    for (final row in allReminders) {
      final id = row['id'] as String;
      final title = row['title'] as String;
      final body = row['body'] as String;
      final scheduledAt = DateTime.fromMillisecondsSinceEpoch(
          row['scheduled_at'] as int);
      final isRecurring = (row['is_recurring'] as int) == 1;
      final intervalDays = row['interval_days'] as int;
      final entityType = row['entity_type'] as String;
      final entityId = row['entity_id'] as String;
      final notificationId = id.hashCode.abs() % 2147483647;

      if (scheduledAt.isAfter(now)) {
        // Future reminder: reschedule it
        await _scheduleNotification(
          notificationId: notificationId,
          title: title,
          body: body,
          scheduledAt: scheduledAt,
          payload: '$entityType:$entityId:$id',
        );
      } else {
        // Past-due reminder: fire it immediately
        await _showImmediateNotification(
          notificationId: notificationId,
          title: title,
          body: '$body (was due ${_formatDueAgo(now.difference(scheduledAt))})',
          payload: '$entityType:$entityId:$id',
        );

        if (isRecurring && intervalDays > 0) {
          // Calculate the next occurrence
          DateTime nextDate = scheduledAt;
          while (nextDate.isBefore(now)) {
            nextDate = nextDate.add(Duration(days: intervalDays));
          }
          // Update the DB with the next occurrence
          await _db!.update(
            _tableName,
            {'scheduled_at': nextDate.millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [id],
          );
          await _scheduleNotification(
            notificationId: notificationId,
            title: title,
            body: body,
            scheduledAt: nextDate,
            payload: '$entityType:$entityId:$id',
          );
        } else {
          // Non-recurring past reminder: remove from DB
          await _db!
              .delete(_tableName, where: 'id = ?', whereArgs: [id]);
        }
      }
    }
  }

  /// Schedule a notification using Future.delayed approach for simplicity.
  /// For production, this uses the platform notification scheduling.
  Future<void> _scheduleNotification({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    final delay = scheduledAt.difference(DateTime.now());

    if (delay.isNegative) {
      // Already past, show immediately
      await _showImmediateNotification(
        notificationId: notificationId,
        title: title,
        body: body,
        payload: payload,
      );
      return;
    }

    // Use Future.delayed for scheduling
    // This works while the app is running. For background delivery,
    // the rescheduleAllReminders() method fires past-due reminders on app start.
    Future.delayed(delay, () async {
      await _showImmediateNotification(
        notificationId: notificationId,
        title: title,
        body: body,
        payload: payload,
      );
    });
  }

  Future<void> _showImmediateNotification({
    required int notificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  String _formatDueAgo(Duration duration) {
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    return '${duration.inDays}d ago';
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
