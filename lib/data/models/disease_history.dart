/// Model untuk satu entry riwayat penyakit user.
///
/// Field [diagnosedAt] dan [note] bersifat opsional — user bisa hanya
/// mengisi nama penyakit tanpa detail tambahan (hybrid approach).
class DiseaseHistory {
  final String id;
  final String name;
  final DateTime? diagnosedAt;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiseaseHistory({
    required this.id,
    required this.name,
    this.diagnosedAt,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  DiseaseHistory copyWith({
    String? id,
    String? name,
    DateTime? diagnosedAt,
    bool clearDiagnosedAt = false,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiseaseHistory(
      id: id ?? this.id,
      name: name ?? this.name,
      diagnosedAt: clearDiagnosedAt ? null : (diagnosedAt ?? this.diagnosedAt),
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'diagnosed_at': diagnosedAt?.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DiseaseHistory.fromMap(Map<String, dynamic> map) {
    DateTime? parseDiagnosedAt() {
      final dynamic raw = map['diagnosed_at'];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return DiseaseHistory(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      diagnosedAt: parseDiagnosedAt(),
      note: map['note']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
