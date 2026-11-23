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
    try {
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
    } catch (e, stackTrace) {
      debugPrint('NotificationService init error: $e\n$stackTrace');
    }
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

  /// Peringatan budget real-time. [percent] = 80 / 100.
  Future<void> showBudgetWarning({
    required String categoryName,
    required int spentAmount,
    required int budgetAmount,
    int percent = 80,
  }) async {
    if (kIsWeb) return;
    final over = percent >= 100;
    await _notificationsPlugin.show(
      // Satu id per kategori supaya notifikasi lama diganti, bukan menumpuk.
      200 + (categoryName.hashCode.abs() % 500),
      over ? 'Budget $categoryName habis' : 'Budget $categoryName sudah $percent%',
      over
          ? 'Terpakai ${_rp(spentAmount)} dari ${_rp(budgetAmount)}. Pengeluaran berikutnya di kategori ini sudah melebihi rencana.'
          : 'Terpakai ${_rp(spentAmount)} dari ${_rp(budgetAmount)}. Sisa ${_rp(budgetAmount - spentAmount)}.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          'Peringatan Budget',
          channelDescription: 'Muncul saat budget kategori hampir atau sudah habis',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Pengingat tagihan rutin pada tanggal tertentu jam 09.00.
  Future<void> scheduleBillReminder({
    required int id,
    required String title,
    required String body,
    required DateTime date,
  }) async {
    if (kIsWeb) return;
    final when = tz.TZDateTime(tz.local, date.year, date.month, date.day, 9);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_reminders',
          'Pengingat Tagihan',
          channelDescription: 'Pengingat langganan dan tagihan rutin',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id);
  }

  static String _rp(int v) {
    final s = v.abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '${v < 0 ? '-' : ''}Rp$s';
  }

  /// Cancel all scheduled reminders
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }
}
