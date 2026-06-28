import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository untuk update data profil user.
///
/// Foto profil tidak didukung karena Firebase Storage membutuhkan
/// upgrade ke Blaze plan. Avatar menggunakan initial nama (huruf pertama).
///
/// Semua write memakai [SetOptions(merge: true)] — lebih aman dari
/// [.update()] karena tidak crash kalau field belum ada di dokumen.
class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final String? uid = _uid;
    if (uid == null) throw StateError('Tidak ada user yang login.');
    return _firestore.collection('users').doc(uid);
  }

  // ─── Update display name ──────────────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _userDoc.set({
      'profile': {'display_name': trimmed},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _auth.currentUser?.updateDisplayName(trimmed);
  }

  // ─── Update sleep goal ────────────────────────────────────────────────────

  Future<void> updateSleepGoal(int hours) async {
    final int clamped = hours.clamp(1, 24);

    await _userDoc.set({
      'profile': {'sleep_goal': clamped},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
