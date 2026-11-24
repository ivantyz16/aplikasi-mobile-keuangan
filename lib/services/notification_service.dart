import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    // Sesuaikan dengan AndroidManifest.xml (@mipmap/launcher_icon)
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);
    await requestPermissions();

    _initialized = true;
  }

  /// Minta izin notifikasi (Android 13+) & exact alarm (Android 12+)
  static Future<void> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    final canExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    if (!canExact) {
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  /// Menampilkan notifikasi langsung ke layar HP
  static Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

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
    if (!_initialized) await init();
    await requestPermissions();

    // Hapus jadwal lama sebelum pasang yang baru
    await _plugin.cancel(100);

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

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final hasExactAlarm =
        await androidPlugin?.canScheduleExactNotifications() ?? false;

    await _plugin.zonedSchedule(
      100,
      'Waktunya menabung hari ini',
      'Catat pemasukanmu sekarang supaya streak menabung tidak terputus.',
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: hasExactAlarm
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
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