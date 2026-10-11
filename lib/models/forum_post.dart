import 'reference_data.dart';

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
  final owner = int.tryParse('${raw['user_id'] ?? (user as Map?)?['id']}');
  final date = raw['created_at'];
  final item = <String, dynamic>{
    'id': raw['id'],
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
  if (comment) return item;
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
  if (comments != null && comments is! List) throw const FormatException();
  item.addAll({
    'image': referenceImage({'image': raw['image']}),
    'likes_count': count('likes_count'),
    'comments_count': count('comments_count'),
    'is_liked_by_me': liked == true || liked == 1,
    'comments': (comments as List? ?? [])
        .map((c) => parseForumItem(c, comment: true))
        .toList(),
  });
  return item;
}
