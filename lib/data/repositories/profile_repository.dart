import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Repository untuk update data profil user.
///
/// Tiga operasi yang tersedia:
/// - [updateDisplayName] — ubah nama tampilan di Firestore
/// - [updateSleepGoal]  — ubah target jam tidur di Firestore
/// - [updatePhotoUrl]   — upload foto ke Firebase Storage, simpan URL ke Firestore
///
/// Semua perubahan disimpan di `users/{uid}.profile.*` supaya sinkron
/// antar device saat user login di HP lain.
class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final String? uid = _uid;
    assert(uid != null, 'ProfileRepository dipanggil tanpa user yang login.');
    return _firestore.collection('users').doc(uid);
  }

  // ─── Update display name ──────────────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _userDoc.update({
      'profile.display_name': trimmed,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update juga di FirebaseAuth supaya konsisten
    await _auth.currentUser?.updateDisplayName(trimmed);
  }

  // ─── Update sleep goal ────────────────────────────────────────────────────

  Future<void> updateSleepGoal(int hours) async {
    assert(hours >= 1 && hours <= 24, 'Sleep goal harus antara 1–24 jam.');

    await _userDoc.update({
      'profile.sleep_goal': hours,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ─── Upload & update profile photo ───────────────────────────────────────

  /// Upload file foto [imageFile] ke Firebase Storage, lalu simpan URL-nya
  /// ke Firestore dan FirebaseAuth.
  ///
  /// Path Storage: `profile_photos/{uid}/avatar.jpg`
  /// Selalu menimpa file lama (nama file tetap), jadi tidak ada akumulasi
  /// file lama di Storage.
  Future<String> updateProfilePhoto(File imageFile) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('Tidak ada user yang login.');

    final Reference ref = _storage
        .ref()
        .child('profile_photos')
        .child(uid)
        .child('avatar.jpg');

    final UploadTask uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    // Simpan URL ke Firestore
    await _userDoc.update({
      'profile.photo_url': downloadUrl,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update juga di FirebaseAuth
    await _auth.currentUser?.updatePhotoURL(downloadUrl);

    return downloadUrl;
  }

  // ─── Fetch profile ────────────────────────────────────────────────────────

  /// Ambil data profil terkini dari Firestore (one-shot).
  Future<Map<String, dynamic>?> fetchProfile() async {
    final String? uid = _uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }
}
