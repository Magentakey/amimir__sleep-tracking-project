import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Menyimpan preferensi pengaturan global aplikasi yang tidak terikat
/// ke akun manapun — berbeda dengan box per-user (sleep log, daily log,
/// dll) yang dibuka/ditutup oleh [UserSessionService].
///
/// Saat ini hanya dipakai untuk preferensi notifikasi pengingat harian.
class LocalSettingsService {
  /// Nama box ini global (tidak per-user) karena pengaturan notifikasi
  /// berlaku di level device, bukan per-akun.
  static const String settingsBoxName = 'local_settings';

  static const String _reminderEnabledKey = 'daily_reminder_enabled';
  static const String _reminderHourKey = 'daily_reminder_hour';
  static const String _reminderMinuteKey = 'daily_reminder_minute';
  static const String _lastUidKey = 'last_logged_in_uid';

  /// Default waktu pengingat: 21:00
  static const int _defaultHour = 21;
  static const int _defaultMinute = 0;

  Box get _box => Hive.box(settingsBoxName);

  // ─── Getter ───────────────────────────────────────────────────────────────

  bool getReminderEnabled() {
    return _box.get(_reminderEnabledKey, defaultValue: false) as bool;
  }

  TimeOfDay getReminderTime() {
    final int hour =
        _box.get(_reminderHourKey, defaultValue: _defaultHour) as int;
    final int minute =
        _box.get(_reminderMinuteKey, defaultValue: _defaultMinute) as int;
    return TimeOfDay(hour: hour, minute: minute);
  }

  // ─── Setter ───────────────────────────────────────────────────────────────

  Future<void> setReminderEnabled(bool enabled) async {
    await _box.put(_reminderEnabledKey, enabled);
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    await _box.put(_reminderHourKey, time.hour);
    await _box.put(_reminderMinuteKey, time.minute);
  }

  // ─── Last logged-in UID ─────────────────────────────────────────────────────
  // Dipakai oleh WorkManager callback (background isolate) yang tidak
  // tahu siapa user yang sedang login di isolate utama (UserSessionService
  // bersifat in-memory, tidak ikut ter-share ke isolate terpisah).
  // Disimpan di box global ini supaya callback bisa tahu box notifikasi
  // siapa yang harus ditulis saat pengingat harian fire.

  String? getLastUid() {
    return _box.get(_lastUidKey) as String?;
  }

  Future<void> setLastUid(String uid) async {
    await _box.put(_lastUidKey, uid);
  }
}
