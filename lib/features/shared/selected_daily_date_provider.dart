import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/local/local_sleep_service.dart';
import '../sleep/sleep_providers.dart';

/// Tanggal tanpa komponen jam/menit/detik.
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Default tanggal harian yang "masuk akal" untuk dipakai saat belum ada
/// pilihan eksplisit dari user pada sesi ini:
/// - Kalau ada sleep log, pakai tanggal sleep log terakhir (sama seperti
///   logic lama di AnalysisScreen — user biasanya ingin lihat data
///   terakhir yang mereka catat).
/// - Kalau belum ada sleep log sama sekali, pakai hari ini. Khusus jam
///   00:00–03:59 dianggap masih "kemarin" (user mungkin belum tidur/baru
///   mau tidur lewat tengah malam).
DateTime computeSmartDefaultDailyDate(LocalSleepService sleepService) {
  final DateTime? latestSleepDate = sleepService.getLatestSleepLogDate();

  if (latestSleepDate != null) {
    return dateOnly(latestSleepDate);
  }

  final DateTime now = DateTime.now();
  final DateTime today = dateOnly(now);

  if (now.hour >= 0 && now.hour < 4) {
    return today.subtract(const Duration(days: 1));
  }

  return today;
}

/// Tanggal harian yang sedang "aktif"/dipilih user, dipakai bersama oleh
/// Home, Dashboard, dan Analysis supaya pindah-pindah halaman tidak
/// mereset pilihan tanggal balik ke hari ini.
///
/// Sebelum provider ini ada, tiap screen punya state tanggal lokal
/// masing-masing yang dihitung ulang dari nol setiap kali initState()
/// dipanggil — itu sebabnya pilih tanggal 5 Juli di Dashboard, pergi ke
/// Home untuk mencatat tidur, lalu kembali ke Dashboard, malah balik ke
/// tanggal hari ini. Sekarang ketiga screen baca/tulis ke provider yang
/// sama, jadi pilihan tanggal konsisten selama sesi aplikasi berjalan.
final selectedDailyDateProvider = StateProvider<DateTime>((ref) {
  final LocalSleepService sleepService = ref.read(sleepLogRepositoryProvider);
  return computeSmartDefaultDailyDate(sleepService);
});
