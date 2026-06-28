class SleepLog {
  final String id;

  /// Concept:
  /// date = targetDailyDate.
  ///
  /// This is the DailyLog date that this sleep session belongs to.
  /// It is not automatically the wake date.
  ///
  /// Example:
  /// DailyLog.date = 2026-06-10
  /// sleepTime = 2026-06-10 23:30
  /// wakeTime = 2026-06-11 06:30
  /// SleepLog.date = 2026-06-10
  final DateTime date;

  final DateTime sleepTime;
  final DateTime wakeTime;
  final int durationMinutes;
  final int sleepScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SleepLog({
    required this.id,
    required this.date,
    required this.sleepTime,
    required this.wakeTime,
    required this.durationMinutes,
    required this.sleepScore,
    required this.createdAt,
    required this.updatedAt,
  });

  SleepLog copyWith({
    String? id,
    DateTime? date,
    DateTime? sleepTime,
    DateTime? wakeTime,
    int? durationMinutes,
    int? sleepScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SleepLog(
      id: id ?? this.id,
      date: date ?? this.date,
      sleepTime: sleepTime ?? this.sleepTime,
      wakeTime: wakeTime ?? this.wakeTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      sleepScore: sleepScore ?? this.sleepScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  SleepLog withNormalizedDate() {
    return copyWith(date: dateOnly(date));
  }

  DateTime get targetDailyDate {
    return dateOnly(date);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': dateOnly(date).toIso8601String(),
      'sleepTime': sleepTime.toIso8601String(),
      'wakeTime': wakeTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'sleepScore': sleepScore,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SleepLog.fromMap(Map<dynamic, dynamic> map) {
    final DateTime now = DateTime.now();

    return SleepLog(
      id: map['id'] as String? ?? now.millisecondsSinceEpoch.toString(),
      date: dateOnly(_parseDateTime(map['date'], fallback: now)),
      sleepTime: _parseDateTime(map['sleepTime'], fallback: now),
      wakeTime: _parseDateTime(map['wakeTime'], fallback: now),
      durationMinutes: _parseInt(map['durationMinutes']),
      sleepScore: _parseInt(map['sleepScore']),
      createdAt: _parseDateTime(map['createdAt'], fallback: now),
      updatedAt: _parseDateTime(map['updatedAt'], fallback: now),
    );
  }

  String get formattedDuration {
    final int hours = durationMinutes ~/ 60;
    final int minutes = durationMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool isSameDate(DateTime firstDate, DateTime secondDate) {
    final DateTime first = dateOnly(firstDate);
    final DateTime second = dateOnly(secondDate);

    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static bool isDateInRange({
    required DateTime date,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final DateTime target = dateOnly(date);
    final DateTime start = dateOnly(startDate);
    final DateTime end = dateOnly(endDate);

    return !target.isBefore(start) && !target.isAfter(end);
  }

  static DateTime _parseDateTime(dynamic value, {required DateTime fallback}) {
    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}
