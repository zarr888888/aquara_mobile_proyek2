import '../models/pasar_item.dart';
import '../models/profile_summary.dart';
import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

class ProfileProductsPage {
  const ProfileProductsPage(this.items, this.page, this.lastPage);
  final List<Map<String, dynamic>> items;
  final int page, lastPage;
}

mixin ProfileApi on AuthService {
  Future<ApiResult<T>> _profileRead<T>(
    int id,
    SessionSnapshot owner,
    T Function(Map body) parse, {
    int? page,
  }) async {
    if (id <= 0 || (page != null && page < 1)) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Profil tidak tersedia.',
        ),
      );
    }
    final result = await authClient.request(
      'GET',
      page == null ? 'profiles/$id' : 'profiles/$id/pasars',
      query: page == null ? null : {'page': '$page', 'per_page': '20'},
      expectedSession: owner,
    );
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    try {
      final body = result.data;
      if (result.statusCode != 200 || body is! Map || body['success'] != true) {
        throw const FormatException();
      }
      return ApiResult.success(data: parse(body), statusCode: 200);
    } on FormatException {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidResponse,
          message: 'Respons profil tidak valid. Silakan coba lagi.',
        ),
        statusCode: result.statusCode,
      );
    }
  }

  Future<ApiResult<ProfileSummary>> fetchProfile(
    int id, {
    required SessionSnapshot expectedSession,
  }) => _profileRead(
    id,
    expectedSession,
    (body) => ProfileSummary.parse(body['data'], id),
  );

  Future<ApiResult<ProfileProductsPage>> fetchProfileProducts(
    int id, {
    required SessionSnapshot expectedSession,
    int page = 1,
  }) => _profileRead(id, expectedSession, (body) {
    final rows = body['data'], meta = body['meta'];
    if (rows is! List ||
        meta is! Map ||
        meta['current_page'] != page ||
        meta['per_page'] is! int ||
        meta['per_page'] < 1 ||
        meta['per_page'] > 50 ||
        rows.length > meta['per_page'] ||
        meta['last_page'] is! int ||
        meta['last_page'] < 1 ||
        meta['total'] is! int ||
        meta['total'] < 0) {
      throw const FormatException();
    }
    final items = rows.map(parsePasarItem).toList();
    if (items.any((item) => item['user_id'] != id)) {
      throw const FormatException();
    }
    return ProfileProductsPage(
      List.unmodifiable(items),
      page,
      meta['last_page'],
    );
  }, page: page);
}
