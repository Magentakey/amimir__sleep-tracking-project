import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/user_session_service.dart';
import 'core/widgets/session_gate.dart';
import 'data/local/local_settings_service.dart';
import 'firebase_options.dart';

/// Nama unik task WorkManager untuk pengingat harian.
const String kDailyReminderTask = 'amimir_daily_reminder_task';

/// Callback yang dijalankan WorkManager di background (isolate terpisah).
///
/// Kenapa WorkManager dan bukan AlarmManager (zonedSchedule):
/// Samsung (One UI) agresif mematikan BroadcastReceiver dari AlarmManager
/// sebelum sempat menampilkan notifikasi, meski alarm-nya sendiri terbukti
/// fired tepat waktu (verified via `adb shell dumpsys alarm`). WorkManager
/// memakai JobScheduler yang tidak diperlakukan sama oleh Samsung — jadi
/// notifikasi benar-benar muncul.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kDailyReminderTask) return true;

    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Timezone wajib di-init ulang karena ini isolate terpisah dari main()
      tz.initializeTimeZones();
      try {
        final String deviceTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTz));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      }

      await NotificationService().initialize();
      await NotificationService().showDailyReminderNow();

      // Jadwal ulang untuk besok di jam yang sama — WorkManager task ini
      // bersifat one-off, jadi perlu re-register setiap kali fire supaya
      // jadi pengingat harian yang berulang.
      final int hour = inputData?['hour'] as int? ?? 21;
      final int minute = inputData?['minute'] as int? ?? 0;
      final Duration delay =
          _delayUntilNext(TimeOfDay(hour: hour, minute: minute));

      await Workmanager().registerOneOffTask(
        kDailyReminderTask,
        kDailyReminderTask,
        initialDelay: delay,
        inputData: {'hour': hour, 'minute': minute},
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    } catch (_) {
      // Gagal diam-diam — tidak ada UI untuk menampilkan error di background
    }

    return true;
  });
}

/// Hitung durasi sampai jam [time] berikutnya (hari ini kalau belum lewat,
/// besok kalau sudah lewat).
Duration _delayUntilNext(TimeOfDay time) {
  final DateTime now = DateTime.now();
  DateTime next =
      DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (next.difference(now).inSeconds < 30) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();
  await UserSessionService.deleteLegacyUnscopedBoxes();
  await Hive.openBox(LocalSettingsService.settingsBoxName);

  // ── Timezone ──────────────────────────────────────────────────────────────
  tz.initializeTimeZones();
  try {
    final String deviceTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimezone));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
  }

  // ── Notifikasi & WorkManager ───────────────────────────────────────────────
  await NotificationService().initialize();
  await NotificationService().requestPermissions();
  await Workmanager().initialize(callbackDispatcher);

  // Jadwal ulang reminder kalau sebelumnya aktif (menangani app reinstall
  // atau HP restart, di mana semua task WorkManager terhapus oleh OS)
  final LocalSettingsService settings = LocalSettingsService();
  if (settings.getReminderEnabled()) {
    final TimeOfDay time = settings.getReminderTime();
    final Duration delay = _delayUntilNext(time);
    await Workmanager().registerOneOffTask(
      kDailyReminderTask,
      kDailyReminderTask,
      initialDelay: delay,
      inputData: {'hour': time.hour, 'minute': time.minute},
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }

  runApp(ProviderScope(child: SessionGate(child: const AmimirApp())));
}
