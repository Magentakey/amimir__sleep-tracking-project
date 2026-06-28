class CaffeineLog {
  final String name;
  final DateTime dateTime;

  const CaffeineLog({required this.name, required this.dateTime});

  CaffeineLog copyWith({String? name, DateTime? dateTime}) {
    return CaffeineLog(
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'dateTime': dateTime.toIso8601String()};
  }

  factory CaffeineLog.fromMap(Map<dynamic, dynamic> map) {
    return CaffeineLog(
      name: map['name'] as String? ?? '',
      dateTime: _parseDateTime(map['dateTime'], fallback: DateTime.now()),
    );
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
}

class MealLog {
  final String photoPath;
  final DateTime dateTime;
  final String note;

  const MealLog({
    required this.photoPath,
    required this.dateTime,
    required this.note,
  });

  MealLog copyWith({String? photoPath, DateTime? dateTime, String? note}) {
    return MealLog(
      photoPath: photoPath ?? this.photoPath,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoPath': photoPath,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
    };
  }

  factory MealLog.fromMap(Map<dynamic, dynamic> map) {
    return MealLog(
      photoPath: map['photoPath'] as String? ?? '',
      dateTime: _parseDateTime(map['dateTime'], fallback: DateTime.now()),
      note: map['note'] as String? ?? '',
    );
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
}

class DailyLog {
  final String id;

  /// Concept:
  /// date = selectedDailyDate.
  ///
  /// This is the date of daily activity, habit, mood, caffeine, meal,
  /// condition, activity, and sleep helpers.
  final DateTime date;

  final String mood;

  final String conditionType;
  final String conditionNote;

  final List<String> sleepHelpers;

  final List<CaffeineLog> caffeineLogs;
  final List<MealLog> mealLogs;

  final String activity;
  final int activityDuration;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyLog({
    required this.id,
    required this.date,
    required this.mood,
    required this.conditionType,
    required this.conditionNote,
    required this.sleepHelpers,
    required this.caffeineLogs,
    required this.mealLogs,
    required this.activity,
    required this.activityDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyLog.empty(DateTime date) {
    final DateTime now = DateTime.now();

    return DailyLog(
      id: now.millisecondsSinceEpoch.toString(),
      date: dateOnly(date),
      mood: '',
      conditionType: 'normal',
      conditionNote: '',
      sleepHelpers: const [],
      caffeineLogs: const [],
      mealLogs: const [],
      activity: '',
      activityDuration: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  DailyLog copyWith({
    String? id,
    DateTime? date,
    String? mood,
    String? conditionType,
    String? conditionNote,
    List<String>? sleepHelpers,
    List<CaffeineLog>? caffeineLogs,
    List<MealLog>? mealLogs,
    String? activity,
    int? activityDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyLog(
      id: id ?? this.id,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      conditionType: conditionType ?? this.conditionType,
      conditionNote: conditionNote ?? this.conditionNote,
      sleepHelpers: sleepHelpers ?? this.sleepHelpers,
      caffeineLogs: caffeineLogs ?? this.caffeineLogs,
      mealLogs: mealLogs ?? this.mealLogs,
      activity: activity ?? this.activity,
      activityDuration: activityDuration ?? this.activityDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DailyLog withNormalizedDate() {
    return copyWith(date: dateOnly(date));
  }

  DateTime get selectedDailyDate {
    return dateOnly(date);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': dateOnly(date).toIso8601String(),
      'mood': mood,
      'conditionType': conditionType,
      'conditionNote': conditionNote,
      'sleepHelpers': sleepHelpers,
      'caffeineLogs': caffeineLogs.map((item) => item.toMap()).toList(),
      'mealLogs': mealLogs.map((item) => item.toMap()).toList(),
      'activity': activity,
      'activityDuration': activityDuration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DailyLog.fromMap(Map<dynamic, dynamic> map) {
    final DateTime now = DateTime.now();

    return DailyLog(
      id: map['id'] as String? ?? now.millisecondsSinceEpoch.toString(),
      date: dateOnly(_parseDateTime(map['date'], fallback: now)),
      mood: map['mood'] as String? ?? '',
      conditionType: map['conditionType'] as String? ?? 'normal',
      conditionNote: map['conditionNote'] as String? ?? '',
      sleepHelpers: _parseStringList(map['sleepHelpers']),
      caffeineLogs: _parseCaffeineLogs(map['caffeineLogs']),
      mealLogs: _parseMealLogs(map['mealLogs']),
      activity: map['activity'] as String? ?? '',
      activityDuration: _parseInt(map['activityDuration']),
      createdAt: _parseDateTime(map['createdAt'], fallback: now),
      updatedAt: _parseDateTime(map['updatedAt'], fallback: now),
    );
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

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    return [];
  }

  static List<CaffeineLog> _parseCaffeineLogs(dynamic value) {
    if (value is List) {
      return value.map((item) {
        return CaffeineLog.fromMap(item as Map<dynamic, dynamic>);
      }).toList();
    }

    return [];
  }

  static List<MealLog> _parseMealLogs(dynamic value) {
    if (value is List) {
      return value.map((item) {
        return MealLog.fromMap(item as Map<dynamic, dynamic>);
      }).toList();
    }

    return [];
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
