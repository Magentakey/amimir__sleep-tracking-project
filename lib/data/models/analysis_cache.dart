class AnalysisCache {
  final String id;
  final String periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String summary;
  final String insight;
  final String recommendation;
  final DateTime createdAt;

  const AnalysisCache({
    required this.id,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    this.summary = '',
    required this.insight,
    required this.recommendation,
    required this.createdAt,
  });

  AnalysisCache copyWith({
    String? id,
    String? periodType,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? summary,
    String? insight,
    String? recommendation,
    DateTime? createdAt,
  }) {
    return AnalysisCache(
      id: id ?? this.id,
      periodType: periodType ?? this.periodType,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      summary: summary ?? this.summary,
      insight: insight ?? this.insight,
      recommendation: recommendation ?? this.recommendation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'periodType': periodType,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'summary': summary,
      'insight': insight,
      'recommendation': recommendation,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AnalysisCache.fromMap(Map<dynamic, dynamic> map) {
    return AnalysisCache(
      id: map['id'] as String,
      periodType: map['periodType'] as String,
      periodStart: DateTime.parse(map['periodStart'] as String),
      periodEnd: DateTime.parse(map['periodEnd'] as String),
      summary: map['summary'] as String? ?? '',
      insight: map['insight'] as String? ?? '',
      recommendation: map['recommendation'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
