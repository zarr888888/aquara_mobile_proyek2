import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/forum_post.dart';
import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// Forum facade shares AuthService's client and session, never another transport.
mixin ForumApi on AuthService {
  final _forumReads = <String, Future<ApiResult<List<dynamic>>>>{};

  Future<ApiResult<ForumPage>> fetchForumPage({
    required SessionSnapshot expectedSession,
    bool mine = false,
    int page = 1,
    int perPage = 20,
    int? postId,
    int? parentId,
  }) async {
    if (page < 1 || perPage < 1 || perPage > 50) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.validation,
          message: 'Halaman tidak valid.',
        ),
      );
    }
    final comments = postId != null;
    final result = await authClient.request(
      'GET',
      !comments
          ? 'forum'
          : parentId == null
          ? 'forum/$postId/comments'
          : 'forum/comment/$parentId/replies',
      query: {
        'page': '$page',
        'per_page': '$perPage',
        if (!comments && mine) 'mine': '1',
      },
      expectedSession: expectedSession,
    );
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    try {
      final body = result.data;
      if (result.statusCode != 200 || body is! Map || body['success'] != true) {
        throw const FormatException();
      }
      final meta = comments ? body['data'] : body['meta'];
      return ApiResult.success(
        data: ForumPage.parse(
          comments && meta is Map ? meta['data'] : body['data'],
          meta,
          page,
          comments: comments,
          postId: postId,
          parentId: parentId,
        ),
        statusCode: 200,
      );
    } on FormatException {
      return ApiResult.failure(_badForum());
    }
  }

  Future<ApiResult<List<dynamic>>> fetchForumPosts({
    required SessionSnapshot expectedSession,
    bool mine = false,
  }) {
    final key = '${expectedSession.revision}:$mine';
    return _forumReads.putIfAbsent(key, () async {
      try {
        final result = await fetchForumPage(
          expectedSession: expectedSession,
          mine: mine,
        );
        if (!result.isSuccess) {
          return ApiResult.failure(
            result.failure!,
            statusCode: result.statusCode,
          );
        }
        return ApiResult.success(data: result.data!.items, statusCode: 200);
      } finally {
        _forumReads.remove(key);
      }
    });
  }

  ApiFailure _badForum() => ApiFailure(
    kind: ApiErrorKind.invalidResponse,
    message:
        'Respons Forum tidak valid. Periksa ulang daftar sebelum mengulang aksi.',
  );

  Future<ApiResult<Object?>> postForum(
    String content,
    File? image, {
    required SessionSnapshot expectedSession,
  }) => _writeForum('forum', content, image, expectedSession, update: false);

  Future<ApiResult<Object?>> updateForumPost(
    int id,
    String content,
    File? image, {
    required SessionSnapshot expectedSession,
  }) => _writeForum(
    'forum/$id/update',
    content,
    image,
    expectedSession,
    update: true,
  );

  Future<ApiResult<Object?>> _writeForum(
    String path,
    String content,
    File? image,
    SessionSnapshot owner, {
    required bool update,
  }) async {
    if (content.trim().isEmpty || (!update && content.runes.length > 5000)) {
      return _validation(
        'Isi posting wajib diisi${update ? '' : ', maksimal 5000 karakter'}.',
      );
    }
    ApiResult<Object?> result;
    if (image == null) {
      result = await authClient.request(
        'POST',
        path,
        body: {'content': content},
        expectedSession: owner,
      );
    } else {
      try {
        final limit = (update ? 10240 : 5120) * 1024;
        if (await image.length() > limit ||
            !RegExp(
              r'\.(jpe?g|png|gif|webp|bmp)$',
              caseSensitive: false,
            ).hasMatch(image.path)) {
          return _validation(
            'Pilih gambar maksimal ${update ? 10240 : 5120} KB.',
          );
        }
        final file = await http.MultipartFile.fromPath('image', image.path);
        result = await authClient.multipart(
          path,
          fields: {'content': content},
          files: [file],
          expectedSession: owner,
        );
      } catch (_) {
        return _validation('Gambar tidak dapat dibaca. Pilih kembali gambar.');
      }
    }
    return _forumSuccess(result);
  }

  ApiResult<Object?> _validation(String message) => ApiResult.failure(
    ApiFailure(kind: ApiErrorKind.validation, message: message),
  );

  ApiResult<Object?> _forumSuccess(
    ApiResult<Object?> result, {
    bool toggle = false,
  }) {
    if (!result.isSuccess) return result;
    final body = result.data;
    if (result.statusCode != 200 ||
        body is! Map ||
        body['success'] != true ||
        (toggle && body['status'] != 'liked' && body['status'] != 'unliked')) {
      return ApiResult.failure(_badForum(), statusCode: result.statusCode);
    }
    return ApiResult.success(
      data: toggle ? body['status'] : null,
      statusCode: 200,
    );
  }

  Future<ApiResult<Object?>> toggleLikePost(
    int id, {
    required SessionSnapshot expectedSession,
  }) async => _forumSuccess(
    await authClient.request(
      'POST',
      'forum/$id/toggle-like',
      expectedSession: expectedSession,
    ),
    toggle: true,
  );
  Future<ApiResult<Object?>> deleteForumPost(
    int id, {
    required SessionSnapshot expectedSession,
  }) async => _forumSuccess(
    await authClient.request(
      'DELETE',
      'forum/$id',
      expectedSession: expectedSession,
    ),
  );
  Future<ApiResult<Object?>> storeComment(
    int postId,
    String content, {
    required SessionSnapshot expectedSession,
    int? parentId,
  }) async {
    if (content.trim().isEmpty || content.runes.length > 5000) {
      return _validation('Komentar wajib diisi, maksimal 5000 karakter.');
    }
    return _commentSuccess(
      await authClient.request(
        'POST',
        'forum/$postId/comment',
        body: {'content': content, 'parent_id': ?parentId},
        expectedSession: expectedSession,
      ),
      postId: postId,
      parentId: parentId,
    );
  }

  ApiResult<Object?> _commentSuccess(
    ApiResult<Object?> result, {
    int? id,
    int? postId,
    int? parentId,
  }) {
    if (!result.isSuccess) return result;
    try {
      final body = result.data;
      if (result.statusCode != 200 || body is! Map || body['success'] != true) {
        throw const FormatException();
      }
      final item = parseForumItem(body['data'], comment: true);
      if ((id != null && item['id'] != id) ||
          (postId != null &&
              (item['community_post_id'] != postId ||
                  item['parent_id'] != parentId))) {
        throw const FormatException();
      }
      return ApiResult.success(data: item, statusCode: 200);
    } on FormatException {
      return ApiResult.failure(_badForum());
    }
  }

  Future<ApiResult<Object?>> editComment(
    int id,
    String content, {
    required SessionSnapshot expectedSession,
  }) async {
    if (content.trim().isEmpty || content.runes.length > 5000) {
      return _validation('Komentar wajib diisi, maksimal 5000 karakter.');
    }
    return _commentSuccess(
      await authClient.request(
        'PATCH',
        'forum/comment/$id',
        body: {'content': content},
        expectedSession: expectedSession,
      ),
      id: id,
    );
  }

  Future<ApiResult<Object?>> setCommentLike(
    int id,
    bool liked, {
    required SessionSnapshot expectedSession,
  }) async {
    final result = await authClient.request(
      liked ? 'PUT' : 'DELETE',
      'forum/comment/$id/like',
      expectedSession: expectedSession,
    );
    if (!result.isSuccess) return result;
    final body = result.data;
    final data = body is Map ? body['data'] : null;
    if (result.statusCode != 200 ||
        body is! Map ||
        body['success'] != true ||
        data is! Map ||
        data['id'] != id ||
        data['likes_count'] is! int ||
        data['likes_count'] < 0 ||
        data['is_liked_by_me'] is! bool ||
        data['is_liked_by_me'] != liked) {
      return ApiResult.failure(_badForum());
    }
    return ApiResult.success(
      data: <String, dynamic>{
        'id': id,
        'likes_count': data['likes_count'],
        'is_liked_by_me': liked,
      },
      statusCode: 200,
    );
  }

  Future<ApiResult<Object?>> deleteComment(
    int commentId, {
    required SessionSnapshot expectedSession,
  }) async => _forumSuccess(
    await authClient.request(
      'DELETE',
      'forum/comment/$commentId',
      expectedSession: expectedSession,
    ),
  );
}
