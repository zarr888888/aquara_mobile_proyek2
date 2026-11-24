import 'package:flutter/foundation.dart' show kDebugMode;
import 'reference_data.dart';

const sosTypes = ['Wabah Penyakit', 'Pencemaran Limbah', 'Cuaca Ekstrem'];

String? _sosPhoto(Object? value) {
  const demo =
      kDebugMode &&
      bool.fromEnvironment('SAMUDERA_SOS_DEMO') &&
      String.fromEnvironment('SAMUDERA_API_URL') ==
          'http://127.0.0.1:18746/api';
  const prefix = 'http://127.0.0.1:18746/demo-media/';
  if (demo && value is String && value.startsWith(prefix)) {
    final path = value.substring(prefix.length);
    // Check raw segments before URI normalization; no traversal, escapes,
    // query credentials, or alternate authority are accepted.
    final safe = path
        .split('/')
        .every(
          (s) =>
              s.isNotEmpty &&
              s != '.' &&
              s != '..' &&
              !s.contains(RegExp(r'[^A-Za-z0-9._-]')),
        );
    return safe ? value : null;
  }
  return referenceImage({'image': value});
}

class SosReport {
  const SosReport(
    this.id,
    this.type,
    this.description,
    this.status,
    this.photo,
    this.createdAt,
  );
  final int id;
  final String type;
  final String description;
  final String status;
  final String? photo;
  final DateTime? createdAt;

  factory SosReport.parse(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! int ||
        raw['id'] <= 0 ||
        raw['jenis_sos'] is! String ||
        raw['deskripsi'] is! String ||
        raw['status_laporan'] is! String) {
      throw const FormatException();
    }
    final status = raw['status_laporan'] as String;
    return SosReport(
      raw['id'],
      raw['jenis_sos'],
      raw['deskripsi'],
      const ['Pending', 'Diproses', 'Selesai'].contains(status)
          ? status
          : 'Status belum tersedia',
      _sosPhoto(raw['foto']),
      raw['created_at'] is String ? DateTime.tryParse(raw['created_at']) : null,
    );
  }
}
