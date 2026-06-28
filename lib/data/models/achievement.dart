enum AchievementCategory {
  sleep,
  streak,
  dailyLog,
  analysis,
  special,
}

enum AchievementRarity {
  common,
  rare,
  epic,
  legendary,
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final int targetProgress;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.category,
    required this.rarity,
    required this.targetProgress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon_name': iconName,
      'category': category.name,
      'rarity': rarity.name,
      'target_progress': targetProgress,
    };
  }

  factory AchievementDefinition.fromMap(Map<String, dynamic> map) {
    return AchievementDefinition(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      iconName: map['icon_name']?.toString() ?? 'emoji_events',
      category: _parseCategory(map['category']?.toString()),
      rarity: _parseRarity(map['rarity']?.toString()),
      targetProgress: _parseInt(map['target_progress']),
    );
  }

  static AchievementCategory _parseCategory(String? value) {
    for (final AchievementCategory category in AchievementCategory.values) {
      if (category.name == value) {
        return category;
      }
    }

    return AchievementCategory.sleep;
  }

  static AchievementRarity _parseRarity(String? value) {
    for (final AchievementRarity rarity in AchievementRarity.values) {
      if (rarity.name == value) {
        return rarity;
      }
    }

    return AchievementRarity.common;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AchievementProgress {
  final AchievementDefinition definition;
  final int currentProgress;
  final DateTime? unlockedAt;
  final bool isEquipped;

  const AchievementProgress({
    required this.definition,
    required this.currentProgress,
    required this.unlockedAt,
    required this.isEquipped,
  });

  String get id {
    return definition.id;
  }

  bool get isUnlocked {
    return unlockedAt != null || currentProgress >= definition.targetProgress;
  }

  int get targetProgress {
    return definition.targetProgress;
  }

  double get progressPercent {
    if (definition.targetProgress <= 0) {
      return 0;
    }

    final double progress = currentProgress / definition.targetProgress;

    if (progress < 0) {
      return 0;
    }

    if (progress > 1) {
      return 1;
    }

    return progress;
  }

  String get progressText {
    return '$currentProgress/${definition.targetProgress}';
  }

  Map<String, dynamic> toMap() {
    return {
      'definition': definition.toMap(),
      'current_progress': currentProgress,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'is_equipped': isEquipped,
    };
  }

  factory AchievementProgress.fromMap(Map<String, dynamic> map) {
    final dynamic definitionMap = map['definition'];

    return AchievementProgress(
      definition: definitionMap is Map
          ? AchievementDefinition.fromMap(
              Map<String, dynamic>.from(definitionMap),
            )
          : AchievementDefinition.fromMap(const {}),
      currentProgress: _parseInt(map['current_progress']),
      unlockedAt: _parseDateTime(map['unlocked_at']),
      isEquipped: map['is_equipped'] == true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}