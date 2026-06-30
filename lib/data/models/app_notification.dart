/// Jenis notifikasi in-app yang ditampilkan di dropdown lonceng.
enum AppNotificationType { achievement, dailyReminder }

/// Satu entry notifikasi in-app (bukan notifikasi OS) yang muncul di
/// dropdown lonceng pada top bar.
///
/// Sumbernya cuma dua untuk saat ini:
/// - [AppNotificationType.achievement] — saat achievement baru ter-unlock
/// - [AppNotificationType.dailyReminder] — saat pengingat harian fire
class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  factory AppNotification.fromMap(Map<dynamic, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      type: AppNotificationType.values.firstWhere(
        (t) => t.name == map['type']?.toString(),
        orElse: () => AppNotificationType.achievement,
      ),
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isRead: map['is_read'] as bool? ?? false,
    );
  }
}
