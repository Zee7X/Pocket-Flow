import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
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

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Schedule daily reminder to record expenses
  Future<void> scheduleDailyExpenseReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      101, // Daily reminder ID
      'PocketFlow 📊',
      'Sudah catat pengeluaran hari ini? Yuk luangkan 1 menit.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_expense_reminder',
          'Pengingat Harian',
          channelDescription: 'Pengingat untuk mencatat pengeluaran harian',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Send instant budget warning
  Future<void> showBudgetWarning({
    required String categoryName,
    required int spentAmount,
    required int budgetAmount,
  }) async {
    if (kIsWeb) return;
    await _notificationsPlugin.show(
      201,
      'Budget Peringatan ⚠️',
      'Pengeluaran kategori $categoryName sudah mendekati batas budget bulanan.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          'Peringatan Budget',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Cancel all scheduled reminders
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }
}
