import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

bool validRetailQuantity(String unit, String value) {
  final pattern = unit == 'kg'
      ? r'^(0|[1-9]\d{0,5})(\.\d{1,3})?$'
      : r'^[1-9]\d{0,5}$';
  return const ['kg', 'ekor', 'kemasan'].contains(unit) &&
      RegExp(pattern).hasMatch(value) &&
      (num.tryParse(value) ?? 0) > 0;
}

typedef RetailRow = Map<String, dynamic>;

RetailRow _readOrder(dynamic row) {
  if (row is! Map ||
      [
        'id',
        'buyer_id',
        'seller_id',
        'harga_satuan',
        'pasar_id',
        'total_harga',
      ].any((k) => row[k] is! int || row[k] < 1) ||
      row['nama_ikan'] is! String ||
      !const ['kg', 'ekor', 'kemasan'].contains(row['satuan_jual']) ||
      row['jumlah'] is! String ||
      !RegExp(r'^\d{1,6}\.\d{3}$').hasMatch(row['jumlah']) ||
      row['status_bayar'] is! String ||
      (row['confirmed_at'] != null &&
          (row['confirmed_at'] is! String ||
              DateTime.tryParse(row['confirmed_at']) == null))) {
    throw const FormatException();
  }
  return Map.unmodifiable(Map<String, dynamic>.from(row));
}

mixin RetailApi on AuthService {
  Future<ApiResult<T>> _retail<T>(
    SessionSnapshot owner,
    String method,
    String path,
    int status,
    T Function(dynamic) parse, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final r = await authClient.request(
      method,
      path,
      expectedSession: owner,
      body: body,
      query: query,
    );
    if (!r.isSuccess) {
      return ApiResult.failure(r.failure!, statusCode: r.statusCode);
    }
    try {
      final value = r.data;
      if (r.statusCode != status || value is! Map || value['success'] != true) {
        throw const FormatException();
      }
      return ApiResult.success(data: parse(value['data']), statusCode: status);
    } on FormatException {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidResponse,
          message: 'Respons pesanan tidak valid. Periksa riwayat.',
        ),
        statusCode: r.statusCode,
      );
    }
  }

  Future<ApiResult<bool>> retailOffer(
    SessionSnapshot owner,
    int id,
    String unit,
    int price,
  ) => _retail(
    owner,
    'PUT',
    'pasars/$id/retail-offer',
    200,
    (v) {
      if (v is! Map ||
          v['id'] != id ||
          v['satuan_jual'] != unit ||
          v['harga'] != price) {
        throw const FormatException();
      }
      return true;
    },
    body: {'satuan_jual': unit, 'harga': price},
  );
  Future<ApiResult<RetailRow>> retailBuy(
    SessionSnapshot owner,
    int id,
    String unit,
    int price,
    String quantity,
  ) => _retail(
    owner,
    'POST',
    'retail-orders',
    201,
    (v) {
      final row = _readOrder(v);
      if (row['pasar_id'] != id ||
          row['satuan_jual'] != unit ||
          row['harga_satuan'] != price) {
        throw const FormatException();
      }
      return row;
    },
    body: {
      'pasar_id': id,
      'expected_unit': unit,
      'expected_price': price,
      'jumlah': quantity,
    },
  );
  Future<ApiResult<RetailRow>> retailConfirm(SessionSnapshot owner, int id) =>
      _retail(owner, 'PUT', 'retail-orders/$id/confirmation', 200, (v) {
        final row = _readOrder(v);
        if (row['id'] != id || row['confirmed_at'] == null) {
          throw const FormatException();
        }
        return row;
      });
  Future<ApiResult<({List<RetailRow> rows, int last})>> retailHistory(
    SessionSnapshot owner,
    int page,
  ) => _retail(owner, 'GET', 'retail-orders', 200, (v) {
    if (v is! Map ||
        v['current_page'] != page ||
        v['last_page'] is! int ||
        v['data'] is! List) {
      throw const FormatException();
    }
    return (
      rows: (v['data'] as List).map(_readOrder).toList(),
      last: v['last_page'] as int,
    );
  }, query: {'page': '$page'});
}
