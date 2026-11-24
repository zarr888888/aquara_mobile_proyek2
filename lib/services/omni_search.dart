import '../models/forum_post.dart';
import '../models/pasar_item.dart';
import '../models/reference_data.dart';
import 'api_result.dart';
import 'api_service.dart';
import 'session_service.dart';

enum ContentKind {
  pasar('Pasar', 'pasars'),
  forum('Forum', 'forum'),
  berita('Berita', 'posts');

  const ContentKind(this.label, this.path);
  final String label, path;
}

typedef Hit = ({int id, String? title, String? summary});
typedef SearchPage = ({List<Hit> hits, int page, bool more});
typedef Groups = Map<ContentKind, SearchPage>;

final _waits = Expando<Map<bool, ({int revision, DateTime until})>>();

extension OmniSearch on ApiService {
  Future<ApiResult<T>> _read<T>(
    String path,
    SessionSnapshot owner,
    T Function(Map<String, dynamic>) parse, {
    Map<String, String>? query,
  }) async {
    final waits = _waits[session] ??= {};
    final detail = query == null;
    final wait = waits[detail];
    if (wait != null &&
        wait.revision == owner.revision &&
        DateTime.now().isBefore(wait.until)) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.rateLimited,
          message: 'Terlalu banyak permintaan.',
          retryAt: wait.until,
        ),
        statusCode: 429,
      );
    }
    final result = await authClient.request(
      'GET',
      path,
      query: query,
      expectedSession: owner,
    );
    if (!session.owns(owner)) {
      return ApiResult.failure(
        ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
      );
    }
    final failure = result.failure;
    if (failure != null) {
      if (failure.kind == ApiErrorKind.rateLimited) {
        final until =
            failure.retryAt ??
            DateTime.now().add(failure.retryAfter ?? Duration.zero);
        waits[detail] = (revision: owner.revision, until: until);
      }
      return ApiResult.failure(failure, statusCode: result.statusCode);
    }
    try {
      final body = result.data;
      if (body is! Map ||
          body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return ApiResult.success(
        data: parse(body['data']),
        statusCode: result.statusCode,
      );
    } on FormatException {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidResponse,
          message: 'Format respons tidak sesuai.',
        ),
      );
    }
  }

  Future<ApiResult<Groups>> searchContent(
    String input,
    SessionSnapshot owner, {
    ContentKind? group,
    int page = 1,
  }) async {
    final q = input.trim();
    if (q.isEmpty || q.runes.length > 100 || page < 1 || page > 1000) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.validation,
          message: 'Masukkan 1–100 karakter.',
        ),
      );
    }
    return _read('search', owner, (data) {
      final groups = <ContentKind, SearchPage>{};
      for (final kind in ContentKind.values) {
        final block = data[kind.name];
        if (block is! Map || block['data'] is! List || block['meta'] is! Map) {
          throw const FormatException();
        }
        final meta = block['meta'] as Map;
        final current = kind == group ? page : 1;
        if (meta['current_page'] != current ||
            meta['has_more_pages'] is! bool ||
            meta['total'] is! int ||
            meta['per_page'] is! int ||
            meta['last_page'] is! int) {
          throw const FormatException();
        }
        final hits = <Hit>[];
        for (final row in block['data']) {
          if (row is! Map ||
              row['type'] != kind.name ||
              row['id'] is! int ||
              row['id'] <= 0 ||
              (kind == ContentKind.forum
                  ? row['title'] != null
                  : row['title'] is! String) ||
              (row['summary'] != null && row['summary'] is! String) ||
              (row['thumbnail'] != null && row['thumbnail'] is! String)) {
            throw const FormatException();
          }
          hits.add((
            id: row['id'] as int,
            title: row['title'] as String?,
            summary: row['summary'] as String?,
          ));
        }
        groups[kind] = (
          hits: hits,
          page: current,
          more: current < 1000 && meta['has_more_pages'] == true,
        );
      }
      return groups;
    }, query: {'q': q, if (group != null) '${group.name}_page': '$page'});
  }

  Future<ApiResult<Map<String, dynamic>>> contentDetail(
    ContentKind kind,
    int id,
    SessionSnapshot owner,
  ) => _read('${kind.path}/$id', owner, (row) {
    if (row['id'] is! int || row['id'] != id || id <= 0) {
      throw const FormatException();
    }
    switch (kind) {
      case ContentKind.pasar:
        return parsePasarItem(row);
      case ContentKind.forum:
        return parseForumItem(row);
      case ContentKind.berita:
        if (row['title'] is! String ||
            row['content'] is! String ||
            (row['created_at'] != null && row['created_at'] is! String)) {
          throw const FormatException();
        }
        return {
          'title': row['title'],
          'content': row['content'],
          'date': row['created_at'] ?? '–',
          'image': referenceImage(row) ?? '',
        };
    }
  });
}
