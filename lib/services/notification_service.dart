import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Minta izin notifikasi (Android 13+) & izin exact alarm (Android 12+)
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  /// Menampilkan notifikasi langsung ke layar HP
  static Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sakuin_channel',
      'Pengingat Tabungan',
      channelDescription: 'Notifikasi pengingat menabung dan target',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Menjadwalkan pengingat harian otomatis di luar aplikasi
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'sakuin_daily_reminder',
      'Pengingat Harian',
      channelDescription: 'Pengingat rutin untuk menjaga streak menabung',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      100,
      'Waktunya menabung hari ini',
      'Catat pemasukanmu sekarang supaya streak menabung tidak terputus.',
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Membatalkan pengingat harian jika toggle di Settings dimatikan
  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(100);
  }
}