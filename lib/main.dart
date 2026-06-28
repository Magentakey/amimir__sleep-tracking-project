import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

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
  // Wajib untuk fitur Daily Log Reminder (zonedSchedule di NotificationService)
  tz.initializeTimeZones();

  // ── Notifikasi OS ─────────────────────────────────────────────────────────
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  // Jadwal ulang pengingat harian kalau sebelumnya aktif.
  // Ini menangani kasus app di-reinstall (semua jadwal notif terhapus oleh OS).
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
