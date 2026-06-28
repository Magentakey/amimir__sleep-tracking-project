import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/disease_history.dart';
import '../../data/repositories/disease_history_repository.dart';
import '../../data/repositories/profile_repository.dart';

// ─── Repository providers ─────────────────────────────────────────────────────

final diseaseHistoryRepositoryProvider =
    Provider<DiseaseHistoryRepository>((ref) {
  return DiseaseHistoryRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

// ─── Stream provider ─────────────────────────────────────────────────────────

/// Stream real-time riwayat penyakit dari Firestore.
///
/// Dipilih [StreamProvider] bukan FutureProvider/cache karena:
/// - Data disease history ada di Firestore (cloud), bukan Hive (local)
/// - User mungkin add/edit/delete di DiseaseHistoryScreen lalu langsung
///   buka AnalysisScreen — perlu data selalu up-to-date tanpa manual
///   invalidation
/// - Tidak ada biaya Firestore tambahan yang signifikan karena data ini
///   kecil dan jarang berubah
///
/// Listener otomatis tutup saat provider di-dispose (keluar dari screen).
final diseaseHistoryProvider =
    StreamProvider.autoDispose<List<DiseaseHistory>>((ref) {
  final DiseaseHistoryRepository repo = ref.watch(
    diseaseHistoryRepositoryProvider,
  );
  return repo.watchAll();
});
