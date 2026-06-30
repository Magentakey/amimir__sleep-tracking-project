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

/// Nama task WorkManager untuk pengingat harian.
const String kDailyReminderTask = 'amimir_daily_reminder_task';

/// Callback yang dijalankan WorkManager di background (isolate terpisah).
/// Harus top-level function dan diberi @pragma supaya tidak ter-tree-shake.
///
/// Kenapa WorkManager dan bukan zonedSchedule:
/// flutter_local_notifications pakai AlarmManager → BroadcastReceiver yang
/// Samsung agresif kill sebelum sempat post notification. WorkManager pakai
/// JobScheduler yang Samsung tidak bisa kill sembarangan — dirancang khusus
/// untuk background tasks yang wajib selesai.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kDailyReminderTask) return true;

    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Timezone wajib di-init juga di isolate background
      tz.initializeTimeZones();
      try {
        final String deviceTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTz));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      }

      // Tampilkan notifikasi sekarang (show() bukan zonedSchedule)
      await NotificationService().initialize();
      await NotificationService().showDailyReminderNow();

      // Jadwal ulang untuk besok di jam yang sama
      final int hour = inputData?['hour'] as int? ?? 21;
      final int minute = inputData?['minute'] as int? ?? 0;
      final Duration delay = _delayUntilNext(TimeOfDay(hour: hour, minute: minute));

      await Workmanager().registerOneOffTask(
        kDailyReminderTask,
        kDailyReminderTask,
        initialDelay: delay,
        inputData: {'hour': hour, 'minute': minute},
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );

      debugPrint('[WorkManager] reminder shown, next in ${delay.inHours}h ${delay.inMinutes % 60}m');
    } catch (e) {
      debugPrint('[WorkManager] error: $e');
    }

    return true;
  });
}

/// Hitung durasi sampai jam [time] berikutnya.
Duration _delayUntilNext(TimeOfDay time) {
  final DateTime now = DateTime.now();
  DateTime next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  // Kalau sudah lewat (atau kurang dari 30 detik ke depan), ambil besok
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

  // Init WorkManager dengan callback dispatcher
  await Workmanager().initialize(callbackDispatcher);

  // Jadwal ulang WorkManager reminder kalau sebelumnya aktif
  // (menangani kasus app di-reinstall atau HP restart)
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
