import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firebaseFirestore;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firebaseFirestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firebaseFirestore = firebaseFirestore ?? FirebaseFirestore.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final UserCredential userCredential =
        await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final User? user = userCredential.user;

    if (user != null) {
      await _saveUserProfile(user: user);
    }

    return userCredential;
  }

  Future<UserCredential> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  Future<void> _saveUserProfile({
    required User user,
  }) async {
    final String email = user.email ?? '';
    final String username = _getUsernameFromEmail(email);

    await _firebaseFirestore.collection('users').doc(user.uid).set({
      'email': email,
      'username': username,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'profile': {
        'display_name': username,
        'photo_url': '',
        'sleep_goal': 8,
        'equipped_achievement_id': null,
      },
    });
  }

  Future<String?> fetchEquippedAchievementId(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firebaseFirestore.collection('users').doc(uid).get();

      if (!doc.exists) return null;

      final Map<String, dynamic>? data = doc.data();
      if (data == null) return null;

      final dynamic profile = data['profile'];
      if (profile is! Map) return null;

      final dynamic id = profile['equipped_achievement_id'];
      if (id == null) return null;

      final String idStr = id.toString();
      return idStr.isEmpty ? null : idStr;
    } catch (_) {
      return null;
    }
  }

  String _getUsernameFromEmail(String email) {
    if (email.isEmpty || !email.contains('@')) {
      return 'user';
    }

    return email.split('@').first;
  }
}