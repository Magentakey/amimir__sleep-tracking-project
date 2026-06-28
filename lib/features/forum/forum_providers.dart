import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// ============================================================
// Models
// ============================================================

class ForumBadge {
  final String id;
  final String title;
  final String iconName;
  final String rarity;

  const ForumBadge({
    required this.id,
    required this.title,
    required this.iconName,
    required this.rarity,
  });

  factory ForumBadge.fromMap(Map<String, dynamic> map) {
    return ForumBadge(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      iconName: map['icon_name'] as String? ?? '',
      rarity: map['rarity'] as String? ?? 'common',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'icon_name': iconName,
    'rarity': rarity,
  };
}

class ForumPost {
  final String id;
  final String authorUid;
  final String authorUsername;
  final ForumBadge? authorBadge;
  final String content;
  final String category;
  final DateTime createdAt;
  final List<String> likes;
  final List<String> dislikes;

  const ForumPost({
    required this.id,
    required this.authorUid,
    required this.authorUsername,
    this.authorBadge,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.likes,
    required this.dislikes,
  });

  factory ForumPost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Defensive badge parsing — field must be a non-empty Map to be valid
    ForumBadge? badge;
    final rawBadge = data['author_badge'];
    if (rawBadge is Map<String, dynamic> && rawBadge.isNotEmpty) {
      badge = ForumBadge.fromMap(rawBadge);
    }

    return ForumPost(
      id: doc.id,
      authorUid: data['author_uid'] as String? ?? '',
      authorUsername: data['author_username'] as String? ?? 'Unknown',
      authorBadge: badge,
      content: data['content'] as String? ?? '',
      category: data['category'] as String? ?? 'Umum',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] as List? ?? []),
      dislikes: List<String>.from(data['dislikes'] as List? ?? []),
    );
  }
}

// ============================================================
// Sort & Filter State
// ============================================================

enum ForumSort { newest, popular }

class ForumFilter {
  final String? category;
  final ForumSort sort;

  const ForumFilter({this.category, this.sort = ForumSort.newest});

  ForumFilter copyWith({
    String? category,
    ForumSort? sort,
    bool clearCategory = false,
  }) {
    return ForumFilter(
      category: clearCategory ? null : (category ?? this.category),
      sort: sort ?? this.sort,
    );
  }
}

final forumFilterProvider = StateProvider<ForumFilter>(
  (ref) => const ForumFilter(),
);

// ============================================================
// Forum Posts Stream
// ============================================================

final forumPostsProvider = StreamProvider.autoDispose<List<ForumPost>>((ref) {
  final filter = ref.watch(forumFilterProvider);

  // No orderBy on filtered queries — Firestore requires a composite index
  // for where() + orderBy() combinations. Sort entirely client-side instead.
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
    'forum_posts',
  );

  if (filter.category != null) {
    query = query.where('category', isEqualTo: filter.category);
  }

  return query.snapshots().map((snap) {
    final posts = snap.docs.map(ForumPost.fromDoc).toList();

    if (filter.sort == ForumSort.popular) {
      posts.sort((a, b) => b.likes.length.compareTo(a.likes.length));
    } else {
      // Default: newest first
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return posts;
  });
});

// ============================================================
// Actions
// ============================================================

final forumServiceProvider = Provider<ForumService>((ref) => ForumService());

class ForumService {
  final _col = FirebaseFirestore.instance.collection('forum_posts');
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<void> createPost({
    required String content,
    required String category,
    required String username,
    ForumBadge? badge,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _col.add({
      'author_uid': uid,
      'author_username': username,
      'author_badge': badge?.toMap(),
      'content': content,
      'category': category,
      'created_at': FieldValue.serverTimestamp(),
      'likes': [],
      'dislikes': [],
    });
  }

  Future<void> toggleLike(ForumPost post) async {
    final uid = _uid;
    if (uid == null) return;

    final ref = _col.doc(post.id);
    final hasLiked = post.likes.contains(uid);
    final hasDisliked = post.dislikes.contains(uid);

    final batch = FirebaseFirestore.instance.batch();

    if (hasLiked) {
      batch.update(ref, {
        'likes': FieldValue.arrayRemove([uid]),
      });
    } else {
      batch.update(ref, {
        'likes': FieldValue.arrayUnion([uid]),
      });
      if (hasDisliked) {
        batch.update(ref, {
          'dislikes': FieldValue.arrayRemove([uid]),
        });
      }
    }

    await batch.commit();
  }

  Future<void> toggleDislike(ForumPost post) async {
    final uid = _uid;
    if (uid == null) return;

    final ref = _col.doc(post.id);
    final hasDisliked = post.dislikes.contains(uid);
    final hasLiked = post.likes.contains(uid);

    final batch = FirebaseFirestore.instance.batch();

    if (hasDisliked) {
      batch.update(ref, {
        'dislikes': FieldValue.arrayRemove([uid]),
      });
    } else {
      batch.update(ref, {
        'dislikes': FieldValue.arrayUnion([uid]),
      });
      if (hasLiked) {
        batch.update(ref, {
          'likes': FieldValue.arrayRemove([uid]),
        });
      }
    }

    await batch.commit();
  }

  Future<void> deletePost(String postId) async {
    await _col.doc(postId).delete();
  }
}
