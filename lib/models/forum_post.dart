import 'reference_data.dart';
import 'profile_summary.dart';

/// Only presentation fields are retained; contact details are not copied.
Map<String, dynamic> parseForumItem(Object? raw, {bool comment = false}) {
  if (raw is! Map ||
      raw['id'] is! int ||
      (raw['id'] as int) <= 0 ||
      raw['content'] is! String) {
    throw const FormatException();
  }
  final user = raw['user'];
  if (user != null && user is! Map) throw const FormatException();
  final identity = raw['user_id'];
  final owner = identity is int
      ? identity
      : identity is String && RegExp(r'^[0-9]+$').hasMatch(identity)
      ? int.tryParse(identity)
      : null;
  if ((identity != null && identity is! int && identity is! String) ||
      (comment && identity is! String)) {
    throw const FormatException();
  }
  final date = raw['created_at'];
  final item = <String, dynamic>{
    'id': raw['id'],
    'profile': profileRelation(user, identity),
    'user_id': owner != null && owner > 0 ? owner : null,
    'content': raw['content'],
    'author_name': user is Map && user['name'] is String
        ? user['name']
        : raw['author_name'] is String
        ? raw['author_name']
        : 'Pengguna',
    'created_at': date is String && DateTime.tryParse(date) != null
        ? date
        : null,
    'avatar': user is Map
        ? referenceImage({'image': user['foto_profil']})
        : null,
  };
  if (comment) {
    final parent = raw['parent_id'];
    final post = raw['community_post_id'];
    if (!raw.containsKey('user') ||
        post is! int ||
        post <= 0 ||
        !raw.containsKey('parent_id') ||
        (parent != null &&
            (parent is! int || parent <= 0 || parent == raw['id'])) ||
        raw['likes_count'] is! int ||
        raw['likes_count'] < 0 ||
        raw['replies_count'] is! int ||
        raw['replies_count'] < 0 ||
        (parent != null && raw['replies_count'] != 0) ||
        raw['is_liked_by_me'] is! bool) {
      throw const FormatException();
    }
    for (final key in ['created_at', 'updated_at']) {
      final value = raw[key];
      if (!raw.containsKey(key) ||
          (value != null &&
              (value is! String || DateTime.tryParse(value) == null))) {
        throw const FormatException();
      }
      item[key] = value;
    }
    if (user is Map &&
        (user['id'] is! int ||
            user['id'] != owner ||
            user['name'] is! String ||
            (user['foto_profil'] != null && user['foto_profil'] is! String))) {
      throw const FormatException();
    }
    item.addAll({
      'community_post_id': post,
      'parent_id': parent,
      'likes_count': raw['likes_count'],
      'replies_count': raw['replies_count'],
      'is_liked_by_me': raw['is_liked_by_me'],
    });
    return item;
  }
  int count(String key) {
    final value = int.tryParse('${raw[key]}');
    if (value == null || value < 0) throw const FormatException();
    return value;
  }

  final liked = raw['is_liked_by_me'];
  if (liked != true && liked != false && liked != 0 && liked != 1) {
    throw const FormatException();
  }
  final comments = raw['comments'];
  if (comments is! List) throw const FormatException();
  item.addAll({
    'image': referenceImage({'image': raw['image']}),
    'likes_count': count('likes_count'),
    'comments_count': count('comments_count'),
    'root_comments_count': count('root_comments_count'),
    'is_liked_by_me': liked == true || liked == 1,
    'comments': comments.map((c) => parseForumItem(c, comment: true)).toList(),
  });
  return item;
}

class ForumPage {
  const ForumPage(this.items, this.currentPage, this.lastPage, this.total);
  final List<Map<String, dynamic>> items;
  final int currentPage, lastPage, total;
  bool get hasMore => currentPage < lastPage;

  factory ForumPage.parse(
    Object? rows,
    Object? meta,
    int requested, {
    bool comments = false,
    int? postId,
    int? parentId,
  }) {
    if (rows is! List ||
        meta is! Map ||
        meta['current_page'] is! int ||
        meta['current_page'] != requested ||
        meta['per_page'] is! int ||
        meta['per_page'] < 1 ||
        meta['per_page'] > 50 ||
        meta['last_page'] is! int ||
        meta['last_page'] < 1 ||
        meta['total'] is! int ||
        meta['total'] < 0 ||
        rows.length > meta['per_page']) {
      throw const FormatException();
    }
    final items = rows
        .map((r) => parseForumItem(r, comment: comments))
        .toList();
    if (comments &&
        items.any(
          (c) => c['community_post_id'] != postId || c['parent_id'] != parentId,
        )) {
      throw const FormatException();
    }
    if (!comments &&
        items.any(
          (p) =>
              (p['comments'] as List).length > 3 ||
              (p['comments'] as List).any(
                (c) =>
                    c['parent_id'] != null || c['community_post_id'] != p['id'],
              ) ||
              p['root_comments_count'] > p['comments_count'],
        )) {
      throw const FormatException();
    }
    return ForumPage(items, requested, meta['last_page'], meta['total']);
  }
}
