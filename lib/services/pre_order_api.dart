import '../models/pre_order.dart';
import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

mixin PreOrderApi on AuthService {
  ApiResult<T> _invalidOrder<T>([int? status]) => ApiResult.failure(
    ApiFailure(
      kind: ApiErrorKind.invalidResponse,
      message:
          'Respons pesanan tidak valid. Periksa riwayat sebelum mengirim ulang.',
    ),
    statusCode: status,
  );

  ApiResult<T> _orderFailure<T>(ApiResult<Object?> result) {
    final failure = result.failure!;
    const messages = {
      'pasar_id':
          'Produk tidak tersedia untuk pengajuan grosir. Muat ulang Pasar.',
      'total_tonase': preOrderTonError,
      'tgl_pengambilan': preOrderDateError,
    };
    return ApiResult.failure(
      ApiFailure(
        kind: failure.kind,
        message: result.statusCode == 403 || result.statusCode == 404
            ? 'Pesanan tidak tersedia.'
            : failure.kind == ApiErrorKind.validation
            ? 'Periksa data pengajuan.'
            : failure.message,
        fieldErrors: {
          for (final key in messages.keys)
            if (failure.fieldErrors.containsKey(key)) key: [messages[key]!],
        },
        retryAfter: failure.retryAfter,
        retryAt: failure.retryAt,
      ),
      statusCode: result.statusCode,
    );
  }

  ApiResult<PreOrder> _order(ApiResult<Object?> result, int status) {
    if (!result.isSuccess) return _orderFailure(result);
    final body = result.data;
    if (result.statusCode != status ||
        body is! Map ||
        body['success'] != true) {
      return _invalidOrder(result.statusCode);
    }
    try {
      return ApiResult.success(
        data: PreOrder.parse(body['data']),
        statusCode: status,
      );
    } on FormatException {
      return _invalidOrder(result.statusCode);
    }
  }

  Future<ApiResult<PreOrder>> createPreOrder({
    required SessionSnapshot expectedSession,
    required int pasarId,
    required String tonnage,
    required String pickupDate,
  }) async {
    final amount = preOrderHundredths(tonnage);
    final errors = <String, List<String>>{
      if (pasarId <= 0) 'pasar_id': ['Pilih produk grosir dari Pasar.'],
      if (amount == null) 'total_tonase': [preOrderTonError],
      if (!preOrderDateValid(pickupDate))
        'tgl_pengambilan': [preOrderDateError],
    };
    if (errors.isNotEmpty) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.validation,
          message: 'Periksa data pengajuan.',
          fieldErrors: errors,
        ),
      );
    }
    final result = _order(
      await authClient.request(
        'POST',
        'pre-order',
        expectedSession: expectedSession,
        body: {
          'pasar_id': pasarId,
          'total_tonase': amount! / 100,
          'tgl_pengambilan': pickupDate,
        },
      ),
      201,
    );
    if (result.isSuccess &&
        (result.data!.pasarId != pasarId ||
            result.data!.hundredths != amount ||
            result.data!.pickupDate != pickupDate ||
            result.data!.paymentStatus != 'Belum Bayar')) {
      return _invalidOrder(201);
    }
    return result;
  }

  Future<ApiResult<PreOrderPage>> preOrderHistory({
    required SessionSnapshot expectedSession,
    int page = 1,
  }) async {
    if (page < 1) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Halaman tidak valid.',
        ),
      );
    }
    final result = await authClient.request(
      'GET',
      'pre-order',
      query: {'page': '$page'},
      expectedSession: expectedSession,
    );
    if (!result.isSuccess) return _orderFailure(result);
    final body = result.data;
    if (result.statusCode != 200 || body is! Map || body['success'] != true) {
      return _invalidOrder(result.statusCode);
    }
    try {
      final parsed = PreOrderPage.parse(body['data']);
      if (parsed.currentPage != page) return _invalidOrder(200);
      return ApiResult.success(data: parsed, statusCode: 200);
    } on FormatException {
      return _invalidOrder(result.statusCode);
    }
  }

  Future<ApiResult<PreOrder>> preOrderDetail(
    int id, {
    required SessionSnapshot expectedSession,
  }) => _orderById(id, expectedSession: expectedSession, confirm: false);

  Future<ApiResult<PreOrder>> confirmPreOrder(
    int id, {
    required SessionSnapshot expectedSession,
  }) => _orderById(id, expectedSession: expectedSession, confirm: true);

  Future<ApiResult<PreOrder>> _orderById(
    int id, {
    required SessionSnapshot expectedSession,
    required bool confirm,
  }) async {
    if (id <= 0) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Pesanan tidak tersedia.',
        ),
      );
    }
    final result = _order(
      await authClient.request(
        confirm ? 'PUT' : 'GET',
        confirm ? 'pre-order/$id/confirmation' : 'pre-order/$id',
        expectedSession: expectedSession,
      ),
      200,
    );
    if (result.isSuccess &&
        (result.data!.id != id ||
            (confirm && result.data!.confirmedAt == null))) {
      return _invalidOrder(200);
    }
    return result;
  }
}
