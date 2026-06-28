import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/user_session_service.dart';
import 'core/widgets/session_gate.dart';
import 'data/local/local_settings_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();

  // Hapus box lama tanpa UID (data testing lama — lihat UserSessionService)
  await UserSessionService.deleteLegacyUnscopedBoxes();

  // Box global (tidak per-user) untuk preferensi pengaturan app
  await Hive.openBox(LocalSettingsService.settingsBoxName);

  // ── Timezone ──────────────────────────────────────────────────────────────
  // Langkah 1: muat seluruh database timezone dunia
  tz.initializeTimeZones();

  // Langkah 2: baca timezone aktif dari device (misal "Asia/Jakarta")
  // dan set sebagai tz.local supaya scheduleDailyLogReminder memakai
  // jam lokal device — bukan UTC.
  // Tanpa ini, notifikasi jam 21:00 WIB dijadwalkan jam 21:00 UTC = 04:00 WIB.
  try {
    final String deviceTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimezone));
  } catch (_) {
    // Fallback ke WIB kalau gagal baca timezone device
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
  }

  // ── Notifikasi OS ─────────────────────────────────────────────────────────
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  // Jadwal ulang pengingat harian kalau sebelumnya aktif.
  // Menangani kasus app di-reinstall (semua jadwal notif terhapus oleh OS).
  final LocalSettingsService settings = LocalSettingsService();
  if (settings.getReminderEnabled()) {
    await NotificationService().scheduleDailyLogReminder(
      time: settings.getReminderTime(),
    );
  }

  // Box per-akun (sleep, daily, analysis, achievement) dibuka oleh
  // SessionGate setelah tahu siapa yang login — bukan di sini.
  runApp(ProviderScope(child: SessionGate(child: const AmimirApp())));
}
