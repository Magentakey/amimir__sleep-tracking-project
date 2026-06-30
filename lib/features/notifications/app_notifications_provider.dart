import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_app_notification_service.dart';
import '../../data/models/app_notification.dart';

final appNotificationServiceProvider = Provider<LocalAppNotificationService>((
  ref,
) {
  return LocalAppNotificationService();
});

/// Daftar notifikasi in-app (achievement + pengingat harian), dipakai
/// oleh dropdown lonceng di top bar.
///
/// Sync [Notifier] (bukan Async) karena baca Hive itu instan, tidak ada
/// I/O network. Dipanggil ulang (`refresh()`) setiap kali ada notifikasi
/// baru ditambahkan — lihat pemanggilnya di achievement_providers.dart
/// dan session_gate.dart (untuk notifikasi reminder yang masuk lewat
/// WorkManager saat app tertutup).
final appNotificationsProvider =
    NotifierProvider<AppNotificationsNotifier, List<AppNotification>>(
      AppNotificationsNotifier.new,
    );

class AppNotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    final LocalAppNotificationService service = ref.watch(
      appNotificationServiceProvider,
    );
    return service.getAll();
  }

  /// Muat ulang dari Hive — dipanggil setelah ada notifikasi baru masuk.
  void refresh() {
    final LocalAppNotificationService service = ref.read(
      appNotificationServiceProvider,
    );
    state = service.getAll();
  }

  /// Tandai semua sudah dibaca — dipanggil saat user membuka dropdown
  /// lonceng, supaya badge counter langsung hilang.
  Future<void> markAllRead() async {
    final LocalAppNotificationService service = ref.read(
      appNotificationServiceProvider,
    );
    await service.markAllRead();
    state = service.getAll();
  }
}

/// Jumlah notifikasi yang belum dibaca — dipakai untuk badge counter
/// di ikon lonceng.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final List<AppNotification> notifications = ref.watch(
    appNotificationsProvider,
  );
  return notifications.where((n) => !n.isRead).length;
});
