import 'package:hive_flutter/hive_flutter.dart';

/// Mengatur Hive box mana yang aktif sesuai user yang sedang login.
///
/// Setiap user (uid) punya box-nya sendiri untuk tiap jenis data lokal,
/// dengan pola nama: '<prefix>_<uid>'. Ini mencegah data sleep log,
/// daily log, analysis cache, dan achievement antar akun saling ketuker
/// kalau dipakai gantian di HP yang sama.
///
/// Box dibuka/ditutup oleh [SessionGate] (lihat
/// core/widgets/session_gate.dart) setiap kali status login Firebase
/// Auth berubah — bukan dibuka sekali di awal seperti sebelumnya, karena
/// sekarang nama box-nya baru bisa ditentukan setelah tahu siapa yang
/// login.
class UserSessionService {
  UserSessionService._();

  static String? _currentUid;

  /// UID user yang box-nya sedang terbuka. Null kalau belum ada user
  /// yang login (atau baru saja logout).
  static String? get currentUid => _currentUid;

  static const String sleepLogsPrefix = 'local_sleep_logs';
  static const String dailyLogsPrefix = 'local_daily_logs';
  static const String analysisCachePrefix = 'local_analysis_cache';
  static const String achievementsPrefix = 'local_achievements';
  static const String appNotificationsPrefix = 'local_app_notifications';

  static const List<String> _allPrefixes = [
    sleepLogsPrefix,
    dailyLogsPrefix,
    analysisCachePrefix,
    achievementsPrefix,
    appNotificationsPrefix,
  ];

  /// Nama box untuk [prefix] milik [uid] tertentu.
  static String boxNameFor(String prefix, String uid) => '${prefix}_$uid';

  /// Buka semua box milik [uid]. Kalau box untuk [uid] yang sama sudah
  /// terbuka, fungsi ini tidak melakukan apa-apa (idempotent) — supaya
  /// aman dipanggil berkali-kali tanpa efek samping.
  static Future<void> openBoxesForUser(String uid) async {
    if (_currentUid == uid) {
      return;
    }

    if (_currentUid != null) {
      await closeCurrentUserBoxes();
    }

    for (final String prefix in _allPrefixes) {
      await Hive.openBox(boxNameFor(prefix, uid));
    }

    _currentUid = uid;
  }

  /// Tutup box milik user yang sedang aktif (dipanggil saat logout).
  /// Data TIDAK dihapus, cuma ditutup — kalau user ini login lagi di HP
  /// yang sama, datanya akan muncul lagi seperti semula.
  static Future<void> closeCurrentUserBoxes() async {
    final String? uid = _currentUid;

    if (uid == null) {
      return;
    }

    for (final String prefix in _allPrefixes) {
      final String boxName = boxNameFor(prefix, uid);

      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    }

    _currentUid = null;
  }

  /// Hapus box lama (dari sebelum fitur per-akun ini ada) yang namanya
  /// masih global/tidak ter-scope ke uid manapun. Dipanggil sekali saat
  /// app start. Aman dipanggil berkali-kali — no-op kalau box lama
  /// sudah tidak ada/sudah pernah dihapus.
  static Future<void> deleteLegacyUnscopedBoxes() async {
    for (final String prefix in _allPrefixes) {
      try {
        await Hive.deleteBoxFromDisk(prefix);
      } catch (_) {
        // Box lama mungkin sudah tidak ada — abaikan.
      }
    }
  }
}
