import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Mengelola semua notifikasi OS (status bar) untuk Amimir.
///
/// Dua jenis notifikasi:
/// 1. **Sleep Active** — ongoing saat timer tidur berjalan.
/// 2. **Daily Log Reminder** — notifikasi terjadwal harian menggunakan
///    [AndroidScheduleMode.exactAllowWhileIdle] supaya muncul tepat waktu
///    meski device sedang idle/Doze mode.
///
/// Kenapa exactAllowWhileIdle, bukan inexactAllowWhileIdle:
/// Mode inexact bisa ditunda OS berjam-jam saat battery optimization aktif
/// (terutama Samsung). Mode exact dijamin muncul tepat waktu — ini yang
/// dipakai aplikasi alarm dan kalender.
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  // ── ID & Channel ──────────────────────────────────────────────────────────

  static const int _sleepNotificationId = 1001;
  static const int _dailyReminderNotificationId = 1002;

  static const String _sleepChannelId = 'amimir_sleep_active';
  static const String _sleepChannelName = 'Tidur Aktif';
  static const String _sleepChannelDesc =
      'Notifikasi yang muncul saat timer tidur sedang berjalan.';

  static const String _dailyReminderChannelId = 'amimir_daily_reminder';
  static const String _dailyReminderChannelName = 'Pengingat Harian';
  static const String _dailyReminderChannelDesc =
      'Pengingat untuk mengisi data harian (mood, aktivitas, kafein, makanan).';

  // ─────────────────────────────────────────────────────────────────────────

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // ─── Inisialisasi ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Minta izin notifikasi (POST_NOTIFICATIONS) ke user.
  /// Android 13+ (API 33+): muncul dialog sistem sekali saja.
  Future<void> requestPermissions() async {
    await _androidPlugin?.requestNotificationsPermission();
  }

  /// Minta izin exact alarm ke user (SCHEDULE_EXACT_ALARM).
  ///
  /// Android 12+ (API 31+): sistem mungkin meminta user mengizinkan
  /// exact alarm via Settings → Apps → Amimir → Alarms & Reminders.
  /// Method ini membuka halaman settings tersebut langsung.
  ///
  /// Dipanggil di profile_screen saat user menyalakan reminder,
  /// bukan di startup — agar tidak membingungkan user yang belum butuh.
  Future<void> requestExactAlarmPermission() async {
    await _androidPlugin?.requestExactAlarmsPermission();
  }

  /// Cek apakah izin exact alarm sudah diberikan.
  Future<bool> canScheduleExactAlarms() async {
    final bool? result = await _androidPlugin?.canScheduleExactNotifications();
    return result ?? false;
  }

  // ─── Sleep Active ─────────────────────────────────────────────────────────

  Future<void> showSleepActiveNotification({
    required DateTime startTime,
  }) async {
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

  /// Jadwalkan pengingat harian pada [time] yang ditentukan user.
  ///
  /// Memakai [AndroidScheduleMode.exactAllowWhileIdle] — notifikasi dijamin
  /// muncul tepat waktu meski device sedang idle/Doze mode/battery saver.
  /// Butuh permission SCHEDULE_EXACT_ALARM di AndroidManifest, dan pada
  /// Android 12+ user perlu grant via Settings jika belum diizinkan.
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

    // ── Debug log — hapus setelah notification confirmed bekerja ──────────
    debugPrint('[NotifService] timezone   : ${tz.local.name}');
    debugPrint('[NotifService] now (local) : $now');
    debugPrint('[NotifService] scheduled   : $scheduledDate');
    debugPrint('[NotifService] time set    : ${time.hour}:${time.minute}');
    // ──────────────────────────────────────────────────────────────────────

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _dailyReminderChannelId,
          _dailyReminderChannelName,
          channelDescription: _dailyReminderChannelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
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

  /// Test: kirim notifikasi dalam 1 menit dari sekarang (tanpa repeat).
  /// Dipakai untuk verifikasi bahwa pipeline notifikasi bekerja.
  /// Hapus setelah confirmed bekerja.
  Future<void> scheduleTestNotification() async {
    if (!_initialized) await initialize();

    final tz.TZDateTime fireAt =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

    debugPrint('[NotifService] TEST notif scheduled at: $fireAt');

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
      '✅ Test Notifikasi Amimir',
      'Notifikasi berhasil! Pipeline notifikasi bekerja dengan benar.',
      fireAt,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelDailyLogReminder() async {
    await _plugin.cancel(_dailyReminderNotificationId);
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
