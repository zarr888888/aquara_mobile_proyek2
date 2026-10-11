import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

const aiImageMaxBytes = 15360 * 1024;
const aiRequestTimeout = Duration(seconds: 180);

/// Only the structured presentation contract is retained, never raw_ai_response.
class AiAnalysis {
  const AiAnalysis(
    this.imagePath,
    this.disease,
    this.waterQuality,
    this.solution,
  );
  final String imagePath;
  final String disease;
  final String waterQuality;
  final String solution;

  factory AiAnalysis.parse(Object? value) {
    if (value is! Map) throw const FormatException();
    String text(String key) {
      final item = value[key];
      if (item is! String || item.trim().isEmpty) {
        throw const FormatException();
      }
      return item;
    }

    return AiAnalysis(
      text('image_path'),
      text('disease_detected'),
      text('water_quality_status'),
      text('solution'),
    );
  }
}

/// Picked files are read once into session-owned memory. No original is deleted.
class AiImage {
  AiImage._(this.bytes, this.filename);
  final Uint8List bytes;
  final String filename;

  static Future<ApiResult<AiImage>> read(XFile file) async {
    try {
      if (await file.length() > aiImageMaxBytes) throw const FormatException();
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      const pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
      final png =
          bytes.length >= 8 &&
          Iterable.generate(8).every((i) => bytes[i] == pngHeader[i]);
      if (bytes.isEmpty ||
          bytes.length > aiImageMaxBytes ||
          !((jpeg && RegExp(r'\.jpe?g$').hasMatch(name)) ||
              (png && name.endsWith('.png')))) {
        throw const FormatException();
      }
      return ApiResult.success(
        data: AiImage._(
          Uint8List.fromList(bytes).asUnmodifiableView(),
          png ? 'image.png' : 'image.jpg',
        ),
        statusCode: 200,
      );
    } catch (_) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.validation,
          message:
              'Foto tidak dapat dibaca atau tidak valid. Gunakan JPEG/JPG/PNG maksimal 15360 KB.',
        ),
      );
    }
  }
}

mixin AiAnalysisApi on AuthService {
  Future<ApiResult<AiAnalysis>> analyzeImage({
    required AiImage image,
    required SessionSnapshot expectedSession,
    Duration requestTimeout = aiRequestTimeout,
  }) async {
    if (!session.owns(expectedSession)) {
      return ApiResult.failure(
        ApiFailure(
          kind: expectedSession.isAuthenticated
              ? ApiErrorKind.staleSession
              : ApiErrorKind.unauthenticated,
          message: 'Silakan buka kembali analisis dari sesi aktif.',
        ),
      );
    }
    final result = await authClient.multipart(
      'ai-analyze',
      expectedSession: expectedSession,
      requestTimeout: requestTimeout,
      files: [
        http.MultipartFile.fromBytes(
          'image',
          image.bytes,
          filename: image.filename,
        ),
      ],
    );
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    try {
      final body = result.data;
      if (result.statusCode != 200 || body is! Map || body['success'] != true) {
        throw const FormatException();
      }
      return ApiResult.success(
        data: AiAnalysis.parse(body['data']),
        statusCode: 200,
      );
    } on FormatException {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidResponse,
          message:
              'Hasil analisis tidak valid. Tidak ada diagnosis yang dapat ditampilkan.',
        ),
        statusCode: result.statusCode,
      );
    }
  }
}
