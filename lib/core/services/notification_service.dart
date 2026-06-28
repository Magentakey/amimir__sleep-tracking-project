import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Mengelola semua notifikasi OS (status bar) untuk Amimir.
///
/// Tiga jenis notifikasi yang dikelola:
/// 1. **Sleep Active** — ongoing saat timer tidur berjalan (tidak bisa
///    di-swipe, hilang lewat [cancelSleepNotification]).
/// 2. **Daily Log Reminder** — notifikasi terjadwal harian yang mengingatkan
///    user untuk mengisi data harian (mood, aktivitas, kafein, makanan).
///
/// Notifikasi achievement TIDAK melewati kelas ini — ditangani in-app
/// oleh [AchievementUnlockBanner].
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();

  /// Singleton — selalu pakai instance yang sama.
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

  // ─── Inisialisasi ─────────────────────────────────────────────────────────

  /// Inisialisasi plugin. Dipanggil sekali di [main()].
  /// Aman dipanggil berkali-kali — idempotent.
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

  /// Minta izin notifikasi ke user.
  ///
  /// Android 13+ (API 33+): memunculkan dialog izin sistem sekali saja.
  /// Android di bawah 13: no-op, izin otomatis diberikan.
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
  }

  // ─── Sleep Active ─────────────────────────────────────────────────────────

  /// Tampilkan notifikasi "Tidur sedang aktif" di status bar.
  ///
  /// Bersifat `ongoing` (tidak bisa di-swipe) — hilang hanya lewat
  /// [cancelSleepNotification()].
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

  /// Batalkan notifikasi sleep aktif.
  /// Dipanggil saat user menghentikan timer (Stop Sleep).
  Future<void> cancelSleepNotification() async {
    await _plugin.cancel(_sleepNotificationId);
  }

  // ─── Daily Log Reminder ───────────────────────────────────────────────────

  /// Jadwalkan pengingat harian pada [time] yang ditentukan user.
  ///
  /// Notifikasi akan muncul setiap hari pada jam yang sama.
  /// Menggunakan [AndroidScheduleMode.inexactAllowWhileIdle] — tidak
  /// membutuhkan izin SCHEDULE_EXACT_ALARM (lebih hemat baterai).
  ///
  /// Panggil [cancelDailyLogReminder()] sebelum memanggil ini lagi
  /// kalau user mengubah waktu pengingat, supaya jadwal lama tidak
  /// tumpang-tindih.
  Future<void> scheduleDailyLogReminder({required TimeOfDay time}) async {
    if (!_initialized) await initialize();

    // Batalkan jadwal lama sebelum buat yang baru
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

    // Kalau waktu hari ini sudah lewat, jadwalkan untuk besok
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

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

    await _plugin.zonedSchedule(
      _dailyReminderNotificationId,
      '📝  Waktunya catat harianmu!',
      'Jangan lupa isi mood, aktivitas, kafein, dan data makanan hari ini.',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // matchDateTimeComponents.time → ulang setiap hari di jam yang sama
      matchDateTimeComponents: DateTimeComponents.time,
      // Diperlukan oleh flutter_local_notifications meski tidak relevan di Android
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Batalkan pengingat harian.
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
