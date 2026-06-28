import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/disease_history.dart';

/// Repository untuk operasi CRUD riwayat penyakit di Firestore.
///
/// Struktur Firestore:
/// ```
/// users/{uid}/disease_history/{docId}
///   id         : String
///   name       : String
///   diagnosed_at : String? (ISO 8601)
///   note       : String
///   created_at : String (ISO 8601)
///   updated_at : String (ISO 8601)
/// ```
///
/// Menggunakan subcollection bukan array agar setiap entry punya dokumen
/// sendiri — lebih fleksibel untuk add/edit/delete individual tanpa
/// baca-tulis seluruh list.
class DiseaseHistoryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DiseaseHistoryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('disease_history');
  }

  // ─── Stream (real-time) ───────────────────────────────────────────────────

  /// Stream riwayat penyakit, diurutkan dari yang paling baru.
  /// Dipakai oleh `diseaseHistoryProvider` (StreamProvider).
  Stream<List<DiseaseHistory>> watchAll() {
    final String? uid = _uid;
    if (uid == null) return const Stream.empty();

    return _collection(uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DiseaseHistory.fromMap(doc.data());
      }).toList();
    });
  }

  // ─── One-shot read ────────────────────────────────────────────────────────

  /// Ambil semua riwayat penyakit sekali (untuk konteks AI analysis).
  Future<List<DiseaseHistory>> getAll() async {
    final String? uid = _uid;
    if (uid == null) return [];

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _collection(uid)
            .orderBy('created_at', descending: false)
            .get();

    return snapshot.docs.map((doc) {
      return DiseaseHistory.fromMap(doc.data());
    }).toList();
  }

  // ─── Write ────────────────────────────────────────────────────────────────

  Future<void> add(DiseaseHistory entry) async {
    final String? uid = _uid;
    if (uid == null) return;

    await _collection(uid).doc(entry.id).set(entry.toMap());
  }

  Future<void> update(DiseaseHistory entry) async {
    final String? uid = _uid;
    if (uid == null) return;

    final DiseaseHistory updated = entry.copyWith(
      updatedAt: DateTime.now(),
    );

    await _collection(uid).doc(updated.id).update(updated.toMap());
  }

  Future<void> delete(String id) async {
    final String? uid = _uid;
    if (uid == null) return;

    await _collection(uid).doc(id).delete();
  }
}
