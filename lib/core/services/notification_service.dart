import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Mengelola semua notifikasi OS (status bar) untuk Amimir.
///
/// Dua jenis notifikasi:
/// 1. **Sleep Active** — ongoing saat timer tidur berjalan.
/// 2. **Daily Log Reminder** — ditampilkan oleh WorkManager callback
///    (lihat main.dart) setiap kali task terjadwal fire, bukan oleh
///    AlarmManager/zonedSchedule. WorkManager dipilih karena Samsung
///    (One UI) agresif mematikan BroadcastReceiver dari AlarmManager
///    sebelum sempat menampilkan notifikasi, sedangkan JobScheduler
///    yang dipakai WorkManager tidak diperlakukan sama.
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

  /// Tampilkan notifikasi pengingat harian. Dipanggil oleh WorkManager
  /// callback (lihat callbackDispatcher di main.dart) saat task terjadwal
  /// fire — bukan dipanggil langsung dari UI.
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
      'Waktunya catat harianmu!',
      'Jangan lupa isi mood, aktivitas, kafein, dan data makanan hari ini.',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelDailyReminderNotification() async {
    await _plugin.cancel(_dailyReminderNotificationId);
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
