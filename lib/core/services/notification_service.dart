import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  static const int _sleepNotificationId = 1001;
  static const int _dailyReminderNotificationId = 1002;

  static const String _sleepChannelId = 'amimir_sleep_active';
  static const String _sleepChannelName = 'Tidur Aktif';
  static const String _sleepChannelDesc =
      'Notifikasi yang muncul saat timer tidur sedang berjalan.';

  // v2: channel baru dengan importance HIGH.
  // Channel lama (amimir_daily_reminder) dibuat dengan importance DEFAULT dan
  // Android tidak bisa upgrade importance channel yang sudah ada — harus ganti
  // ID untuk paksa buat channel baru dengan settings yang benar.
  static const String _dailyReminderChannelId = 'amimir_daily_reminder_v2';
  static const String _dailyReminderChannelName = 'Pengingat Harian';
  static const String _dailyReminderChannelDesc =
      'Pengingat untuk mengisi data harian (mood, aktivitas, kafein, makanan).';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _androidPlugin?.requestNotificationsPermission();
  }

  Future<void> requestExactAlarmPermission() async {
    await _androidPlugin?.requestExactAlarmsPermission();
  }

  Future<bool> canScheduleExactAlarms() async {
    return await _androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  // ─── Sleep Active ─────────────────────────────────────────────────────────

  Future<void> showSleepActiveNotification({required DateTime startTime}) async {
    if (!_initialized) await initialize();
    final String timeStr = _formatTime(startTime);
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _sleepChannelId,
          _sleepChannelName,
          channelDescription: _sleepChannelDesc,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFBAC3FF),
          playSound: false,
          enableVibration: false,
        );
    await _plugin.show(
      _sleepNotificationId,
      '😴  Tidur sedang aktif',
      'Dimulai pukul $timeStr  ·  Buka Amimir untuk menghentikan.',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelSleepNotification() async {
    await _plugin.cancel(_sleepNotificationId);
  }

  // ─── Daily Log Reminder ───────────────────────────────────────────────────

  Future<void> scheduleDailyLogReminder({required TimeOfDay time}) async {
    if (!_initialized) await initialize();

    await cancelDailyLogReminder();

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('[NotifService] timezone   : ${tz.local.name}');
    debugPrint('[NotifService] now (local) : $now');
    debugPrint('[NotifService] scheduled   : $scheduledDate');
    debugPrint('[NotifService] time set    : ${time.hour}:${time.minute}');

    // HIGH: muncul sebagai heads-up popup DAN tersimpan di panel notifikasi.
    // defaultImportance hanya masuk panel tapi tidak ada popup.
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _dailyReminderChannelId,
          _dailyReminderChannelName,
          channelDescription: _dailyReminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFBAC3FF),
          autoCancel: true,
        );

    try {
      await _plugin.zonedSchedule(
        _dailyReminderNotificationId,
        '📝  Waktunya catat harianmu!',
        'Jangan lupa isi mood, aktivitas, kafein, dan data makanan hari ini.',
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[NotifService] zonedSchedule SUCCESS');
    } catch (e) {
      debugPrint('[NotifService] zonedSchedule ERROR: $e');
      rethrow;
    }
  }

  Future<void> cancelDailyLogReminder() async {
    await _plugin.cancel(_dailyReminderNotificationId);
  }

  /// Tampilkan notifikasi pengingat harian SEKARANG menggunakan show()
  /// biasa — bukan zonedSchedule. Dipanggil oleh WorkManager callback
  /// di background. show() jauh lebih reliable dari BroadcastReceiver
  /// karena tidak bergantung pada AlarmManager yang bisa di-kill Samsung.
  Future<void> showDailyReminderNow() async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _dailyReminderChannelId,
          _dailyReminderChannelName,
          channelDescription: _dailyReminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFBAC3FF),
          autoCancel: true,
        );

    await _plugin.show(
      _dailyReminderNotificationId,
      '📝  Waktunya catat harianmu!',
      'Jangan lupa isi mood, aktivitas, kafein, dan data makanan hari ini.',
      const NotificationDetails(android: androidDetails),
    );
    debugPrint('[NotifService] showDailyReminderNow() called');
  }

  // ─── Test methods ─────────────────────────────────────────────────────────

  /// Test LANGSUNG — show() bukan scheduled. Untuk cek apakah channel
  /// dan permission normal. Kalau ini muncul, pipeline OK.
  Future<void> showImmediateTestNotification() async {
    if (!_initialized) await initialize();
    debugPrint('[NotifService] showImmediateTest called');
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _dailyReminderChannelId,
          _dailyReminderChannelName,
          channelDescription: _dailyReminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFBAC3FF),
          autoCancel: true,
        );
    await _plugin.show(
      8888,
      '✅ Test Langsung Amimir',
      'Kalau ini muncul, channel dan permission OK.',
      const NotificationDetails(android: androidDetails),
    );
    debugPrint('[NotifService] show() called - should appear now');
  }

  /// Test SCHEDULED — 1 menit dari sekarang. Untuk cek alarm pipeline.
  Future<void> scheduleTestNotification() async {
    if (!_initialized) await initialize();
    final tz.TZDateTime fireAt =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    debugPrint('[NotifService] TEST scheduled at: $fireAt');
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _dailyReminderChannelId,
          _dailyReminderChannelName,
          channelDescription: _dailyReminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          autoCancel: true,
        );
    await _plugin.zonedSchedule(
      9999,
      '✅ Test Terjadwal Amimir',
      'Alarm pipeline bekerja dengan benar.',
      fireAt,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
