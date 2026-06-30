import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/user_session_service.dart';
import '../models/app_notification.dart';

/// Riwayat notifikasi in-app (achievement unlock + pengingat harian),
/// ditampilkan di dropdown lonceng pada top bar. Berbeda dengan
/// notifikasi OS (lihat NotificationService) — ini murni di dalam app.
///
/// Box-nya per-akun (UID), sama seperti sleep log/daily log/achievement,
/// supaya riwayat notifikasi tidak ketuker antar akun di HP yang sama.
class LocalAppNotificationService {
  static String get boxName {
    final String? uid = UserSessionService.currentUid;

    if (uid == null) {
      throw StateError(
        'Tidak ada user yang login — box notifikasi belum bisa diakses.',
      );
    }

    return UserSessionService.boxNameFor(
      UserSessionService.appNotificationsPrefix,
      uid,
    );
  }

  /// Box untuk [uid] tertentu — dipakai khusus oleh WorkManager callback
  /// (background isolate) yang tidak melalui [UserSessionService] biasa
  /// karena tidak tahu siapa user yang sedang login di isolate utama.
  static String boxNameForUid(String uid) {
    return UserSessionService.boxNameFor(
      UserSessionService.appNotificationsPrefix,
      uid,
    );
  }

  /// Batas jumlah notifikasi yang disimpan — biar box tidak membengkak
  /// tanpa batas. Notifikasi terlama otomatis dibuang saat melebihi ini.
  static const int _maxStored = 50;

  Box get _box => Hive.box(boxName);

  List<AppNotification> getAll() {
    final List<AppNotification> list = _box.values
        .map((raw) => AppNotification.fromMap(raw as Map<dynamic, dynamic>))
        .toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int getUnreadCount() {
    return _box.values
        .map((raw) => AppNotification.fromMap(raw as Map<dynamic, dynamic>))
        .where((n) => !n.isRead)
        .length;
  }

  Future<void> add(AppNotification notification) async {
    await _box.put(notification.id, notification.toMap());
    await _enforceMaxStored();
  }

  Future<void> markAllRead() async {
    final List<AppNotification> all = getAll();

    for (final AppNotification n in all) {
      if (!n.isRead) {
        await _box.put(n.id, n.copyWith(isRead: true).toMap());
      }
    }
  }

  Future<void> _enforceMaxStored() async {
    final List<AppNotification> all = getAll();

    if (all.length <= _maxStored) return;

    final List<AppNotification> toRemove = all.sublist(_maxStored);

    for (final AppNotification n in toRemove) {
      await _box.delete(n.id);
    }
  }
}
