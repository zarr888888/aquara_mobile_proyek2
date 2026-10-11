import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/sos_report.dart';
import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// In-memory, signature-checked upload, following the existing profile upload.
class SosPhoto {
  SosPhoto._(this.bytes, this.filename);
  final Uint8List bytes;
  final String filename;

  static Future<SosPhoto> read(XFile file) async {
    if (await file.length() > 2048 * 1024) throw const FormatException();
    final bytes = await file.readAsBytes();
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
    return SosPhoto._(
      bytes.asUnmodifiableView(),
      png ? 'foto.png' : 'foto.jpg',
    );
  }
}

mixin SosApi on AuthService {
  ApiResult<T> _invalidSos<T>([int? status]) => ApiResult.failure(
    ApiFailure(
      kind: ApiErrorKind.invalidResponse,
      message:
          'Respons laporan tidak valid. Periksa riwayat sebelum mengirim ulang.',
    ),
    statusCode: status,
  );

  Future<ApiResult<List<SosReport>>> sosHistory({
    required SessionSnapshot expectedSession,
  }) async {
    final result = await authClient.request(
      'GET',
      'lapor-darurat',
      expectedSession: expectedSession,
    );
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    final body = result.data;
    if (result.statusCode != 200 ||
        body is! Map ||
        body['success'] != true ||
        body['data'] is! List) {
      return _invalidSos(result.statusCode);
    }
    try {
      return ApiResult.success(
        data: List.unmodifiable((body['data'] as List).map(SosReport.parse)),
        statusCode: 200,
      );
    } on FormatException {
      return _invalidSos(result.statusCode);
    }
  }

  Future<ApiResult<SosReport>> sosDetail(
    int id, {
    required SessionSnapshot expectedSession,
  }) async {
    if (id <= 0) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Laporan tidak tersedia.',
        ),
      );
    }
    final result = await authClient.request(
      'GET',
      'lapor-darurat/$id',
      expectedSession: expectedSession,
    );
    final parsed = _report(result, 200);
    if (parsed.isSuccess && parsed.data!.id != id) return _invalidSos(200);
    return parsed;
  }

  Future<ApiResult<SosReport>> sendSos({
    required SessionSnapshot expectedSession,
    required String type,
    required String description,
    SosPhoto? photo,
  }) async {
    final errors = <String, List<String>>{
      if (!sosTypes.contains(type)) 'jenis_sos': ['Pilih jenis laporan.'],
      if (description.trim().isEmpty || description.runes.length > 5000)
        'deskripsi': ['Deskripsi wajib diisi, maksimal 5000 karakter.'],
    };
    if (errors.isNotEmpty) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.validation,
          message: 'Periksa data laporan.',
          fieldErrors: errors,
        ),
      );
    }
    final fields = {'jenis_sos': type, 'deskripsi': description};
    final result = photo == null
        ? await authClient.request(
            'POST',
            'lapor-darurat',
            body: fields,
            expectedSession: expectedSession,
          )
        : await authClient.multipart(
            'lapor-darurat',
            fields: fields,
            files: [
              http.MultipartFile.fromBytes(
                'foto',
                photo.bytes,
                filename: photo.filename,
              ),
            ],
            expectedSession: expectedSession,
          );
    return _report(result, 201);
  }

  ApiResult<SosReport> _report(ApiResult<Object?> result, int status) {
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    final body = result.data;
    if (result.statusCode != status ||
        body is! Map ||
        body['success'] != true) {
      return _invalidSos(result.statusCode);
    }
    try {
      return ApiResult.success(
        data: SosReport.parse(body['data']),
        statusCode: status,
      );
    } on FormatException {
      return _invalidSos(result.statusCode);
    }
  }
}
