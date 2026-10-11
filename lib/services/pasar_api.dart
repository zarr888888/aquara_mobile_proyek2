import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/pasar_item.dart';
import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// Four Pasar endpoints on the existing authenticated transport.
mixin PasarApi on AuthService {
  final _pasarReads = <int, Future<ApiResult<List<dynamic>>>>{};

  ApiFailure _badPasar() => ApiFailure(
    kind: ApiErrorKind.invalidResponse,
    message:
        'Respons Pasar tidak valid. Periksa ulang daftar sebelum mengulang aksi.',
  );

  Future<ApiResult<List<dynamic>>> fetchPasar({
    required SessionSnapshot expectedSession,
  }) => _pasarReads.putIfAbsent(expectedSession.revision, () async {
    try {
      final result = await authClient.request(
        'GET',
        'pasars',
        expectedSession: expectedSession,
      );
      if (!result.isSuccess) {
        return ApiResult.failure(
          result.failure!,
          statusCode: result.statusCode,
        );
      }
      final body = result.data;
      if (result.statusCode != 200 ||
          body is! Map ||
          body['success'] != true ||
          body['data'] is! List) {
        return ApiResult.failure(_badPasar(), statusCode: result.statusCode);
      }
      try {
        return ApiResult.success(
          data: List.unmodifiable((body['data'] as List).map(parsePasarItem)),
          statusCode: 200,
        );
      } on FormatException {
        return ApiResult.failure(_badPasar(), statusCode: result.statusCode);
      }
    } finally {
      _pasarReads.remove(expectedSession.revision);
    }
  });

  Future<ApiResult<Map<String, dynamic>>> createPasar({
    required SessionSnapshot expectedSession,
    required String namaIkan,
    required String harga,
    required String deskripsi,
    required String nomorWa,
    required String lokasi,
    String? stok,
    String? kategori,
    String? tipePenjualan,
    File? foto,
  }) => _writePasar(
    'pasars',
    expectedSession,
    namaIkan,
    harga,
    deskripsi,
    nomorWa,
    lokasi,
    stok,
    kategori,
    tipePenjualan,
    foto,
    201,
  );

  Future<ApiResult<Map<String, dynamic>>> updatePasarItem({
    required int id,
    required SessionSnapshot expectedSession,
    required String namaIkan,
    required String harga,
    required String deskripsi,
    required String nomorWa,
    required String lokasi,
    String? stok,
    String? kategori,
    String? tipePenjualan,
    File? imageFile,
  }) => _writePasar(
    'pasars/$id/update',
    expectedSession,
    namaIkan,
    harga,
    deskripsi,
    nomorWa,
    lokasi,
    stok,
    kategori,
    tipePenjualan,
    imageFile,
    200,
  );

  Future<ApiResult<Map<String, dynamic>>> _writePasar(
    String path,
    SessionSnapshot owner,
    String name,
    String price,
    String description,
    String phone,
    String location,
    String? stock,
    String? category,
    String? saleType,
    File? image,
    int expectedStatus,
  ) async {
    final errors = <String, List<String>>{};
    void check(String key, String? error) {
      if (error != null) errors[key] = [error];
    }

    check('nama_ikan', pasarTextError(name, 255));
    check('harga', pasarNumberError(price));
    check('deskripsi', pasarTextError(description, 2000));
    check('nomor_wa', pasarTextError(phone, 20));
    check('lokasi', pasarTextError(location, 255));
    check('stok', pasarNumberError(stock, optional: true));
    if (category != null &&
        category.isNotEmpty &&
        !pasarCategories.contains(category)) {
      check('kategori', 'Pilih kategori yang tersedia.');
    }
    if (saleType != null &&
        saleType.isNotEmpty &&
        !pasarSaleTypes.contains(saleType)) {
      check('tipe_penjualan', 'Pilih tipe penjualan yang tersedia.');
    }
    if (errors.isNotEmpty) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.validation,
          message: 'Periksa kolom jualan.',
          fieldErrors: errors,
        ),
      );
    }
    final body = <String, Object?>{
      'nama_ikan': name,
      'harga': pasarInteger(price),
      'deskripsi': description,
      'nomor_wa': phone,
      'lokasi': location,
      if (stock != null && stock.isNotEmpty) 'stok': pasarInteger(stock),
      if (category != null && category.isNotEmpty) 'kategori': category,
      if (saleType != null && saleType.isNotEmpty) 'tipe_penjualan': saleType,
    };
    ApiResult<Object?> result;
    if (image == null) {
      result = await authClient.request(
        'POST',
        path,
        body: body,
        expectedSession: owner,
      );
    } else {
      try {
        if (await image.length() > 2048 * 1024 ||
            !RegExp(
              r'\.(jpe?g|png)$',
              caseSensitive: false,
            ).hasMatch(image.path)) {
          throw const FormatException();
        }
        final bytes = await image.readAsBytes();
        final jpeg =
            bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        final png =
            bytes.length >= 8 &&
            bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
        if (bytes.length > 2048 * 1024 || (!jpeg && !png)) {
          throw const FormatException();
        }
        result = await authClient.multipart(
          path,
          fields: body.map((key, value) => MapEntry(key, value.toString())),
          files: [
            http.MultipartFile.fromBytes(
              'foto',
              bytes,
              filename: png ? 'foto.png' : 'foto.jpg',
            ),
          ],
          expectedSession: owner,
        );
      } catch (_) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.validation,
            message:
                'Pilih file JPEG/JPG/PNG yang dapat dibaca, maksimal 2048 KB.',
            fieldErrors: const {
              'foto': ['Foto tidak valid.'],
            },
          ),
        );
      }
    }
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    final payload = result.data;
    if (result.statusCode != expectedStatus ||
        payload is! Map ||
        payload['success'] != true) {
      return ApiResult.failure(_badPasar(), statusCode: result.statusCode);
    }
    try {
      return ApiResult.success(
        data: parsePasarItem(payload['data']),
        statusCode: expectedStatus,
      );
    } on FormatException {
      return ApiResult.failure(_badPasar(), statusCode: result.statusCode);
    }
  }

  Future<ApiResult<Object?>> deletePasarItem(
    int id, {
    required SessionSnapshot expectedSession,
  }) async {
    if (id <= 0) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Jualan tidak tersedia.',
        ),
      );
    }
    final result = await authClient.request(
      'DELETE',
      'pasars/$id',
      expectedSession: expectedSession,
    );
    if (!result.isSuccess) return result;
    final body = result.data;
    if (result.statusCode != 200 ||
        body is! Map ||
        body['message'] is! String) {
      return ApiResult.failure(_badPasar(), statusCode: result.statusCode);
    }
    return const ApiResult.success(data: null, statusCode: 200);
  }
}
